import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sync_log.dart';
import '../providers/sync_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/common_widgets.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel? _filterLevel;
  String? _filterTaskId;

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final allLogs = syncProvider.logs;

    // 过滤
    final logs = allLogs.where((l) {
      if (_filterLevel != null && l.level != _filterLevel) return false;
      if (_filterTaskId != null && l.taskId != _filterTaskId) return false;
      return true;
    }).toList();

    // 获取所有任务名称用于筛选
    final taskNames = <String, String>{};
    for (final log in allLogs) {
      taskNames[log.taskId] = log.taskName;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: context.watch<LocaleProvider>().t('同步日志', 'Sync Logs'),
            actions: [
              if (allLogs.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _confirmClear(context, syncProvider),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text(context.watch<LocaleProvider>().t('清空日志', 'Clear Logs')),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
          // 筛选栏
          if (allLogs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(
                children: [
                  // 级别筛选
                  _FilterChip(
                    label: context.watch<LocaleProvider>().t('全部级别', 'All Levels'),
                    isSelected: _filterLevel == null,
                    onTap: () => setState(() => _filterLevel = null),
                  ),
                  const SizedBox(width: 6),
                  ...LogLevel.values.map((level) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChip(
                          label: level.label,
                          isSelected: _filterLevel == level,
                          color: _levelColor(level),
                          onTap: () => setState(() => _filterLevel =
                              _filterLevel == level ? null : level),
                        ),
                      )),
                  const SizedBox(width: 12),
                  // 任务筛选
                  if (taskNames.length > 1)
                    DropdownButton<String?>(
                      value: _filterTaskId,
                      hint: Text(context.watch<LocaleProvider>().t('全部任务', 'All Tasks')),
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                            value: null, child: Text(context.read<LocaleProvider>().t('全部任务', 'All Tasks'))),
                        ...taskNames.entries.map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            )),
                      ],
                      onChanged: (v) => setState(() => _filterTaskId = v),
                    ),
                ],
              ),
            ),
          // 日志列表
          Expanded(
            child: logs.isEmpty
                ? EmptyState(
                    icon: Icons.history_outlined,
                    message: context.watch<LocaleProvider>().t(
                      allLogs.isEmpty ? '暂无同步日志' : '没有符合条件的日志',
                      allLogs.isEmpty ? 'No sync logs' : 'No matching logs',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return _LogCard(log: logs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, SyncProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.read<LocaleProvider>().t('清空日志', 'Clear Logs')),
        content: Text(context.read<LocaleProvider>().t('确定要清空所有同步日志吗？此操作不可撤销。', 'Clear all logs? This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.read<LocaleProvider>().t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              provider.clearAllLogs();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.read<LocaleProvider>().t('清空', 'Clear')),
          ),
        ],
      ),
    );
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.success:
        return Colors.green;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: chipColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected ? chipColor : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final SyncLog log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelColor = _levelColor(log.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 级别标签
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.level.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: levelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 任务名称
                Text(
                  log.taskName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // 复制按钮
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: context.watch<LocaleProvider>().t('复制日志', 'Copy Log'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _copyLog(context),
                ),
                const SizedBox(width: 8),
                // 时间
                Text(
                  DateFormat('MM-dd HH:mm:ss').format(log.timestamp.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (log.duration != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(log.duration!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // 消息
            Text(
              log.message,
              style: theme.textTheme.bodySmall,
            ),
            // 统计信息
            if (log.filesUploaded > 0 ||
                log.filesDownloaded > 0 ||
                log.filesSkipped > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  if (log.filesUploaded > 0)
                    _StatBadge(
                        icon: Icons.upload,
                        label: context.watch<LocaleProvider>().t('上传 ${log.filesUploaded}', 'Upload ${log.filesUploaded}'),
                        color: Colors.blue),
                  if (log.filesDownloaded > 0)
                    _StatBadge(
                        icon: Icons.download,
                        label: context.watch<LocaleProvider>().t('下载 ${log.filesDownloaded}', 'Download ${log.filesDownloaded}'),
                        color: Colors.green),
                  if (log.filesSkipped > 0)
                    _StatBadge(
                        icon: Icons.skip_next,
                        label: context.watch<LocaleProvider>().t('跳过 ${log.filesSkipped}', 'Skip ${log.filesSkipped}'),
                        color: Colors.grey),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyLog(BuildContext context) {
    final locale = context.read<LocaleProvider>();
    final buffer = StringBuffer();
    buffer.writeln('【${log.level.label}】${log.taskName}');
    buffer.writeln('${locale.t('时间', 'Time')}: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp.toLocal())}');
    if (log.duration != null) {
      buffer.writeln('${locale.t('耗时', 'Duration')}: ${_formatDuration(log.duration!)}');
    }
    buffer.writeln('${locale.t('消息', 'Message')}: ${log.message}');
    if (log.filesUploaded > 0 || log.filesDownloaded > 0 || log.filesSkipped > 0) {
      buffer.writeln('${locale.t('统计', 'Stats')}: ${locale.t('上传', 'Upload')}${log.filesUploaded} ${locale.t('下载', 'Download')}${log.filesDownloaded} ${locale.t('跳过', 'Skip')}${log.filesSkipped}');
    }
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(locale.t('日志已复制到剪贴板', 'Log copied to clipboard')), duration: const Duration(seconds: 2)),
    );
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.success:
        return Colors.green;
    }
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m${d.inSeconds % 60}s';
    return '${d.inHours}h${d.inMinutes % 60}m';
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}
