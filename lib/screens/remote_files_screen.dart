import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sync_task.dart';
import '../providers/account_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/common_widgets.dart';
import '../utils/app_navigator.dart';

/// 远程文件模块主页面
/// 用于选择同步任务对应的云端存储桶，然后进入云端文件浏览器
class RemoteFilesScreen extends StatelessWidget {
  const RemoteFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final tasks = syncProvider.tasks;
    final locale = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: locale.t('远程文件', 'Remote Files'),
          ),
          Expanded(
            child: tasks.isEmpty
                ? EmptyState(
                    icon: Icons.cloud_off,
                    message: locale.t('暂无同步任务，请先创建任务', 'No sync tasks, please create one first'),
                    action: TextButton.icon(
                      onPressed: () => AppNavigator.toNewTask(context),
                      icon: const Icon(Icons.add),
                      label: Text(locale.t('创建任务', 'Create Task')),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final account = accountProvider.getAccountById(task.accountId);
                      final bucket = accountProvider.getBucketConfigById(task.bucketConfigId);

                      return _TaskCard(
                        task: task,
                        accountName: account?.name ?? locale.t('未知账户', 'Unknown Account'),
                        bucketName: bucket?.bucketName ?? locale.t('未知存储桶', 'Unknown Bucket'),
                        region: bucket?.region ?? '',
                        onTap: () {
                          if (account != null && bucket != null) {
                            AppNavigator.toRemoteBrowser(context, account.id, bucket.id);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 任务卡片，点击进入云端文件浏览器
class _TaskCard extends StatelessWidget {
  final SyncTask task;
  final String accountName;
  final String bucketName;
  final String region;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.accountName,
    required this.bucketName,
    required this.region,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sync,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$accountName / $bucketName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${locale.t('远程路径', 'Remote Path')}: ${task.remotePath}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
