import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../models/sync_task.dart';

/// 文件预览页面：展示各同步任务本地文件夹内容，支持打开文件资源管理器
class FilePreviewScreen extends StatefulWidget {
  const FilePreviewScreen({super.key});

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  SyncTask? _selectedTask;
  String? _currentPath;
  List<FileSystemEntity> _entries = [];
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tasks = context.read<SyncProvider>().tasks;
    if (_selectedTask == null && tasks.isNotEmpty) {
      _selectTask(tasks.first);
    }
  }

  void _selectTask(SyncTask task) {
    setState(() {
      _selectedTask = task;
      _currentPath = task.localPath;
    });
    _loadDirectory(task.localPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        setState(() {
          _entries = [];
          _error = '目录不存在：$path';
          _loading = false;
        });
        return;
      }
      final list = await dir.list(followLinks: false).toList();
      list.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      setState(() {
        _entries = list;
        _currentPath = path;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '读取目录失败：$e';
        _loading = false;
      });
    }
  }

  /// 用系统文件资源管理器打开指定路径
  Future<void> _openInExplorer(String path) async {
    try {
      final target = FileSystemEntity.isDirectorySync(path) ? path : File(path).parent.path;
      await Process.run('explorer.exe', [target]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开资源管理器：$e')),
        );
      }
    }
  }

  /// 导航到子目录
  void _navigateTo(String path) {
    _loadDirectory(path);
  }

  /// 返回上级目录（不超过任务根目录）
  void _navigateUp() {
    if (_currentPath == null || _selectedTask == null) return;
    final root = _selectedTask!.localPath;
    if (_currentPath == root) return;
    final parent = Directory(_currentPath!).parent.path;
    _loadDirectory(parent);
  }

  bool get _canGoUp {
    if (_currentPath == null || _selectedTask == null) return false;
    return _currentPath != _selectedTask!.localPath;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = context.watch<SyncProvider>().tasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部标题栏
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_open, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                '文件预览',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_currentPath != null)
                TextButton.icon(
                  onPressed: () => _openInExplorer(_currentPath!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('在资源管理器中打开'),
                ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? _buildEmpty(theme)
              : Row(
                  children: [
                    // 左侧任务列表
                    _TaskList(
                      tasks: tasks,
                      selected: _selectedTask,
                      onSelect: _selectTask,
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    // 右侧文件列表
                    Expanded(
                      child: Column(
                        children: [
                          _BreadcrumbBar(
                            currentPath: _currentPath,
                            rootPath: _selectedTask?.localPath,
                            canGoUp: _canGoUp,
                            onGoUp: _navigateUp,
                            onOpenExplorer: _currentPath != null
                                ? () => _openInExplorer(_currentPath!)
                                : null,
                          ),
                          Expanded(
                            child: _loading
                                ? const Center(child: CircularProgressIndicator())
                                : _error != null
                                    ? _buildError(theme)
                                    : _buildFileList(theme),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('暂无同步任务', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('请先在「同步任务」页面创建任务',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(_error!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildFileList(ThemeData theme) {
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          '此文件夹为空',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entity = _entries[index];
        final isDir = entity is Directory;
        final name = entity.path.split(Platform.pathSeparator).last;
        FileStat? stat;
        try {
          stat = entity.statSync();
        } catch (_) {}

        return _FileListTile(
          name: name,
          isDirectory: isDir,
          stat: stat,
          onTap: isDir
              ? () => _navigateTo(entity.path)
              : () => _openInExplorer(entity.path),
          onOpenExplorer: () => _openInExplorer(entity.path),
        );
      },
    );
  }
}

// ─── 左侧任务列表 ─────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<SyncTask> tasks;
  final SyncTask? selected;
  final ValueChanged<SyncTask> onSelect;

  const _TaskList({
    required this.tasks,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '同步任务',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: tasks.length,
              itemBuilder: (context, i) {
                final task = tasks[i];
                final isSelected = selected?.id == task.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        task.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : null,
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        task.localPath,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelect(task),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 面包屑导航栏 ─────────────────────────────────────────────────────────────

class _BreadcrumbBar extends StatelessWidget {
  final String? currentPath;
  final String? rootPath;
  final bool canGoUp;
  final VoidCallback onGoUp;
  final VoidCallback? onOpenExplorer;

  const _BreadcrumbBar({
    required this.currentPath,
    required this.rootPath,
    required this.canGoUp,
    required this.onGoUp,
    this.onOpenExplorer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 16),
            onPressed: canGoUp ? onGoUp : null,
            tooltip: '返回上级',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              currentPath ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 文件列表项 ───────────────────────────────────────────────────────────────

class _FileListTile extends StatelessWidget {
  final String name;
  final bool isDirectory;
  final FileStat? stat;
  final VoidCallback onTap;
  final VoidCallback onOpenExplorer;

  const _FileListTile({
    required this.name,
    required this.isDirectory,
    required this.stat,
    required this.onTap,
    required this.onOpenExplorer,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        isDirectory ? Icons.folder : _fileIcon(name),
        size: 20,
        color: isDirectory
            ? const Color(0xFFFFA726)
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(name, style: theme.textTheme.bodyMedium),
      subtitle: stat != null
          ? Text(
              isDirectory
                  ? _formatDate(stat!.modified)
                  : '${_formatSize(stat!.size)}  ·  ${_formatDate(stat!.modified)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new, size: 16),
        tooltip: '在资源管理器中打开',
        onPressed: onOpenExplorer,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
      onTap: onTap,
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image_outlined;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file_outlined;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_outlined;
      case 'txt':
      case 'md':
      case 'log':
        return Icons.description_outlined;
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'java':
      case 'cpp':
      case 'c':
      case 'h':
        return Icons.code_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
