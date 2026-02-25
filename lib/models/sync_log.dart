import 'dart:convert';

enum LogLevel { info, warning, error, success }

extension LogLevelLabel on LogLevel {
  String get label {
    switch (this) {
      case LogLevel.info:
        return '信息';
      case LogLevel.warning:
        return '警告';
      case LogLevel.error:
        return '错误';
      case LogLevel.success:
        return '成功';
    }
  }
}

class SyncLog {
  final String id;
  final String taskId;
  final String taskName;
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final int filesUploaded;
  final int filesDownloaded;
  final int filesSkipped;
  final int filesDeleted;
  final Duration? duration;

  SyncLog({
    required this.id,
    required this.taskId,
    required this.taskName,
    required this.timestamp,
    required this.level,
    required this.message,
    this.filesUploaded = 0,
    this.filesDownloaded = 0,
    this.filesSkipped = 0,
    this.filesDeleted = 0,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'taskName': taskName,
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'message': message,
        'filesUploaded': filesUploaded,
        'filesDownloaded': filesDownloaded,
        'filesSkipped': filesSkipped,
        'filesDeleted': filesDeleted,
        'durationMs': duration?.inMilliseconds,
      };

  factory SyncLog.fromJson(Map<String, dynamic> json) => SyncLog(
        id: json['id'] as String,
        taskId: json['taskId'] as String,
        taskName: json['taskName'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: LogLevel.values.firstWhere((e) => e.name == json['level']),
        message: json['message'] as String,
        filesUploaded: (json['filesUploaded'] as int?) ?? 0,
        filesDownloaded: (json['filesDownloaded'] as int?) ?? 0,
        filesSkipped: (json['filesSkipped'] as int?) ?? 0,
        filesDeleted: (json['filesDeleted'] as int?) ?? 0,
        duration: json['durationMs'] != null
            ? Duration(milliseconds: json['durationMs'] as int)
            : null,
      );

  String toJsonString() => jsonEncode(toJson());

  factory SyncLog.fromJsonString(String jsonStr) =>
      SyncLog.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
