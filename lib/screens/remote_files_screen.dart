import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/common_widgets.dart';
import '../utils/app_navigator.dart';

/// 远程文件模块主页面
/// 用于选择账户和存储桶，然后进入云端文件浏览器
class RemoteFilesScreen extends StatelessWidget {
  const RemoteFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;
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
            child: accounts.isEmpty
                ? EmptyState(
                    icon: Icons.cloud_off,
                    message: locale.t('暂无账户，请先创建账户', 'No accounts, please create one first'),
                    action: TextButton.icon(
                      onPressed: () => AppNavigator.toNewAccount(context),
                      icon: const Icon(Icons.add),
                      label: Text(locale.t('创建账户', 'Create Account')),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final bucketConfigs = accountProvider.getBucketConfigsByAccount(account.id);
                      
                      return _AccountCard(
                        accountName: account.name,
                        bucketConfigs: bucketConfigs,
                        onBucketTap: (bucketConfig) {
                          AppNavigator.toRemoteBrowser(context, account.id, bucketConfig.id);
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

/// 账户卡片，显示该账户下的所有存储桶
class _AccountCard extends StatelessWidget {
  final String accountName;
  final List bucketConfigs;
  final Function(dynamic bucketConfig) onBucketTap;

  const _AccountCard({
    required this.accountName,
    required this.bucketConfigs,
    required this.onBucketTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(
          accountName,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          locale.t('${bucketConfigs.length} 个存储桶', '${bucketConfigs.length} buckets'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: bucketConfigs.map((bucket) {
          return ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            leading: Icon(
              Icons.cloud_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            title: Text(bucket.name),
            subtitle: Text(
              '${bucket.bucketName} (${bucket.region})',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onBucketTap(bucket),
          );
        }).toList(),
      ),
    );
  }
}
