import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';
import '../providers/account_provider.dart';
import '../providers/locale_provider.dart';
import '../services/oss_service.dart';
import '../widgets/common_widgets.dart';

/// 云端文件浏览器页面
/// 支持浏览、上传、下载、删除云端文件
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
  List<OssObject> _objects = [];
  List<String> _prefixStack = ['']; // 模拟目录导航栈
  bool _isLoading = false;
  String? _error;
  String? _currentPrefix;

  AccountModel? _account;
  BucketConfig? _bucketConfig;

  @override
  void initState() {
    super.initState();
    _initOssService();
  }

  void _initOssService() {
    final accountProvider = context.read<AccountProvider>();
    _account = accountProvider.getAccountById(widget.accountId);
    _bucketConfig = accountProvider.getBucketConfigById(widget.bucketConfigId);
    
    if (_account != null && _bucketConfig != null) {
      _ossService = OssService(account: _account!, bucket: _bucketConfig!);
      _loadObjects();
    }
  }

  Future<void> _loadObjects() async {
    if (_ossService == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefix = _prefixStack.isEmpty ? '' : _prefixStack.last;
      _currentPrefix = prefix;
      final objects = await _ossService!.listObjects(prefix);
      setState(() {
        _objects = objects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
    // 从 prefix 中提取路径段
    final prefix = _prefixStack.last;
    return prefix.split('/').where((s) => s.isNotEmpty).toList();
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

  Future<void> _uploadFile() async {
    // 简单的文件上传对话框
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

      // 构建完整的 objectKey（包含当前路径前缀）
      final fullObjectKey = _currentPrefix ?? '' + objectKey;

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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();
    final bucketName = _bucketConfig?.bucketName ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          PageHeader(
            title: locale.t('远程文件', 'Remote Files'),
            actions: [
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.cloud, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '$bucketName',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
          // 路径导航
          if (_prefixStack.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  IconButton.outlined(
                    onPressed: _navigateUp,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    tooltip: locale.t('返回上级', 'Go Up'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _navigateToPrefix(''),
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
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                InkWell(
                                  onTap: isLast ? null : () {
                                    // 计算到这个段的所有前缀
                                    final prefix = _pathSegments.sublist(0, idx + 1).join('/') + '/';
                                    _navigateToPrefix(prefix);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(
                                      segment,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isLast
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.primary,
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
                ],
              ),
            ),
          // 文件列表
          Expanded(
            child: _buildContent(theme, locale),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, LocaleProvider locale) {
    if (_isLoading && _objects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _objects.isEmpty) {
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

    if (_objects.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open,
        message: locale.t('该目录下暂无文件', 'No files in this directory'),
        action: FilledButton.icon(
          onPressed: _uploadFile,
          icon: const Icon(Icons.cloud_upload),
          label: Text(locale.t('上传文件', 'Upload File')),
        ),
      );
    }

    // 按前缀分组显示（文件夹在前）
    final folders = <String>{};
    final files = <OssObject>[];

    for (final obj in _objects) {
      // 提取相对路径中的下一级目录
      final relativeKey = obj.key.replaceFirst(_currentPrefix ?? '', '');
      if (relativeKey.contains('/')) {
        final folderName = relativeKey.split('/').first;
        folders.add(folderName);
      } else {
        files.add(obj);
      }
    }

    final allItems = <dynamic>[
      ...folders.map((f) => _FolderItem(name: f, prefix: f + '/')),
      ...files,
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        
        if (item is _FolderItem) {
          return _FileListTile(
            icon: Icons.folder,
            iconColor: theme.colorScheme.primary,
            title: item.name,
            subtitle: locale.t('文件夹', 'Folder'),
            onTap: () => _navigateToPrefix(_currentPrefix ?? '' + item.prefix),
            trailing: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _navigateToPrefix(_currentPrefix ?? '' + item.prefix),
            ),
          );
        }

        final obj = item as OssObject;
        final fileName = obj.key.split('/').last;
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']
            .any((ext) => fileName.toLowerCase().endsWith('.$ext'));

        return _FileListTile(
          icon: isImage ? Icons.image : Icons.insert_drive_file,
          iconColor: theme.colorScheme.secondary,
          title: fileName,
          subtitle: '${_formatFileSize(obj.size)} • ${obj.lastModified.toString().substring(0, 16)}',
          onTap: () {},
          trailing: Row(
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

class _FolderItem {
  final String name;
  final String prefix;
  _FolderItem({required this.name, required this.prefix});
}

class _FileListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget trailing;

  const _FileListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
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
