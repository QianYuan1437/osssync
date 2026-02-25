import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';
import '../models/sync_task.dart';
import '../models/sync_log.dart';

class StorageService {
  static const _accountsKey = 'accounts';
  static const _bucketsKey = 'bucket_configs';
  static const _tasksKey = 'sync_tasks';
  static const _logsKey = 'sync_logs';
  static const _themeModeKey = 'theme_mode';
  static const _maxLogs = 500;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) throw StateError('StorageService not initialized');
    return _prefs!;
  }

  // ─── 主题 ───────────────────────────────────────────────────────────────────

  Future<String> getThemeMode() async {
    return prefs.getString(_themeModeKey) ?? 'dark';
  }

  Future<void> saveThemeMode(String mode) async {
    await prefs.setString(_themeModeKey, mode);
  }

  // ─── 账户 ───────────────────────────────────────────────────────────────────

  Future<List<AccountModel>> loadAccounts() async {
    final jsonList = prefs.getStringList(_accountsKey) ?? [];
    final accounts = jsonList.map(AccountModel.fromJsonString).toList();
    // 从安全存储加载密钥
    for (final account in accounts) {
      final secret = await _secureStorage.read(key: 'aks_${account.id}');
      account.accessKeySecret = secret ?? '';
    }
    return accounts;
  }

  Future<void> saveAccounts(List<AccountModel> accounts) async {
    final jsonList = accounts.map((a) => a.toJsonString()).toList();
    await prefs.setStringList(_accountsKey, jsonList);
    // 安全存储密钥
    for (final account in accounts) {
      if (account.accessKeySecret.isNotEmpty) {
        await _secureStorage.write(
          key: 'aks_${account.id}',
          value: account.accessKeySecret,
        );
      }
    }
  }

  Future<void> deleteAccountSecret(String accountId) async {
    await _secureStorage.delete(key: 'aks_$accountId');
  }

  // ─── 存储桶配置 ──────────────────────────────────────────────────────────────

  Future<List<BucketConfig>> loadBucketConfigs() async {
    final jsonList = prefs.getStringList(_bucketsKey) ?? [];
    return jsonList.map(BucketConfig.fromJsonString).toList();
  }

  Future<void> saveBucketConfigs(List<BucketConfig> configs) async {
    final jsonList = configs.map((b) => b.toJsonString()).toList();
    await prefs.setStringList(_bucketsKey, jsonList);
  }

  // ─── 同步任务 ────────────────────────────────────────────────────────────────

  Future<List<SyncTask>> loadSyncTasks() async {
    final jsonList = prefs.getStringList(_tasksKey) ?? [];
    return jsonList.map(SyncTask.fromJsonString).toList();
  }

  Future<void> saveSyncTasks(List<SyncTask> tasks) async {
    final jsonList = tasks.map((t) => t.toJsonString()).toList();
    await prefs.setStringList(_tasksKey, jsonList);
  }

  // ─── 同步日志 ────────────────────────────────────────────────────────────────

  Future<List<SyncLog>> loadSyncLogs() async {
    final jsonList = prefs.getStringList(_logsKey) ?? [];
    return jsonList.map(SyncLog.fromJsonString).toList();
  }

  Future<void> appendSyncLog(SyncLog log) async {
    final jsonList = prefs.getStringList(_logsKey) ?? [];
    jsonList.insert(0, log.toJsonString()); // 最新在前
    // 限制日志数量
    final trimmed = jsonList.length > _maxLogs
        ? jsonList.sublist(0, _maxLogs)
        : jsonList;
    await prefs.setStringList(_logsKey, trimmed);
  }

  Future<void> clearLogs() async {
    await prefs.remove(_logsKey);
  }

  Future<void> clearLogsByTask(String taskId) async {
    final jsonList = prefs.getStringList(_logsKey) ?? [];
    final filtered = jsonList.where((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return map['taskId'] != taskId;
      } catch (_) {
        return false;
      }
    }).toList();
    await prefs.setStringList(_logsKey, filtered);
  }
}
