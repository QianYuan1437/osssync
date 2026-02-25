import 'dart:async';
import '../models/sync_task.dart';

/// 定时任务调度器，为每个启用的同步任务维护独立的 Timer
class SchedulerService {
  final Map<String, Timer> _timers = {};

  /// 当定时器触发时的回调，参数为 taskId
  void Function(String taskId)? onTrigger;

  /// 注册或更新一个任务的定时器
  void scheduleTask(SyncTask task) {
    // 先取消旧的
    cancelTask(task.id);

    if (!task.isEnabled || task.intervalMinutes <= 0) return;

    final interval = Duration(minutes: task.intervalMinutes);
    _timers[task.id] = Timer.periodic(interval, (_) {
      onTrigger?.call(task.id);
    });
  }

  /// 取消某个任务的定时器
  void cancelTask(String taskId) {
    _timers[taskId]?.cancel();
    _timers.remove(taskId);
  }

  /// 重新加载所有任务的定时器
  void reloadAll(List<SyncTask> tasks) {
    cancelAll();
    for (final task in tasks) {
      scheduleTask(task);
    }
  }

  /// 取消所有定时器
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  bool isScheduled(String taskId) => _timers.containsKey(taskId);

  void dispose() {
    cancelAll();
  }
}
