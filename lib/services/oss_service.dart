import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';

class OssObject {
  final String key;
  final String etag; // MD5 hex，去掉引号
  final int size;
  final DateTime lastModified;

  OssObject({
    required this.key,
    required this.etag,
    required this.size,
    required this.lastModified,
  });
}

class OssService {
  final AccountModel account;
  final BucketConfig bucket;
  late final Dio _dio;

  OssService({required this.account, required this.bucket}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
    ));
  }

  String get _baseUrl => 'https://${bucket.bucketName}.${bucket.endpoint}';

  // ─── 签名 ────────────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    final utc = dt.toUtc();
    final fmt = DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US');
    return '${fmt.format(utc)} GMT';
  }

  String _sign(String method, String contentMd5, String contentType,
      String date, String canonicalizedResource) {
    final stringToSign =
        '$method\n$contentMd5\n$contentType\n$date\n$canonicalizedResource';
    final key = utf8.encode(account.accessKeySecret);
    final msg = utf8.encode(stringToSign);
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(msg);
    return base64.encode(digest.bytes);
  }

  Map<String, String> _buildHeaders({
    required String method,
    required String objectKey,
    String contentType = '',
    String contentMd5 = '',
    Map<String, String>? extraHeaders,
  }) {
    final date = _formatDate(DateTime.now());
    final canonicalizedResource = '/${bucket.bucketName}/$objectKey';
    final signature = _sign(
        method, contentMd5, contentType, date, canonicalizedResource);
    final auth =
        'OSS ${account.accessKeyId}:$signature';

    return {
      'Date': date,
      'Authorization': auth,
      if (contentType.isNotEmpty) 'Content-Type': contentType,
      if (contentMd5.isNotEmpty) 'Content-MD5': contentMd5,
      ...?extraHeaders,
    };
  }

  // ─── 列举对象 ─────────────────────────────────────────────────────────────────

  /// 列举指定前缀下的所有对象（自动分页）
  Future<List<OssObject>> listObjects(String prefix) async {
    final objects = <OssObject>[];
    String? marker;
    bool isTruncated = true;

    while (isTruncated) {
      final queryParams = <String, String>{
        'prefix': prefix,
        'max-keys': '1000',
        if (marker != null) 'marker': marker,
      };

      final date = _formatDate(DateTime.now());
      final canonicalizedResource = '/${bucket.bucketName}/';
      final signature = _sign('GET', '', '', date, canonicalizedResource);

      final response = await _dio.get(
        _baseUrl,
        queryParameters: queryParams,
        options: Options(headers: {
          'Date': date,
          'Authorization': 'OSS ${account.accessKeyId}:$signature',
        }),
      );

      final xmlStr = response.data as String;
      final parsed = _parseListObjectsXml(xmlStr);
      objects.addAll(parsed['objects'] as List<OssObject>);
      isTruncated = parsed['isTruncated'] as bool;
      marker = parsed['nextMarker'] as String?;
      if (marker == null || marker.isEmpty) isTruncated = false;
    }

    return objects;
  }

  Map<String, dynamic> _parseListObjectsXml(String xmlStr) {
    final objects = <OssObject>[];
    bool isTruncated = false;
    String? nextMarker;

    // 解析 IsTruncated
    final truncatedMatch =
        RegExp(r'<IsTruncated>(.*?)</IsTruncated>').firstMatch(xmlStr);
    if (truncatedMatch != null) {
      isTruncated = truncatedMatch.group(1)?.toLowerCase() == 'true';
    }

    // 解析 NextMarker
    final markerMatch =
        RegExp(r'<NextMarker>(.*?)</NextMarker>').firstMatch(xmlStr);
    if (markerMatch != null) {
      nextMarker = markerMatch.group(1);
    }

    // 解析 Contents
    final contentRegex = RegExp(
        r'<Contents>(.*?)</Contents>',
        dotAll: true);
    for (final match in contentRegex.allMatches(xmlStr)) {
      final content = match.group(1)!;
      final key = RegExp(r'<Key>(.*?)</Key>').firstMatch(content)?.group(1) ?? '';
      final etag = (RegExp(r'<ETag>(.*?)</ETag>').firstMatch(content)?.group(1) ?? '')
          .replaceAll('"', '')
          .toLowerCase();
      final size = int.tryParse(
              RegExp(r'<Size>(.*?)</Size>').firstMatch(content)?.group(1) ?? '0') ??
          0;
      final lastModifiedStr =
          RegExp(r'<LastModified>(.*?)</LastModified>').firstMatch(content)?.group(1) ?? '';
      DateTime lastModified;
      try {
        lastModified = DateTime.parse(lastModifiedStr);
      } catch (_) {
        lastModified = DateTime.now();
      }

      if (key.isNotEmpty) {
        objects.add(OssObject(
          key: key,
          etag: etag,
          size: size,
          lastModified: lastModified,
        ));
      }
    }

    return {
      'objects': objects,
      'isTruncated': isTruncated,
      'nextMarker': nextMarker,
    };
  }

  // ─── 上传 ─────────────────────────────────────────────────────────────────────

  Future<void> uploadFile(
    String localFilePath,
    String objectKey, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(localFilePath);
    final bytes = await file.readAsBytes();
    final md5 = base64.encode(md5Hash(bytes));
    final contentType = _guessContentType(localFilePath);

    final headers = _buildHeaders(
      method: 'PUT',
      objectKey: objectKey,
      contentType: contentType,
      contentMd5: md5,
    );

    await _dio.put(
      '$_baseUrl/$objectKey',
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          ...headers,
          'Content-Length': bytes.length,
        },
        contentType: contentType,
      ),
      onSendProgress: onProgress,
    );
  }

  // ─── 下载 ─────────────────────────────────────────────────────────────────────

  Future<void> downloadFile(
    String objectKey,
    String localFilePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final headers = _buildHeaders(
      method: 'GET',
      objectKey: objectKey,
    );

    // 确保目录存在
    final dir = File(localFilePath).parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _dio.download(
      '$_baseUrl/$objectKey',
      localFilePath,
      options: Options(headers: headers),
      onReceiveProgress: onProgress,
    );
  }

  // ─── 删除 ─────────────────────────────────────────────────────────────────────

  Future<void> deleteObject(String objectKey) async {
    final headers = _buildHeaders(
      method: 'DELETE',
      objectKey: objectKey,
    );
    await _dio.delete(
      '$_baseUrl/$objectKey',
      options: Options(headers: headers),
    );
  }

  // ─── 连接测试 ─────────────────────────────────────────────────────────────────

  Future<bool> testConnection() async {
    try {
      final date = _formatDate(DateTime.now());
      final canonicalizedResource = '/${bucket.bucketName}/';
      final signature = _sign('GET', '', '', date, canonicalizedResource);

      final response = await _dio.get(
        '$_baseUrl/?max-keys=1',
        options: Options(
          headers: {
            'Date': date,
            'Authorization': 'OSS ${account.accessKeyId}:$signature',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── 工具方法 ─────────────────────────────────────────────────────────────────

  Uint8List md5Hash(Uint8List data) {
    return Uint8List.fromList(md5.convert(data).bytes);
  }

  String _guessContentType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'html': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
      'json': 'application/json',
      'xml': 'application/xml',
      'zip': 'application/zip',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}
