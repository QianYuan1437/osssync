import 'dart:convert';

enum SyncDirection { upload, download, bidirectional }

enum SyncStatus { idle, syncing, error, success }

extension SyncDirectionLabel on SyncDirection {
  String get label {
    switch (this) {
      case SyncDirection.upload:
        return '上传（本地→OSS）';
      case SyncDirection.download:
        return '下载（OSS→本地）';
      case SyncDirection.bidirectional:
        return '双向同步';
    }
  }

  String get value {
    return name;
  }

  static SyncDirection fromValue(String value) {
    return SyncDirection.values.firstWhere((e) => e.name == value);
  }
}

extension SyncStatusLabel on SyncStatus {
  String get label {
    switch (this) {
      case SyncStatus.idle:
        return '空闲';
      case SyncStatus.syncing:
        return '同步中';
      case SyncStatus.error:
        return '错误';
      case SyncStatus.success:
        return '成功';
    }
  }
}

class SyncTask {
  final String id;
  final String name;
  final String accountId;
  final String bucketConfigId;
  final String localPath;
  final String remotePath; // OSS 路径前缀，如 "backup/docs/"
  final SyncDirection syncDirection;
  final int intervalMinutes; // 0 表示不自动同步
  final bool isEnabled;
  final DateTime? lastSyncAt;
  final SyncStatus status;
  final String? lastError;
  final DateTime createdAt;

  SyncTask({
    required this.id,
    required this.name,
    required this.accountId,
    required this.bucketConfigId,
    required this.localPath,
    required this.remotePath,
    required this.syncDirection,
    required this.intervalMinutes,
    required this.isEnabled,
    this.lastSyncAt,
    required this.status,
    this.lastError,
    required this.createdAt,
  });

  SyncTask copyWith({
    String? id,
    String? name,
    String? accountId,
    String? bucketConfigId,
    String? localPath,
    String? remotePath,
    SyncDirection? syncDirection,
    int? intervalMinutes,
    bool? isEnabled,
    DateTime? lastSyncAt,
    SyncStatus? status,
    String? lastError,
    DateTime? createdAt,
  }) {
    return SyncTask(
      id: id ?? this.id,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      bucketConfigId: bucketConfigId ?? this.bucketConfigId,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      syncDirection: syncDirection ?? this.syncDirection,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'accountId': accountId,
        'bucketConfigId': bucketConfigId,
        'localPath': localPath,
        'remotePath': remotePath,
        'syncDirection': syncDirection.name,
        'intervalMinutes': intervalMinutes,
        'isEnabled': isEnabled,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'status': status.name,
        'lastError': lastError,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SyncTask.fromJson(Map<String, dynamic> json) => SyncTask(
        id: json['id'] as String,
        name: json['name'] as String,
        accountId: json['accountId'] as String,
        bucketConfigId: json['bucketConfigId'] as String,
        localPath: json['localPath'] as String,
        remotePath: json['remotePath'] as String,
        syncDirection: SyncDirection.values
            .firstWhere((e) => e.name == json['syncDirection']),
        intervalMinutes: json['intervalMinutes'] as int,
        isEnabled: json['isEnabled'] as bool,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.parse(json['lastSyncAt'] as String)
            : null,
        status: SyncStatus.values
            .firstWhere((e) => e.name == (json['status'] ?? 'idle')),
        lastError: json['lastError'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());

  factory SyncTask.fromJsonString(String jsonStr) =>
      SyncTask.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
