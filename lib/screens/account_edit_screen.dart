import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';
import '../providers/account_provider.dart';
import '../services/oss_service.dart';
import '../widgets/common_widgets.dart';

class AccountEditScreen extends StatefulWidget {
  final String? accountId;
  const AccountEditScreen({super.key, this.accountId});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _akIdCtrl = TextEditingController();
  final _akSecretCtrl = TextEditingController();
  bool _secretVisible = false;
  bool _isSaving = false;

  // 存储桶配置列表（可多个）
  final List<_BucketFormData> _buckets = [];

  AccountModel? _existingAccount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  void _loadExisting() {
    if (widget.accountId == null) return;
    final provider = context.read<AccountProvider>();
    final account = provider.getAccountById(widget.accountId!);
    if (account == null) return;
    _existingAccount = account;
    _nameCtrl.text = account.name;
    _akIdCtrl.text = account.accessKeyId;
    _akSecretCtrl.text = account.accessKeySecret;

    final buckets = provider.getBucketConfigsByAccount(account.id);
    setState(() {
      _buckets.addAll(buckets.map((b) => _BucketFormData.fromModel(b)));
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _akIdCtrl.dispose();
    _akSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<AccountProvider>();

    try {
      if (_existingAccount == null) {
        // 新增账户
        final account = provider.createNewAccount(
          name: _nameCtrl.text.trim(),
          accessKeyId: _akIdCtrl.text.trim(),
          accessKeySecret: _akSecretCtrl.text.trim(),
        );
        await provider.addAccount(account);

        // 保存存储桶配置
        for (final b in _buckets) {
          if (b.isValid) {
            final config = provider.createNewBucketConfig(
              accountId: account.id,
              name: b.nameCtrl.text.trim(),
              bucketName: b.bucketNameCtrl.text.trim(),
              endpoint: b.selectedEndpoint,
              region: b.selectedRegion,
            );
            await provider.addBucketConfig(config);
          }
        }
      } else {
        // 更新账户
        final updated = _existingAccount!.copyWith(
          name: _nameCtrl.text.trim(),
          accessKeyId: _akIdCtrl.text.trim(),
          accessKeySecret: _akSecretCtrl.text.trim(),
        );
        await provider.updateAccount(updated);

        // 更新存储桶配置
        final existingBuckets =
            provider.getBucketConfigsByAccount(_existingAccount!.id);
        final existingIds = existingBuckets.map((b) => b.id).toSet();
        final newIds = _buckets
            .where((b) => b.existingId != null)
            .map((b) => b.existingId!)
            .toSet();

        // 删除移除的存储桶
        for (final id in existingIds.difference(newIds)) {
          await provider.deleteBucketConfig(id);
        }

        // 更新或新增
        for (final b in _buckets) {
          if (!b.isValid) continue;
          if (b.existingId != null) {
            final config = provider.getBucketConfigById(b.existingId!);
            if (config != null) {
              await provider.updateBucketConfig(config.copyWith(
                name: b.nameCtrl.text.trim(),
                bucketName: b.bucketNameCtrl.text.trim(),
                endpoint: b.selectedEndpoint,
                region: b.selectedRegion,
              ));
            }
          } else {
            final config = provider.createNewBucketConfig(
              accountId: _existingAccount!.id,
              name: b.nameCtrl.text.trim(),
              bucketName: b.bucketNameCtrl.text.trim(),
              endpoint: b.selectedEndpoint,
              region: b.selectedRegion,
            );
            await provider.addBucketConfig(config);
          }
        }
      }

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

  Future<void> _testConnection(int bucketIndex) async {
    final b = _buckets[bucketIndex];
    if (_akIdCtrl.text.isEmpty || _akSecretCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写 AccessKey 信息')),
      );
      return;
    }
    if (!b.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写完整的存储桶信息')),
      );
      return;
    }

    setState(() => b.isTesting = true);
    try {
      final tempAccount = AccountModel(
        id: 'test',
        name: 'test',
        accessKeyId: _akIdCtrl.text.trim(),
        accessKeySecret: _akSecretCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      final tempBucket = BucketConfig(
        id: 'test',
        accountId: 'test',
        name: 'test',
        bucketName: b.bucketNameCtrl.text.trim(),
        endpoint: b.selectedEndpoint,
        region: b.selectedRegion,
        createdAt: DateTime.now(),
      );
      final oss = OssService(account: tempAccount, bucket: tempBucket);
      final ok = await oss.testConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? '连接成功！' : '连接失败，请检查配置'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('连接测试失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => b.isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.accountId != null;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: isEdit ? '编辑账户' : '新增账户',
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
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
                    // 账户基本信息
                    _SectionTitle(title: '账户信息'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: '账户名称',
                                hintText: '如：我的阿里云账户',
                                prefixIcon: Icon(Icons.label_outline),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? '请输入账户名称' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _akIdCtrl,
                              decoration: const InputDecoration(
                                labelText: 'AccessKey ID',
                                hintText: '阿里云 AccessKey ID',
                                prefixIcon: Icon(Icons.key_outlined),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? '请输入 AccessKey ID'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _akSecretCtrl,
                              obscureText: !_secretVisible,
                              decoration: InputDecoration(
                                labelText: 'AccessKey Secret',
                                hintText: '阿里云 AccessKey Secret',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_secretVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(
                                      () => _secretVisible = !_secretVisible),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? '请输入 AccessKey Secret'
                                      : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 存储桶配置
                    Row(
                      children: [
                        _SectionTitle(title: '存储桶配置'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _buckets.add(_BucketFormData())),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('添加存储桶'),
                        ),
                      ],
                    ),
                    if (_buckets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '暂无存储桶配置，点击右上角添加',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ..._buckets.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final b = entry.value;
                      return _BucketConfigCard(
                        data: b,
                        index: idx,
                        onRemove: () =>
                            setState(() => _buckets.removeAt(idx)),
                        onTest: () => _testConnection(idx),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _BucketFormData {
  final String? existingId;
  final nameCtrl = TextEditingController();
  final bucketNameCtrl = TextEditingController();
  String selectedRegion = 'cn-hangzhou';
  String selectedEndpoint = 'oss-cn-hangzhou.aliyuncs.com';
  bool isTesting = false;

  _BucketFormData({this.existingId});

  factory _BucketFormData.fromModel(BucketConfig config) {
    final data = _BucketFormData(existingId: config.id);
    data.nameCtrl.text = config.name;
    data.bucketNameCtrl.text = config.bucketName;
    data.selectedRegion = config.region;
    data.selectedEndpoint = config.endpoint;
    return data;
  }

  bool get isValid =>
      nameCtrl.text.trim().isNotEmpty &&
      bucketNameCtrl.text.trim().isNotEmpty;

  void dispose() {
    nameCtrl.dispose();
    bucketNameCtrl.dispose();
  }
}

class _BucketConfigCard extends StatefulWidget {
  final _BucketFormData data;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onTest;

  const _BucketConfigCard({
    required this.data,
    required this.index,
    required this.onRemove,
    required this.onTest,
  });

  @override
  State<_BucketConfigCard> createState() => _BucketConfigCardState();
}

class _BucketConfigCardState extends State<_BucketConfigCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.data;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('存储桶 ${widget.index + 1}',
                    style: theme.textTheme.labelLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: widget.onRemove,
                  color: Colors.red,
                  tooltip: '删除此存储桶',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: d.nameCtrl,
              decoration: const InputDecoration(
                labelText: '配置名称',
                hintText: '如：生产环境图片桶',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: d.bucketNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Bucket 名称',
                hintText: '如：my-bucket',
                prefixIcon: Icon(Icons.storage_outlined),
              ),
            ),
            const SizedBox(height: 12),
            // Region 选择
            DropdownButtonFormField<String>(
              initialValue: d.selectedRegion,
              decoration: const InputDecoration(
                labelText: '地域 (Region)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: kAliyunRegions
                  .map((r) => DropdownMenuItem(
                        value: r['region'],
                        child: Text(r['label']!),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                final region =
                    kAliyunRegions.firstWhere((r) => r['region'] == v);
                setState(() {
                  d.selectedRegion = v;
                  d.selectedEndpoint = region['endpoint']!;
                });
              },
            ),
            const SizedBox(height: 12),
            // Endpoint 显示
            TextFormField(
              initialValue: d.selectedEndpoint,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Endpoint',
                prefixIcon: Icon(Icons.link_outlined),
              ),
            ),
            const SizedBox(height: 12),
            // 测试连接按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: d.isTesting ? null : widget.onTest,
                icon: d.isTesting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 16),
                label: Text(d.isTesting ? '测试中...' : '测试连接'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
