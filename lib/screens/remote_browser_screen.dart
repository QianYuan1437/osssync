import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';
import '../providers/account_provider.dart';
import '../providers/locale_provider.dart';
import '../services/oss_service.dart';
import '../widgets/common_widgets.dart';

/// 云端文件浏览器页面
/// 支持浏览、上传、下载、删除云端文件，支持批量操作
class RemoteBrowserScreen extends StatefulWidget {
  final String accountId;
  final String bucketConfigId;

  const RemoteBrowserScreen({
    super.key,
    required this.accountId,
    required this.bucketConfigId,
  });

  @override
  State<RemoteBrowserScreen> createState() => _RemoteBrowserScreenState();
}

class _RemoteBrowserScreenState extends State<RemoteBrowserScreen> {
  OssService? _ossService;
  List<OssObject> _allObjects = []; // 原始对象列表
  List<OssObject> _displayedObjects = []; // 显示的对象列表（文件夹+文件）
  List<String> _folderNames = []; // 当前层的文件夹列表
  Set<String> _selectedFileKeys = {}; // 选中的文件key集合
  List<String> _prefixStack = ['']; // 目录导航栈
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _currentPrefix;
  String _searchQuery = '';

  AccountModel? _account;
  BucketConfig? _bucketConfig;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initOssService();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _initOssService() {
    final accountProvider = context.read<AccountProvider>();
    _account = accountProvider.getAccountById(widget.accountId);
    _bucketConfig = accountProvider.getBucketConfigById(widget.bucketConfigId);

    if (_account != null && _bucketConfig != null) {
      _ossService = OssService(account: _account!, bucket: _bucketConfig!);
      _isInitialized = true;
      _loadObjects();
    }
  }

  Future<void> _loadObjects() async {
    if (_ossService == null || !_isInitialized) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _selectedFileKeys.clear();
    });

    try {
      final prefix = _prefixStack.isEmpty ? '' : _prefixStack.last;
      _currentPrefix = prefix;
      final objects = await _ossService!.listObjects(prefix);
      setState(() {
        _allObjects = objects;
        _processDisplayObjects();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _processDisplayObjects() {
    final relativePrefix = _currentPrefix ?? '';

    // 提取当前层的文件夹
    final currentFolders = <String>{};
    final currentFiles = <OssObject>[];

    for (final obj in _allObjects) {
      final relativeKey = obj.key.replaceFirst(relativePrefix, '');
      if (relativeKey.isEmpty) continue;

      if (relativeKey.contains('/')) {
        final folderName = relativeKey.split('/').first;
        currentFolders.add(folderName);
      } else {
        currentFiles.add(obj);
      }
    }

    _folderNames = currentFolders.toList()..sort();
    _displayedObjects = currentFiles..sort((a, b) => a.key.compareTo(b.key));

    // 应用搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      _displayedObjects = _displayedObjects
          .where((obj) => obj.key.toLowerCase().contains(query))
          .toList();
    }
  }

  void _navigateToPrefix(String prefix) {
    setState(() {
      if (prefix.isEmpty) {
        _prefixStack = [''];
      } else {
        _prefixStack.add(prefix);
      }
    });
    _loadObjects();
  }

  void _navigateUp() {
    if (_prefixStack.length > 1) {
      setState(() {
        _prefixStack.removeLast();
      });
      _loadObjects();
    }
  }

  void _navigateToRoot() {
    setState(() {
      _prefixStack = [''];
    });
    _loadObjects();
  }

  String get _currentPath {
    if (_prefixStack.isEmpty || _prefixStack.last.isEmpty) {
      return '/';
    }
    return '/${_prefixStack.last}';
  }

  List<String> get _pathSegments {
    if (_prefixStack.isEmpty || _prefixStack.first.isEmpty) {
      return [];
    }
    return _prefixStack.last.split('/').where((s) => s.isNotEmpty).toList();
  }

  bool get _hasSelection => _selectedFileKeys.isNotEmpty;
  bool get _isAllSelected =>
      _displayedObjects.isNotEmpty &&
      _selectedFileKeys.length == _displayedObjects.length;

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedFileKeys.clear();
      } else {
        _selectedFileKeys = _displayedObjects.map((obj) => obj.key).toSet();
      }
    });
  }

  void _toggleFileSelection(String key) {
    setState(() {
      if (_selectedFileKeys.contains(key)) {
        _selectedFileKeys.remove(key);
      } else {
        _selectedFileKeys.add(key);
      }
    });
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFileKeys.isEmpty || _ossService == null) return;

    final locale = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale.t('确认删除', 'Confirm Delete')),
        content: Text(locale.t(
          '确定要删除选中的 ${_selectedFileKeys.length} 个文件吗？此操作不可撤销。',
          'Are you sure you want to delete ${_selectedFileKeys.length} selected files? This cannot be undone.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(locale.t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(locale.t('删除', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      int successCount = 0;
      int failCount = 0;

      for (final key in _selectedFileKeys.toList()) {
        try {
          await _ossService!.deleteObject(key);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      setState(() {
        _selectedFileKeys.clear();
        _isLoading = false;
      });

      if (mounted) {
        _showMessage(locale.t(
          '删除完成：成功 $successCount 个，失败 $failCount 个',
          'Delete complete: $successCount succeeded, $failCount failed',
        ));
        _loadObjects();
      }
    }
  }

  Future<void> _uploadFile() async {
    final pathController = TextEditingController();
    final objectKeyController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.read<LocaleProvider>().t('上传文件', 'Upload File')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathController,
              decoration: InputDecoration(
                labelText: context.read<LocaleProvider>().t('本地文件路径', 'Local File Path'),
                hintText: context.read<LocaleProvider>().t('例如: C:\\test\\file.txt', 'e.g. C:\\test\\file.txt'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: objectKeyController,
              decoration: InputDecoration(
                labelText: context.read<LocaleProvider>().t('云端对象键', 'Object Key'),
                hintText: context.read<LocaleProvider>().t('例如: folder/file.txt', 'e.g. folder/file.txt'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.read<LocaleProvider>().t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.read<LocaleProvider>().t('上传', 'Upload')),
          ),
        ],
      ),
    );

    if (result == true && _ossService != null) {
      final localPath = pathController.text.trim();
      final objectKey = objectKeyController.text.trim();

      if (localPath.isEmpty || objectKey.isEmpty) {
        _showMessage(context.read<LocaleProvider>().t('请填写完整信息', 'Please fill in all fields'));
        return;
      }

      final fullObjectKey = '${_currentPrefix ?? ''}$objectKey';

      setState(() => _isLoading = true);
      try {
        await _ossService!.uploadFile(localPath, fullObjectKey);
        _showMessage(context.read<LocaleProvider>().t('上传成功', 'Upload successful'));
        _loadObjects();
      } catch (e) {
        _showMessage('${context.read<LocaleProvider>().t('上传失败', 'Upload failed')}: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadFile(OssObject obj) async {
    final pathController = TextEditingController(
      text: Platform.isWindows
          ? 'C:\\Downloads\\${obj.key.split('/').last}'
          : '/tmp/${obj.key.split('/').last}',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.read<LocaleProvider>().t('下载文件', 'Download File')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.read<LocaleProvider>().t('文件', 'File')}: ${obj.key}'),
            Text('${context.read<LocaleProvider>().t('大小', 'Size')}: ${_formatFileSize(obj.size)}'),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: InputDecoration(
                labelText: context.read<LocaleProvider>().t('保存路径', 'Save Path'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.read<LocaleProvider>().t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.read<LocaleProvider>().t('下载', 'Download')),
          ),
        ],
      ),
    );

    if (result == true && _ossService != null) {
      final savePath = pathController.text.trim();
      if (savePath.isEmpty) return;

      setState(() => _isLoading = true);
      try {
        await _ossService!.downloadFile(obj.key, savePath);
        _showMessage(context.read<LocaleProvider>().t('下载成功', 'Download successful'));
      } catch (e) {
        _showMessage('${context.read<LocaleProvider>().t('下载失败', 'Download failed')}: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteFile(OssObject obj) async {
    final locale = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale.t('确认删除', 'Confirm Delete')),
        content: Text(locale.t('确定要删除文件 "${obj.key}" 吗？此操作不可撤销。', 'Are you sure you want to delete "${obj.key}"? This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(locale.t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(locale.t('删除', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && _ossService != null) {
      setState(() => _isLoading = true);
      try {
        await _ossService!.deleteObject(obj.key);
        _showMessage(locale.t('删除成功', 'Delete successful'));
        _loadObjects();
      } catch (e) {
        _showMessage('${locale.t('删除失败', 'Delete failed')}: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _processDisplayObjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();
    final bucketName = _bucketConfig?.bucketName ?? '';

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        // Ctrl+A: 全选
        if (event is KeyDownEvent &&
            HardwareKeyboard.instance.isControlPressed &&
            event.logicalKey == LogicalKeyboardKey.keyA) {
          _toggleSelectAll();
        }
        // Delete: 删除选中
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.delete &&
            _hasSelection) {
          _deleteSelectedFiles();
        }
        // Escape: 取消选择
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => _selectedFileKeys.clear());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            PageHeader(
              title: locale.t('远程文件', 'Remote Files'),
              actions: [
                IconButton.outlined(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  tooltip: locale.t('返回', 'Back'),
                ),
                const SizedBox(width: 8),
                if (_hasSelection) ...[
                  FilledButton.icon(
                    onPressed: _deleteSelectedFiles,
                    icon: const Icon(Icons.delete, size: 18),
                    label: Text(locale.t('删除 (${_selectedFileKeys.length})', 'Delete (${_selectedFileKeys.length})')),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: _isLoading ? null : _uploadFile,
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: Text(locale.t('上传', 'Upload')),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _loadObjects,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  tooltip: locale.t('刷新', 'Refresh'),
                ),
              ],
            ),
            // 存储桶信息
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.cloud, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        bucketName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.folder, color: theme.colorScheme.secondary, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        _currentPath,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 路径导航和搜索
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  if (_prefixStack.length > 1)
                    IconButton.outlined(
                      onPressed: _navigateUp,
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      tooltip: locale.t('返回上级', 'Go Up'),
                    ),
                  if (_prefixStack.length > 1)
                    IconButton.outlined(
                      onPressed: _navigateToRoot,
                      icon: const Icon(Icons.home, size: 18),
                      tooltip: locale.t('返回根目录', 'Go to Root'),
                    ),
                  if (_prefixStack.length > 1) const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _navigateToRoot,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                bucketName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          ..._pathSegments.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final segment = entry.value;
                            final isLast = idx == _pathSegments.length - 1;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
                                InkWell(
                                  onTap: isLast ? null : () {
                                    final prefix = _pathSegments.sublist(0, idx + 1).join('/') + '/';
                                    _navigateToPrefix(prefix);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(
                                      segment,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isLast ? theme.colorScheme.onSurface : theme.colorScheme.primary,
                                        fontWeight: isLast ? FontWeight.w600 : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: locale.t('搜索文件', 'Search files'),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ],
              ),
            ),
            // 批量操作栏（当有选中项时显示）
            if (_hasSelection)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isAllSelected,
                      onChanged: (_) => _toggleSelectAll(),
                    ),
                    Text(locale.t('全选', 'Select All')),
                    const Spacer(),
                    Text(
                      locale.t('已选择 ${_selectedFileKeys.length} 个文件', '${_selectedFileKeys.length} files selected'),
                    ),
                  ],
                ),
              ),
            // 文件列表
            Expanded(
              child: _buildContent(theme, locale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, LocaleProvider locale) {
    if (_isLoading && _allObjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _allObjects.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        message: _error!,
        action: TextButton.icon(
          onPressed: _loadObjects,
          icon: const Icon(Icons.refresh),
          label: Text(locale.t('重试', 'Retry')),
        ),
      );
    }

    final totalItems = _folderNames.length + _displayedObjects.length;
    if (totalItems == 0) {
      return EmptyState(
        icon: _searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_open,
        message: _searchQuery.isNotEmpty
            ? locale.t('没有找到匹配的文件', 'No matching files found')
            : locale.t('该目录下暂无文件', 'No files in this directory'),
        action: _searchQuery.isEmpty
            ? FilledButton.icon(
                onPressed: _uploadFile,
                icon: const Icon(Icons.cloud_upload),
                label: Text(locale.t('上传文件', 'Upload File')),
              )
            : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // 文件夹
        if (index < _folderNames.length) {
          final folderName = _folderNames[index];
          return _FileListTile(
            isFolder: true,
            icon: Icons.folder,
            iconColor: theme.colorScheme.primary,
            title: folderName,
            subtitle: locale.t('文件夹', 'Folder'),
            isSelected: false,
            onTap: () => _navigateToPrefix('${_currentPrefix ?? ''}$folderName/'),
            onCheckboxChanged: null,
          );
        }

        // 文件
        final fileIndex = index - _folderNames.length;
        final obj = _displayedObjects[fileIndex];
        final fileName = obj.key.split('/').last;
        final isSelected = _selectedFileKeys.contains(obj.key);
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']
            .any((ext) => fileName.toLowerCase().endsWith('.$ext'));

        return _FileListTile(
          isFolder: false,
          icon: isImage ? Icons.image : Icons.insert_drive_file,
          iconColor: theme.colorScheme.secondary,
          title: fileName,
          subtitle: '${_formatFileSize(obj.size)} • ${obj.lastModified.toString().substring(0, 16)}',
          isSelected: isSelected,
          onTap: () {},
          onCheckboxChanged: (value) => _toggleFileSelection(obj.key),
          trailing: _hasSelection
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, size: 18),
                      tooltip: locale.t('下载', 'Download'),
                      onPressed: () => _downloadFile(obj),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      tooltip: locale.t('删除', 'Delete'),
                      onPressed: () => _deleteFile(obj),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _FileListTile extends StatelessWidget {
  final bool isFolder;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool?>? onCheckboxChanged;
  final Widget? trailing;

  const _FileListTile({
    required this.isFolder,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.onCheckboxChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: onCheckboxChanged != null
            ? Checkbox(
                value: isSelected,
                onChanged: onCheckboxChanged,
              )
            : Icon(icon, color: iconColor),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
