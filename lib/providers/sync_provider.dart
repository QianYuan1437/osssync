import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_task.dart';
import '../models/sync_log.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';
import '../services/storage_service.dart';
import '../services/sync_engine.dart';
import '../services/scheduler_service.dart';

class SyncProvider extends ChangeNotifier {
  final StorageService _storage;
  final SyncEngine _engine = SyncEngine();
  final SchedulerService _scheduler = SchedulerService();
  final _uuid = const Uuid();

  List<SyncTask> _tasks = [];
  List<SyncLog> _logs = [];
  // 当前正在同步的任务 ID 集合
  final Set<String> _syncingTaskIds = {};
  // 实时进度消息
  final Map<String, String> _progressMessages = {};
  // 编辑草稿：key 为 taskId（新建用 '__new__'），value 为草稿数据 Map
  final Map<String, Map<String, dynamic>> _drafts = {};

  SyncProvider(this._storage) {
    _scheduler.onTrigger = _onSchedulerTrigger;
  }

  List<SyncTask> get tasks => List.unmodifiable(_tasks);
  List<SyncLog> get logs => List.unmodifiable(_logs);
  bool isSyncing(String taskId) => _syncingTaskIds.contains(taskId);
  String? getProgress(String taskId) => _progressMessages[taskId];
  bool get hasAnySyncing => _syncingTaskIds.isNotEmpty;

  // 外部注入账户和存储桶查找函数
  AccountModel? Function(String)? getAccount;
  BucketConfig? Function(String)? getBucketConfig;

  Future<void> init() async {
    _tasks = await _storage.loadSyncTasks();
    _logs = await _storage.loadSyncLogs();
    _scheduler.reloadAll(_tasks);
    notifyListeners();
  }

  // ─── 任务操作 ─────────────────────────────────────────────────────────────────

  Future<void> addTask(SyncTask task) async {
    _tasks.add(task);
    await _storage.saveSyncTasks(_tasks);
    _scheduler.scheduleTask(task);
    notifyListeners();
  }

  Future<void> updateTask(SyncTask updated) async {
    final idx = _tasks.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _tasks[idx] = updated;
      await _storage.saveSyncTasks(_tasks);
      _scheduler.scheduleTask(updated);
      notifyListeners();
    }
  }

  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _storage.saveSyncTasks(_tasks);
    _scheduler.cancelTask(taskId);
    await _storage.clearLogsByTask(taskId);
    _logs.removeWhere((l) => l.taskId == taskId);
    notifyListeners();
  }

  Future<void> toggleTaskEnabled(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;
    final task = _tasks[idx].copyWith(isEnabled: !_tasks[idx].isEnabled);
    _tasks[idx] = task;
    await _storage.saveSyncTasks(_tasks);
    _scheduler.scheduleTask(task);
    notifyListeners();
  }

  SyncTask createNewTask({
    required String name,
    required String accountId,
    required String bucketConfigId,
    required String localPath,
    required String remotePath,
    required SyncDirection syncDirection,
    required int intervalMinutes,
  }) {
    return SyncTask(
      id: _uuid.v4(),
      name: name,
      accountId: accountId,
      bucketConfigId: bucketConfigId,
      localPath: localPath,
      remotePath: remotePath,
      syncDirection: syncDirection,
      intervalMinutes: intervalMinutes,
      isEnabled: true,
      status: SyncStatus.idle,
      createdAt: DateTime.now(),
    );
  }

  SyncTask? getTaskById(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── 草稿管理 ─────────────────────────────────────────────────────────────────

  /// 保存编辑草稿，taskId 为 null 时表示新建任务草稿
  void saveDraft(String? taskId, Map<String, dynamic> draft) {
    final key = taskId ?? '__new__';
    _drafts[key] = Map.from(draft);
  }

  /// 读取草稿，返回 null 表示无草稿
  Map<String, dynamic>? getDraft(String? taskId) {
    final key = taskId ?? '__new__';
    return _drafts[key];
  }

  /// 清除草稿（保存或取消后调用）
  void clearDraft(String? taskId) {
    final key = taskId ?? '__new__';
    _drafts.remove(key);
  }

  // ─── 同步执行 ─────────────────────────────────────────────────────────────────

  Future<void> runSync(String taskId) async {
    if (_syncingTaskIds.contains(taskId)) return;

    final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx < 0) return;

    final task = _tasks[taskIdx];
    final account = getAccount?.call(task.accountId);
    final bucket = getBucketConfig?.call(task.bucketConfigId);

    if (account == null || bucket == null) {
      _addErrorLog(task, '账户或存储桶配置不存在');
      return;
    }

    _syncingTaskIds.add(taskId);
    _tasks[taskIdx] = task.copyWith(status: SyncStatus.syncing);
    notifyListeners();

    try {
      final log = await _engine.runSync(
        task: task,
        account: account,
        bucket: bucket,
        onProgress: (msg) {
          _progressMessages[taskId] = msg;
          notifyListeners();
        },
      );

      await _storage.appendSyncLog(log);
      _logs.insert(0, log);

      final newStatus =
          log.level == LogLevel.error ? SyncStatus.error : SyncStatus.success;
      _tasks[taskIdx] = task.copyWith(
        status: newStatus,
        lastSyncAt: log.timestamp,
        lastError: log.level == LogLevel.error ? log.message : null,
      );
      await _storage.saveSyncTasks(_tasks);
    } catch (e) {
      _tasks[taskIdx] = task.copyWith(
        status: SyncStatus.error,
        lastError: e.toString(),
      );
      _addErrorLog(task, '同步异常: $e');
    } finally {
      _syncingTaskIds.remove(taskId);
      _progressMessages.remove(taskId);
      notifyListeners();
    }
  }

  Future<void> runAllEnabledTasks() async {
    for (final task in _tasks.where((t) => t.isEnabled)) {
      await runSync(task.id);
    }
  }

  void _onSchedulerTrigger(String taskId) {
    runSync(taskId);
  }

  void _addErrorLog(SyncTask task, String message) {
    final log = SyncLog(
      id: _uuid.v4(),
      taskId: task.id,
      taskName: task.name,
      timestamp: DateTime.now(),
      level: LogLevel.error,
      message: message,
    );
    _logs.insert(0, log);
    _storage.appendSyncLog(log);
    notifyListeners();
  }

  // ─── 日志操作 ─────────────────────────────────────────────────────────────────

  Future<void> clearAllLogs() async {
    _logs.clear();
    await _storage.clearLogs();
    notifyListeners();
  }

  List<SyncLog> getLogsByTask(String taskId) {
    return _logs.where((l) => l.taskId == taskId).toList();
  }

  @override
  void dispose() {
    _scheduler.dispose();
    super.dispose();
  }
}
