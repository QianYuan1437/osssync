import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';
import '../utils/app_navigator.dart';
import '../widgets/common_widgets.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: '账户管理',
            actions: [
              FilledButton.icon(
                onPressed: () => AppNavigator.toNewAccount(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增账户'),
              ),
            ],
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.accounts.isEmpty
                    ? EmptyState(
                        icon: Icons.manage_accounts_outlined,
                        message: '暂无账户，请先添加阿里云账户',
                        action: TextButton(
                          onPressed: () => AppNavigator.toNewAccount(context),
                          child: const Text('添加账户'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: provider.accounts.length,
                        itemBuilder: (context, index) {
                          final account = provider.accounts[index];
                          final buckets = provider
                              .getBucketConfigsByAccount(account.id);
                          return _AccountCard(
                            account: account,
                            buckets: buckets,
                            onEdit: () =>
                                AppNavigator.toEditAccount(context, account.id),
                            onDelete: () =>
                                _confirmDelete(context, provider, account),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AccountProvider provider, AccountModel account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账户'),
        content: Text(
            '确定要删除账户「${account.name}」吗？\n关联的存储桶配置也将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteAccount(account.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final List<BucketConfig> buckets;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.buckets,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person,
                      color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        'AccessKey ID: ${_maskKey(account.accessKeyId)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: '编辑',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                  tooltip: '删除',
                  color: Colors.red,
                ),
              ],
            ),
            if (buckets.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text('关联存储桶 (${buckets.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: buckets
                    .map((b) => _BucketChip(bucket: b))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }
}

class _BucketChip extends StatelessWidget {
  final BucketConfig bucket;
  const _BucketChip({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage, size: 12,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '${bucket.bucketName} (${bucket.region})',
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
