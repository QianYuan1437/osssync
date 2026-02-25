import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'providers/account_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(900, 600),
    center: true,
    title: 'OSS Sync',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 初始化本地存储
  final storage = StorageService();
  await storage.init();

  // 初始化 Provider
  final themeProvider = ThemeProvider(storage);
  await themeProvider.init();

  final accountProvider = AccountProvider(storage);
  await accountProvider.init();

  final syncProvider = SyncProvider(storage);
  // 注入账户和存储桶查找函数
  syncProvider.getAccount = accountProvider.getAccountById;
  syncProvider.getBucketConfig = accountProvider.getBucketConfigById;
  await syncProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: syncProvider),
      ],
      child: const AppWithTray(),
    ),
  );
}

class AppWithTray extends StatefulWidget {
  const AppWithTray({super.key});

  @override
  State<AppWithTray> createState() => _AppWithTrayState();
}

class _AppWithTrayState extends State<AppWithTray>
    with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    // 必须设置 preventClose 才能拦截关闭事件
    windowManager.setPreventClose(true);
    _initTray();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/icons/tray_icon.png');
    final menu = Menu(items: [
      MenuItem(key: 'show', label: '显示主窗口'),
      MenuItem.separator(),
      MenuItem(key: 'sync_all', label: '立即同步全部'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]);
    await trayManager.setContextMenu(menu);
    await trayManager.setToolTip('OSS Sync - 阿里云 OSS 同步工具');
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  // ─── TrayListener ────────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        break;
      case 'sync_all':
        final syncProvider = context.read<SyncProvider>();
        syncProvider.runAllEnabledTasks();
        break;
      case 'quit':
        windowManager.destroy();
        break;
    }
  }

  // ─── WindowListener ──────────────────────────────────────────────────────────

  @override
  void onWindowClose() async {
    // 拦截关闭事件，最小化到托盘而非退出
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const OssSyncApp();
  }
}
