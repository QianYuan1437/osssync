import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/bucket_config.dart';
import '../models/sync_task.dart';
import '../providers/account_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/common_widgets.dart';

class SyncTaskEditScreen extends StatefulWidget {
  final String? taskId;
  const SyncTaskEditScreen({super.key, this.taskId});

  @override
  State<SyncTaskEditScreen> createState() => _SyncTaskEditScreenState();
}

class _SyncTaskEditScreenState extends State<SyncTaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _localPathCtrl = TextEditingController();
  final _remotePathCtrl = TextEditingController();

  String? _selectedAccountId;
  String? _selectedBucketConfigId;
  SyncDirection _syncDirection = SyncDirection.upload;
  int _intervalMinutes = 30;
  bool _isEnabled = true;
  bool _isSaving = false;

  SyncTask? _existingTask;

  static const _intervalOptions = [
    {'label': '仅手动', 'value': 0},
    {'label': '每 5 分钟', 'value': 5},
    {'label': '每 15 分钟', 'value': 15},
    {'label': '每 30 分钟', 'value': 30},
    {'label': '每 1 小时', 'value': 60},
    {'label': '每 2 小时', 'value': 120},
    {'label': '每 6 小时', 'value': 360},
    {'label': '每 12 小时', 'value': 720},
    {'label': '每天', 'value': 1440},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadState());
  }

  /// 优先从草稿恢复，草稿不存在时从已有任务加载
  void _loadState() {
    final provider = context.read<SyncProvider>();
    final draft = provider.getDraft(widget.taskId);

    if (draft != null) {
      // 从草稿恢复
      setState(() {
        _nameCtrl.text = draft['name'] as String? ?? '';
        _localPathCtrl.text = draft['localPath'] as String? ?? '';
        _remotePathCtrl.text = draft['remotePath'] as String? ?? '';
        _selectedAccountId = draft['accountId'] as String?;
        _selectedBucketConfigId = draft['bucketConfigId'] as String?;
        _syncDirection = SyncDirection.values.firstWhere(
          (d) => d.name == (draft['syncDirection'] as String?),
          orElse: () => SyncDirection.upload,
        );
        _intervalMinutes = draft['intervalMinutes'] as int? ?? 30;
        _isEnabled = draft['isEnabled'] as bool? ?? true;
      });
      // 如果是编辑模式，还需要加载原始任务引用
      if (widget.taskId != null) {
        _existingTask = provider.getTaskById(widget.taskId!);
      }
      return;
    }

    // 无草稿时从已有任务加载
    if (widget.taskId == null) return;
    final task = provider.getTaskById(widget.taskId!);
    if (task == null) return;
    _existingTask = task;
    setState(() {
      _nameCtrl.text = task.name;
      _localPathCtrl.text = task.localPath;
      _remotePathCtrl.text = task.remotePath;
      _selectedAccountId = task.accountId;
      _selectedBucketConfigId = task.bucketConfigId;
      _syncDirection = task.syncDirection;
      _intervalMinutes = task.intervalMinutes;
      _isEnabled = task.isEnabled;
    });
  }

  /// 将当前编辑内容保存为草稿
  void _saveDraft() {
    final provider = context.read<SyncProvider>();
    provider.saveDraft(widget.taskId, {
      'name': _nameCtrl.text,
      'localPath': _localPathCtrl.text,
      'remotePath': _remotePathCtrl.text,
      'accountId': _selectedAccountId,
      'bucketConfigId': _selectedBucketConfigId,
      'syncDirection': _syncDirection.name,
      'intervalMinutes': _intervalMinutes,
      'isEnabled': _isEnabled,
    });
  }

  @override
  void dispose() {
    // 页面销毁时自动保存草稿（仅当有内容时）
    if (_nameCtrl.text.isNotEmpty ||
        _localPathCtrl.text.isNotEmpty ||
        _selectedAccountId != null) {
      _saveDraft();
    }
    _nameCtrl.dispose();
    _localPathCtrl.dispose();
    _remotePathCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocalFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择本地同步文件夹',
    );
    if (result != null) {
      setState(() => _localPathCtrl.text = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择账户')),
      );
      return;
    }
    if (_selectedBucketConfigId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择存储桶配置')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<SyncProvider>();

    try {
      if (_existingTask == null) {
        final task = provider.createNewTask(
          name: _nameCtrl.text.trim(),
          accountId: _selectedAccountId!,
          bucketConfigId: _selectedBucketConfigId!,
          localPath: _localPathCtrl.text.trim(),
          remotePath: _remotePathCtrl.text.trim(),
          syncDirection: _syncDirection,
          intervalMinutes: _intervalMinutes,
        );
        await provider.addTask(task.copyWith(isEnabled: _isEnabled));
      } else {
        final updated = _existingTask!.copyWith(
          name: _nameCtrl.text.trim(),
          accountId: _selectedAccountId,
          bucketConfigId: _selectedBucketConfigId,
          localPath: _localPathCtrl.text.trim(),
          remotePath: _remotePathCtrl.text.trim(),
          syncDirection: _syncDirection,
          intervalMinutes: _intervalMinutes,
          isEnabled: _isEnabled,
        );
        await provider.updateTask(updated);
      }
      // 保存成功后清除草稿
      provider.clearDraft(widget.taskId);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.taskId != null;
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;
    // 明确类型为 List<BucketConfig>，避免 DropdownButtonFormField 类型推断失败
    final List<BucketConfig> buckets = _selectedAccountId != null
        ? accountProvider.getBucketConfigsByAccount(_selectedAccountId!)
        : const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: isEdit ? '编辑同步任务' : '新建同步任务',
            actions: [
              TextButton(
                onPressed: () {
                  // 取消时清除草稿
                  context.read<SyncProvider>().clearDraft(widget.taskId);
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 基本信息
                    _SectionCard(
                      title: '基本信息',
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '任务名称',
                            hintText: '如：文档备份',
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? '请输入任务名称' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('启用任务'),
                            const Spacer(),
                            Switch(
                              value: _isEnabled,
                              onChanged: (v) => setState(() => _isEnabled = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // OSS 配置
                    _SectionCard(
                      title: 'OSS 配置',
                      children: [
                        // 账户选择
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAccountId,
                          decoration: const InputDecoration(
                            labelText: '选择账户',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          hint: const Text('请选择账户'),
                          items: accounts
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selectedAccountId = v;
                            _selectedBucketConfigId = null;
                          }),
                          validator: (v) => v == null ? '请选择账户' : null,
                        ),
                        const SizedBox(height: 12),
                        // 存储桶选择
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBucketConfigId,
                          decoration: const InputDecoration(
                            labelText: '选择存储桶',
                            prefixIcon: Icon(Icons.storage_outlined),
                          ),
                          hint: Text(
                              buckets.isEmpty ? '请先选择账户' : '请选择存储桶'),
                          items: buckets
                              .map((b) => DropdownMenuItem<String>(
                                    value: b.id,
                                    child: Text('${b.name} (${b.bucketName})'),
                                  ))
                              .toList(),
                          onChanged: buckets.isEmpty
                              ? null
                              : (v) =>
                                  setState(() => _selectedBucketConfigId = v),
                          validator: (v) => v == null ? '请选择存储桶' : null,
                        ),
                        const SizedBox(height: 12),
                        // OSS 远端路径
                        TextFormField(
                          controller: _remotePathCtrl,
                          decoration: const InputDecoration(
                            labelText: 'OSS 路径前缀（可选）',
                            hintText: '如：backup/docs/（留空则为根目录）',
                            prefixIcon: Icon(Icons.cloud_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 本地路径
                    _SectionCard(
                      title: '本地路径',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _localPathCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: '本地同步文件夹',
                                  hintText: '点击右侧按钮选择文件夹',
                                  prefixIcon: Icon(Icons.folder_outlined),
                                ),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? '请选择本地文件夹'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _pickLocalFolder,
                              icon: const Icon(Icons.folder_open, size: 16),
                              label: const Text('浏览'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 同步设置
                    _SectionCard(
                      title: '同步设置',
                      children: [
                        // 同步方向
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('同步方向',
                                style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 8),
                            ...SyncDirection.values.map((dir) => InkWell(
                                  onTap: () =>
                                      setState(() => _syncDirection = dir),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    child: Row(
                                      children: [
                                        Radio<SyncDirection>(
                                          value: dir,
                                          groupValue: _syncDirection,
                                          onChanged: (v) => setState(
                                              () => _syncDirection = v!),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(dir.label),
                                              Text(
                                                _dirDescription(dir),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                        ),
                        const Divider(height: 24),
                        // 同步间隔
                        DropdownButtonFormField<int>(
                          initialValue: _intervalMinutes,
                          decoration: const InputDecoration(
                            labelText: '自动同步间隔',
                            prefixIcon: Icon(Icons.schedule),
                          ),
                          items: _intervalOptions
                              .map((o) => DropdownMenuItem(
                                    value: o['value'] as int,
                                    child: Text(o['label'] as String),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _intervalMinutes = v ?? 30),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dirDescription(SyncDirection dir) {
    switch (dir) {
      case SyncDirection.upload:
        return '将本地新增/修改的文件上传到 OSS，OSS 中多余的文件不受影响';
      case SyncDirection.download:
        return '将 OSS 新增/修改的文件下载到本地，本地多余的文件不受影响';
      case SyncDirection.bidirectional:
        return '双向同步，本地和 OSS 互相补充，以最新修改为准';
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
