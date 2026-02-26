import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sync_task.dart';
import '../providers/account_provider.dart';
import '../providers/sync_provider.dart';
import '../services/storage_service.dart';
import '../utils/app_navigator.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final tasks = syncProvider.tasks;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题栏
          PageHeader(
            title: '控制台',
            actions: [
              FilledButton.icon(
                onPressed: syncProvider.hasAnySyncing
                    ? null
                    : () => syncProvider.runAllEnabledTasks(),
                icon: syncProvider.hasAnySyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(syncProvider.hasAnySyncing ? '同步中...' : '立即同步全部'),
              ),
            ],
          ),
          // 统计卡片
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                _StatCard(
                  icon: Icons.manage_accounts,
                  label: '账户数',
                  value: '${accountProvider.accounts.length}',
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.sync,
                  label: '同步任务',
                  value: '${tasks.length}',
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.check_circle,
                  label: '已启用',
                  value: '${tasks.where((t) => t.isEnabled).length}',
                  color: Colors.teal,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.error_outline,
                  label: '错误任务',
                  value:
                      '${tasks.where((t) => t.status == SyncStatus.error).length}',
                  color: Colors.red,
                ),
              ],
            ),
          ),
          // 任务列表
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                Text('同步任务状态',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('管理任务'),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? EmptyState(
                    icon: Icons.sync_disabled,
                    message: '暂无同步任务',
                    action: TextButton(
                      onPressed: () => AppNavigator.toNewTask(context),
                      child: const Text('创建第一个同步任务'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final account =
                          accountProvider.getAccountById(task.accountId);
                      final bucket = accountProvider
                          .getBucketConfigById(task.bucketConfigId);
                      return _TaskStatusCard(
                        task: task,
                        accountName: account?.name ?? '未知账户',
                        bucketName: bucket?.bucketName ?? '未知存储桶',
                        progress: syncProvider.getProgress(task.id),
                        onSync: () => syncProvider.runSync(task.id),
                        onEdit: () => AppNavigator.toEditTask(context, task.id),
                      );
                    },
                  ),
          ),
          // 应用设置区域
          const Divider(height: 1),
          _AppSettingsSection(),
        ],
      ),
    );
  }
}

/// 控制台底部应用设置区域
class _AppSettingsSection extends StatefulWidget {
  const _AppSettingsSection();

  @override
  State<_AppSettingsSection> createState() => _AppSettingsSectionState();
}

class _AppSettingsSectionState extends State<_AppSettingsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 折叠标题行
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '应用设置',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            _CloseActionSetting(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// 关闭行为设置项
class _CloseActionSetting extends StatefulWidget {
  const _CloseActionSetting();

  @override
  State<_CloseActionSetting> createState() => _CloseActionSettingState();
}

class _CloseActionSettingState extends State<_CloseActionSetting> {
  late String _closeAction;
  late bool _isSet;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final storage = context.read<StorageService>();
    _closeAction = storage.getCloseAction();
    _isSet = storage.isCloseActionSet();
  }

  Future<void> _onActionChanged(String? value) async {
    if (value == null) return;
    final storage = context.read<StorageService>();
    await storage.saveCloseAction(value);
    await storage.setCloseActionConfirmed();
    setState(() {
      _closeAction = value;
      _isSet = true;
    });
  }

  Future<void> _onResetSetting() async {
    final storage = context.read<StorageService>();
    await storage.resetCloseActionSetting();
    setState(() => _isSet = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已重置，下次关闭时将重新询问'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.close,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '关闭窗口行为',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              if (!_isSet)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '未设置',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SettingRadioChip(
                label: '最小化到系统托盘',
                icon: Icons.minimize,
                value: 'minimize',
                groupValue: _closeAction,
                onChanged: _onActionChanged,
              ),
              const SizedBox(width: 10),
              _SettingRadioChip(
                label: '退出程序',
                icon: Icons.exit_to_app,
                value: 'exit',
                groupValue: _closeAction,
                onChanged: _onActionChanged,
              ),
              const Spacer(),
              if (_isSet)
                TextButton.icon(
                  onPressed: _onResetSetting,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('重置（下次询问）'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    textStyle: theme.textTheme.bodySmall,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isSet
                ? '当前设置：点击关闭按钮将${_closeAction == 'minimize' ? '最小化到系统托盘' : '退出程序'}'
                : '尚未设置，下次点击关闭按钮时将弹出选择对话框',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单选样式的 Chip 按钮
class _SettingRadioChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _SettingRadioChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(label,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskStatusCard extends StatelessWidget {
  final SyncTask task;
  final String accountName;
  final String bucketName;
  final String? progress;
  final VoidCallback onSync;
  final VoidCallback onEdit;

  const _TaskStatusCard({
    required this.task,
    required this.accountName,
    required this.bucketName,
    this.progress,
    required this.onSync,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSyncing = task.status == SyncStatus.syncing;
    final isError = task.status == SyncStatus.error;

    Color statusColor;
    IconData statusIcon;
    switch (task.status) {
      case SyncStatus.syncing:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.sync;
        break;
      case SyncStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case SyncStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case SyncStatus.idle:
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusIcon = Icons.radio_button_unchecked;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 状态图标
                isSyncing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: statusColor,
                        ),
                      )
                    : Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Text(task.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (!task.isEnabled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('已禁用',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: onEdit,
                  tooltip: '编辑',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: isSyncing ? null : onSync,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(isSyncing ? '同步中' : '立即同步',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 进度消息
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  progress!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            // 详情信息
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _InfoChip(
                    icon: Icons.folder_outlined, label: task.localPath),
                _InfoChip(
                    icon: Icons.cloud_outlined,
                    label: '$bucketName/${task.remotePath}'),
                _InfoChip(
                    icon: Icons.swap_horiz,
                    label: task.syncDirection.label),
                if (task.intervalMinutes > 0)
                  _InfoChip(
                      icon: Icons.schedule,
                      label: '每 ${task.intervalMinutes} 分钟'),
                if (task.lastSyncAt != null)
                  _InfoChip(
                      icon: Icons.access_time,
                      label:
                          '上次: ${DateFormat('MM-dd HH:mm').format(task.lastSyncAt!.toLocal())}'),
              ],
            ),
            if (isError && task.lastError != null) ...[
              const SizedBox(height: 6),
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
                        maxLines: 2,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
