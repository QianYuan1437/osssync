import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sync_task.dart';
import '../providers/account_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_navigator.dart';
import '../widgets/common_widgets.dart';

class SyncTasksScreen extends StatelessWidget {
  const SyncTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final tasks = syncProvider.tasks;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: context.watch<LocaleProvider>().t('同步任务', 'Sync Tasks'),
            actions: [
              FilledButton.icon(
                onPressed: () => AppNavigator.toNewTask(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.watch<LocaleProvider>().t('新建任务', 'New Task')),
              ),
            ],
          ),
          Expanded(
            child: tasks.isEmpty
                ? EmptyState(
                    icon: Icons.sync_disabled,
                    message: context.watch<LocaleProvider>().t('暂无同步任务', 'No sync tasks'),
                    action: TextButton(
                      onPressed: () => AppNavigator.toNewTask(context),
                      child: Text(context.watch<LocaleProvider>().t('创建第一个同步任务', 'Create First Task')),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final account =
                          accountProvider.getAccountById(task.accountId);
                      final bucket = accountProvider
                          .getBucketConfigById(task.bucketConfigId);
                      return _TaskCard(
                        task: task,
                        accountName: account?.name ?? context.watch<LocaleProvider>().t('未知账户', 'Unknown Account'),
                        bucketName: bucket?.bucketName ?? context.watch<LocaleProvider>().t('未知存储桶', 'Unknown Bucket'),
                        isSyncing: syncProvider.isSyncing(task.id),
                        progress: syncProvider.getProgress(task.id),
                        onSync: () => syncProvider.runSync(task.id),
                        onToggle: () =>
                            syncProvider.toggleTaskEnabled(task.id),
                        onEdit: () => AppNavigator.toEditTask(context, task.id),
                        onDelete: () =>
                            _confirmDelete(context, syncProvider, task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, SyncProvider provider, SyncTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.read<LocaleProvider>().t('删除任务', 'Delete Task')),
        content: Text(context.read<LocaleProvider>().t(
          '确定要删除同步任务「${task.name}」吗？\n相关日志也将一并删除。',
          'Delete task "${task.name}"?\nRelated logs will also be deleted.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.read<LocaleProvider>().t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteTask(task.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.read<LocaleProvider>().t('删除', 'Delete')),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final SyncTask task;
  final String accountName;
  final String bucketName;
  final bool isSyncing;
  final String? progress;
  final VoidCallback onSync;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.accountName,
    required this.bucketName,
    required this.isSyncing,
    this.progress,
    required this.onSync,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    switch (task.status) {
      case SyncStatus.syncing:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.sync;
        break;
      case SyncStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case SyncStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      case SyncStatus.idle:
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusIcon = Icons.radio_button_unchecked;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                isSyncing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: statusColor),
                      )
                    : Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                // 启用/禁用开关
                Switch(
                  value: task.isEnabled,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                // 操作按钮
                FilledButton.tonal(
                  onPressed: isSyncing ? null : onSync,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  child: Text(context.watch<LocaleProvider>().t(
                    isSyncing ? '同步中' : '立即同步',
                    isSyncing ? 'Syncing' : 'Sync Now',
                  ), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit', child: Text(context.read<LocaleProvider>().t('编辑任务', 'Edit'))),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text(context.read<LocaleProvider>().t('删除任务', 'Delete'),
                            style: const TextStyle(color: Colors.red))),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                ),
              ],
            ),
            // 进度消息
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  progress!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            // 详情信息网格
            _InfoGrid(children: [
              _InfoItem(
                  icon: Icons.person_outline,
                  label: context.watch<LocaleProvider>().t('账户', 'Account'),
                  value: accountName),
              _InfoItem(
                  icon: Icons.storage_outlined,
                  label: context.watch<LocaleProvider>().t('存储桶', 'Bucket'),
                  value: bucketName),
              _InfoItem(
                  icon: Icons.folder_outlined,
                  label: context.watch<LocaleProvider>().t('本地路径', 'Local Path'),
                  value: task.localPath),
              _InfoItem(
                  icon: Icons.cloud_outlined,
                  label: context.watch<LocaleProvider>().t('OSS 路径', 'OSS Path'),
                  value: task.remotePath.isEmpty ? context.watch<LocaleProvider>().t('根目录', 'Root') : task.remotePath),
              _InfoItem(
                  icon: Icons.swap_horiz,
                  label: context.watch<LocaleProvider>().t('同步方向', 'Direction'),
                  value: task.syncDirection.label),
              _InfoItem(
                  icon: Icons.schedule,
                  label: context.watch<LocaleProvider>().t('同步间隔', 'Interval'),
                  value: context.watch<LocaleProvider>().t(
                    task.intervalMinutes > 0 ? '每 ${task.intervalMinutes} 分钟' : '仅手动',
                    task.intervalMinutes > 0 ? 'Every ${task.intervalMinutes} min' : 'Manual',
                  )),
              if (task.lastSyncAt != null)
                _InfoItem(
                    icon: Icons.access_time,
                    label: context.watch<LocaleProvider>().t('上次同步', 'Last Sync'),
                    value: DateFormat('yyyy-MM-dd HH:mm')
                        .format(task.lastSyncAt!.toLocal())),
            ]),
            // 错误信息
            if (task.status == SyncStatus.error && task.lastError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.lastError!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.red),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> children;
  const _InfoGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: children,
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            value,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
