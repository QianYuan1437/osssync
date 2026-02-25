import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import '../models/bucket_config.dart';
import '../models/sync_task.dart';
import '../models/sync_log.dart';
import 'oss_service.dart';

class SyncResult {
  final int uploaded;
  final int downloaded;
  final int skipped;
  final int deleted;
  final List<String> errors;
  final Duration duration;

  SyncResult({
    required this.uploaded,
    required this.downloaded,
    required this.skipped,
    required this.deleted,
    required this.errors,
    required this.duration,
  });
}

class SyncEngine {
  final _uuid = const Uuid();

  /// 执行同步任务，返回同步日志
  Future<SyncLog> runSync({
    required SyncTask task,
    required AccountModel account,
    required BucketConfig bucket,
    void Function(String message)? onProgress,
  }) async {
    final startTime = DateTime.now();
    int uploaded = 0, downloaded = 0, skipped = 0, deleted = 0;
    final errors = <String>[];

    final oss = OssService(account: account, bucket: bucket);
    final remotePrefixNorm = _normalizeRemotePath(task.remotePath);

    try {
      onProgress?.call('正在获取本地文件列表...');
      final localFiles = await _scanLocalFiles(task.localPath);

      onProgress?.call('正在获取 OSS 文件列表...');
      final ossObjects = await oss.listObjects(remotePrefixNorm);
      final ossMap = <String, OssObject>{};
      for (final obj in ossObjects) {
        // 去掉前缀，得到相对路径
        final relKey = obj.key.startsWith(remotePrefixNorm)
            ? obj.key.substring(remotePrefixNorm.length)
            : obj.key;
        if (relKey.isNotEmpty) ossMap[relKey] = obj;
      }

      switch (task.syncDirection) {
        case SyncDirection.upload:
          final r = await _doUpload(
            oss: oss,
            localFiles: localFiles,
            ossMap: ossMap,
            localBasePath: task.localPath,
            remotePrefix: remotePrefixNorm,
            onProgress: onProgress,
          );
          uploaded = r['uploaded']!;
          skipped = r['skipped']!;
          errors.addAll(r['errors'] as List<String>);
          break;

        case SyncDirection.download:
          final r = await _doDownload(
            oss: oss,
            localFiles: localFiles,
            ossMap: ossMap,
            localBasePath: task.localPath,
            remotePrefix: remotePrefixNorm,
            onProgress: onProgress,
          );
          downloaded = r['downloaded']!;
          skipped = r['skipped']!;
          errors.addAll(r['errors'] as List<String>);
          break;

        case SyncDirection.bidirectional:
          final ru = await _doUpload(
            oss: oss,
            localFiles: localFiles,
            ossMap: ossMap,
            localBasePath: task.localPath,
            remotePrefix: remotePrefixNorm,
            onProgress: onProgress,
          );
          uploaded = (ru['uploaded'] as int?) ?? 0;
          skipped += (ru['skipped'] as int?) ?? 0;
          errors.addAll(ru['errors'] as List<String>);

          final rd = await _doDownload(
            oss: oss,
            localFiles: localFiles,
            ossMap: ossMap,
            localBasePath: task.localPath,
            remotePrefix: remotePrefixNorm,
            onProgress: onProgress,
            skipExisting: true,
          );
          downloaded = (rd['downloaded'] as int?) ?? 0;
          skipped += (rd['skipped'] as int?) ?? 0;
          errors.addAll(rd['errors'] as List<String>);
          break;
      }
    } catch (e) {
      errors.add('同步失败: $e');
    }

    final duration = DateTime.now().difference(startTime);
    final hasError = errors.isNotEmpty;
    final message = hasError
        ? '同步完成（有错误）: 上传 $uploaded, 下载 $downloaded, 跳过 $skipped\n${errors.join('\n')}'
        : '同步成功: 上传 $uploaded, 下载 $downloaded, 跳过 $skipped';

    return SyncLog(
      id: _uuid.v4(),
      taskId: task.id,
      taskName: task.name,
      timestamp: startTime,
      level: hasError ? LogLevel.error : LogLevel.success,
      message: message,
      filesUploaded: uploaded,
      filesDownloaded: downloaded,
      filesSkipped: skipped,
      filesDeleted: deleted,
      duration: duration,
    );
  }

  // ─── 上传逻辑 ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _doUpload({
    required OssService oss,
    required Map<String, String> localFiles, // relPath -> md5
    required Map<String, OssObject> ossMap,
    required String localBasePath,
    required String remotePrefix,
    void Function(String)? onProgress,
  }) async {
    int uploaded = 0, skipped = 0;
    final errors = <String>[];

    for (final entry in localFiles.entries) {
      final relPath = entry.key;
      final localMd5 = entry.value;
      final ossKey = '$remotePrefix${relPath.replaceAll('\\', '/')}';
      final ossRelKey = relPath.replaceAll('\\', '/');

      final ossObj = ossMap[ossRelKey];
      if (ossObj != null && ossObj.etag == localMd5) {
        skipped++;
        continue;
      }

      try {
        onProgress?.call('上传: $relPath');
        final localPath = p.join(localBasePath, relPath);
        await oss.uploadFile(localPath, ossKey);
        uploaded++;
      } catch (e) {
        errors.add('上传失败 $relPath: $e');
      }
    }

    return {'uploaded': uploaded, 'skipped': skipped, 'errors': errors};
  }

  // ─── 下载逻辑 ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _doDownload({
    required OssService oss,
    required Map<String, String> localFiles,
    required Map<String, OssObject> ossMap,
    required String localBasePath,
    required String remotePrefix,
    void Function(String)? onProgress,
    bool skipExisting = false,
  }) async {
    int downloaded = 0, skipped = 0;
    final errors = <String>[];

    for (final entry in ossMap.entries) {
      final ossRelKey = entry.key;
      final ossObj = entry.value;
      final localRelPath = ossRelKey.replaceAll('/', p.separator);

      // 双向同步时跳过本地已有且 MD5 相同的文件
      if (skipExisting) {
        final localMd5 = localFiles[localRelPath];
        if (localMd5 != null && localMd5 == ossObj.etag) {
          skipped++;
          continue;
        }
        // 本地已有但 MD5 不同时，以 OSS 为准（下载覆盖）
      } else {
        final localMd5 = localFiles[localRelPath];
        if (localMd5 != null && localMd5 == ossObj.etag) {
          skipped++;
          continue;
        }
      }

      try {
        onProgress?.call('下载: $ossRelKey');
        final localPath = p.join(localBasePath, localRelPath);
        final ossKey = '$remotePrefix$ossRelKey';
        await oss.downloadFile(ossKey, localPath);
        downloaded++;
      } catch (e) {
        errors.add('下载失败 $ossRelKey: $e');
      }
    }

    return {'downloaded': downloaded, 'skipped': skipped, 'errors': errors};
  }

  // ─── 工具方法 ─────────────────────────────────────────────────────────────────

  /// 扫描本地文件夹，返回 相对路径 -> MD5 的映射
  Future<Map<String, String>> _scanLocalFiles(String basePath) async {
    final result = <String, String>{};
    final dir = Directory(basePath);
    if (!await dir.exists()) return result;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relPath = p.relative(entity.path, from: basePath);
        final bytes = await entity.readAsBytes();
        final digest = md5.convert(bytes);
        result[relPath] = digest.toString();
      }
    }
    return result;
  }

  String _normalizeRemotePath(String remotePath) {
    if (remotePath.isEmpty) return '';
    // 确保以 / 结尾，不以 / 开头
    var path = remotePath.replaceAll('\\', '/');
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isNotEmpty && !path.endsWith('/')) path = '$path/';
    return path;
  }
}
