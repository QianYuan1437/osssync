import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';
import '../services/storage_service.dart';

class AccountProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  List<AccountModel> _accounts = [];
  List<BucketConfig> _bucketConfigs = [];
  bool _isLoading = false;

  AccountProvider(this._storage);

  List<AccountModel> get accounts => List.unmodifiable(_accounts);
  List<BucketConfig> get bucketConfigs => List.unmodifiable(_bucketConfigs);
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    _accounts = await _storage.loadAccounts();
    _bucketConfigs = await _storage.loadBucketConfigs();
    _isLoading = false;
    notifyListeners();
  }

  // ─── 账户操作 ─────────────────────────────────────────────────────────────────

  Future<void> addAccount(AccountModel account) async {
    _accounts.add(account);
    await _storage.saveAccounts(_accounts);
    notifyListeners();
  }

  Future<void> updateAccount(AccountModel updated) async {
    final idx = _accounts.indexWhere((a) => a.id == updated.id);
    if (idx >= 0) {
      _accounts[idx] = updated;
      await _storage.saveAccounts(_accounts);
      notifyListeners();
    }
  }

  Future<void> deleteAccount(String accountId) async {
    _accounts.removeWhere((a) => a.id == accountId);
    // 同时删除关联的存储桶配置
    _bucketConfigs.removeWhere((b) => b.accountId == accountId);
    await _storage.saveAccounts(_accounts);
    await _storage.saveBucketConfigs(_bucketConfigs);
    await _storage.deleteAccountSecret(accountId);
    notifyListeners();
  }

  AccountModel createNewAccount({
    required String name,
    required String accessKeyId,
    required String accessKeySecret,
  }) {
    return AccountModel(
      id: _uuid.v4(),
      name: name,
      accessKeyId: accessKeyId,
      accessKeySecret: accessKeySecret,
      createdAt: DateTime.now(),
    );
  }

  AccountModel? getAccountById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── 存储桶配置操作 ───────────────────────────────────────────────────────────

  Future<void> addBucketConfig(BucketConfig config) async {
    _bucketConfigs.add(config);
    await _storage.saveBucketConfigs(_bucketConfigs);
    notifyListeners();
  }

  Future<void> updateBucketConfig(BucketConfig updated) async {
    final idx = _bucketConfigs.indexWhere((b) => b.id == updated.id);
    if (idx >= 0) {
      _bucketConfigs[idx] = updated;
      await _storage.saveBucketConfigs(_bucketConfigs);
      notifyListeners();
    }
  }

  Future<void> deleteBucketConfig(String configId) async {
    _bucketConfigs.removeWhere((b) => b.id == configId);
    await _storage.saveBucketConfigs(_bucketConfigs);
    notifyListeners();
  }

  BucketConfig createNewBucketConfig({
    required String accountId,
    required String name,
    required String bucketName,
    required String endpoint,
    required String region,
  }) {
    return BucketConfig(
      id: _uuid.v4(),
      accountId: accountId,
      name: name,
      bucketName: bucketName,
      endpoint: endpoint,
      region: region,
      createdAt: DateTime.now(),
    );
  }

  BucketConfig? getBucketConfigById(String id) {
    try {
      return _bucketConfigs.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  List<BucketConfig> getBucketConfigsByAccount(String accountId) {
    return _bucketConfigs.where((b) => b.accountId == accountId).toList();
  }
}
