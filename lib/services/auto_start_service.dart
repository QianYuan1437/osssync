import 'dart:io';
import 'package:path/path.dart' as p;

class AutoStartService {
  static const _desktopEntry = '''
[Desktop Entry]
Name=OSS Sync
Comment=阿里云 OSS 存储桶自动同步工具
Exec=%EXEC%
Icon=osssync
Type=Application
Categories=Utility;
StartupWMClass=OSS Sync
X-GNOME-Autostart-enabled=true
''';

  /// 获取自动启动目录路径
  Future<String> _getAutoStartDir() async {
    final home = Platform.environment['HOME'] ?? '/root';
    return p.join(home, '.config', 'autostart');
  }

  /// 获取.desktop文件路径
  Future<String> _getDesktopFilePath() async {
    final dir = await _getAutoStartDir();
    return p.join(dir, 'osssync.desktop');
  }

  /// 检查是否已启用开机自启
  Future<bool> isAutoStartEnabled() async {
    final filePath = await _getDesktopFilePath();
    return File(filePath).exists();
  }

  /// 启用开机自启
  Future<void> enableAutoStart() async {
    final dirPath = await _getAutoStartDir();
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filePath = await _getDesktopFilePath();
    final execPath = Platform.resolvedExecutable;
    final content = _desktopEntry.replaceAll('%EXEC%', execPath);
    await File(filePath).writeAsString(content);
  }

  /// 禁用开机自启
  Future<void> disableAutoStart() async {
    final filePath = await _getDesktopFilePath();
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 设置开机自启状态
  Future<void> setAutoStart(bool enabled) async {
    if (enabled) {
      await enableAutoStart();
    } else {
      await disableAutoStart();
    }
  }
}
