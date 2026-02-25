import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sync_log.dart';
import '../providers/sync_provider.dart';
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
            title: '同步日志',
            actions: [
              if (allLogs.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _confirmClear(context, syncProvider),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('清空日志'),
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
                    label: '全部级别',
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
                      hint: const Text('全部任务'),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('全部任务')),
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
                    message: allLogs.isEmpty ? '暂无同步日志' : '没有符合条件的日志',
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
        title: const Text('清空日志'),
        content: const Text('确定要清空所有同步日志吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              provider.clearAllLogs();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
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
                        label: '上传 ${log.filesUploaded}',
                        color: Colors.blue),
                  if (log.filesDownloaded > 0)
                    _StatBadge(
                        icon: Icons.download,
                        label: '下载 ${log.filesDownloaded}',
                        color: Colors.green),
                  if (log.filesSkipped > 0)
                    _StatBadge(
                        icon: Icons.skip_next,
                        label: '跳过 ${log.filesSkipped}',
                        color: Colors.grey),
                ],
              ),
            ],
          ],
        ),
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
