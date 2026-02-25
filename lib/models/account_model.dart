import 'dart:convert';

class AccountModel {
  final String id;
  final String name;
  final String accessKeyId;
  String accessKeySecret; // 运行时持有，存储时加密
  final DateTime createdAt;

  AccountModel({
    required this.id,
    required this.name,
    required this.accessKeyId,
    required this.accessKeySecret,
    required this.createdAt,
  });

  AccountModel copyWith({
    String? id,
    String? name,
    String? accessKeyId,
    String? accessKeySecret,
    DateTime? createdAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      accessKeySecret: accessKeySecret ?? this.accessKeySecret,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'accessKeyId': accessKeyId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AccountModel.fromJson(Map<String, dynamic> json) => AccountModel(
        id: json['id'] as String,
        name: json['name'] as String,
        accessKeyId: json['accessKeyId'] as String,
        accessKeySecret: '', // 从安全存储单独加载
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());

  factory AccountModel.fromJsonString(String jsonStr) =>
      AccountModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
