import 'dart:convert';

class BucketConfig {
  final String id;
  final String accountId;
  final String name; // 配置显示名称
  final String bucketName;
  final String endpoint; // 如 oss-cn-hangzhou.aliyuncs.com
  final String region; // 如 cn-hangzhou
  final DateTime createdAt;

  BucketConfig({
    required this.id,
    required this.accountId,
    required this.name,
    required this.bucketName,
    required this.endpoint,
    required this.region,
    required this.createdAt,
  });

  BucketConfig copyWith({
    String? id,
    String? accountId,
    String? name,
    String? bucketName,
    String? endpoint,
    String? region,
    DateTime? createdAt,
  }) {
    return BucketConfig(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      bucketName: bucketName ?? this.bucketName,
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'name': name,
        'bucketName': bucketName,
        'endpoint': endpoint,
        'region': region,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BucketConfig.fromJson(Map<String, dynamic> json) => BucketConfig(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        name: json['name'] as String,
        bucketName: json['bucketName'] as String,
        endpoint: json['endpoint'] as String,
        region: json['region'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());

  factory BucketConfig.fromJsonString(String jsonStr) =>
      BucketConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}

// 阿里云常用 Region 列表
const kAliyunRegions = [
  {'label': '华东1（杭州）', 'region': 'cn-hangzhou', 'endpoint': 'oss-cn-hangzhou.aliyuncs.com'},
  {'label': '华东2（上海）', 'region': 'cn-shanghai', 'endpoint': 'oss-cn-shanghai.aliyuncs.com'},
  {'label': '华北1（青岛）', 'region': 'cn-qingdao', 'endpoint': 'oss-cn-qingdao.aliyuncs.com'},
  {'label': '华北2（北京）', 'region': 'cn-beijing', 'endpoint': 'oss-cn-beijing.aliyuncs.com'},
  {'label': '华北3（张家口）', 'region': 'cn-zhangjiakou', 'endpoint': 'oss-cn-zhangjiakou.aliyuncs.com'},
  {'label': '华北5（呼和浩特）', 'region': 'cn-huhehaote', 'endpoint': 'oss-cn-huhehaote.aliyuncs.com'},
  {'label': '华北6（乌兰察布）', 'region': 'cn-wulanchabu', 'endpoint': 'oss-cn-wulanchabu.aliyuncs.com'},
  {'label': '华南1（深圳）', 'region': 'cn-shenzhen', 'endpoint': 'oss-cn-shenzhen.aliyuncs.com'},
  {'label': '华南2（河源）', 'region': 'cn-heyuan', 'endpoint': 'oss-cn-heyuan.aliyuncs.com'},
  {'label': '华南3（广州）', 'region': 'cn-guangzhou', 'endpoint': 'oss-cn-guangzhou.aliyuncs.com'},
  {'label': '西南1（成都）', 'region': 'cn-chengdu', 'endpoint': 'oss-cn-chengdu.aliyuncs.com'},
  {'label': '中国香港', 'region': 'cn-hongkong', 'endpoint': 'oss-cn-hongkong.aliyuncs.com'},
  {'label': '亚太东南1（新加坡）', 'region': 'ap-southeast-1', 'endpoint': 'oss-ap-southeast-1.aliyuncs.com'},
  {'label': '亚太东南2（悉尼）', 'region': 'ap-southeast-2', 'endpoint': 'oss-ap-southeast-2.aliyuncs.com'},
  {'label': '亚太东南3（吉隆坡）', 'region': 'ap-southeast-3', 'endpoint': 'oss-ap-southeast-3.aliyuncs.com'},
  {'label': '亚太东南5（雅加达）', 'region': 'ap-southeast-5', 'endpoint': 'oss-ap-southeast-5.aliyuncs.com'},
  {'label': '亚太东北1（日本）', 'region': 'ap-northeast-1', 'endpoint': 'oss-ap-northeast-1.aliyuncs.com'},
  {'label': '美国西部1（硅谷）', 'region': 'us-west-1', 'endpoint': 'oss-us-west-1.aliyuncs.com'},
  {'label': '美国东部1（弗吉尼亚）', 'region': 'us-east-1', 'endpoint': 'oss-us-east-1.aliyuncs.com'},
  {'label': '欧洲中部1（法兰克福）', 'region': 'eu-central-1', 'endpoint': 'oss-eu-central-1.aliyuncs.com'},
];
