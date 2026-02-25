import 'package:flutter/material.dart';
import '../screens/account_edit_screen.dart';
import '../screens/sync_task_edit_screen.dart';

/// 应用内页面导航辅助类
/// 使用原生 Navigator.push 替代 go_router，避免 IndexedStack 中的 context 问题
class AppNavigator {
  /// 跳转到新建账户页
  static Future<void> toNewAccount(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const AccountEditScreen()),
    );
  }

  /// 跳转到编辑账户页
  static Future<void> toEditAccount(BuildContext context, String accountId) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
          builder: (_) => AccountEditScreen(accountId: accountId)),
    );
  }

  /// 跳转到新建同步任务页
  static Future<void> toNewTask(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const SyncTaskEditScreen()),
    );
  }

  /// 跳转到编辑同步任务页
  static Future<void> toEditTask(BuildContext context, String taskId) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
          builder: (_) => SyncTaskEditScreen(taskId: taskId)),
    );
  }

  /// 返回上一页
  static void pop(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
