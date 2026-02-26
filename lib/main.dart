import 'package:flutter/foundation.dart';
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
        Provider.value(value: storage),
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
    // Windows 需要 .ico 格式，其他平台使用 .png
    final iconPath = defaultTargetPlatform == TargetPlatform.windows
        ? 'assets/icons/tray_icon.ico'
        : 'assets/icons/cloud.png';
    await trayManager.setIcon(iconPath);
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
    final storage = context.read<StorageService>();
    final isActionSet = storage.isCloseActionSet();

    if (!isActionSet) {
      // 首次关闭：弹出选择对话框
      final result = await _showCloseActionDialog(storage);
      if (result == null) {
        // 用户取消，不做任何操作（窗口保持打开）
        return;
      }
      if (result == 'exit') {
        await windowManager.destroy();
      } else {
        await windowManager.hide();
      }
    } else {
      final action = storage.getCloseAction();
      if (action == 'exit') {
        await windowManager.destroy();
      } else {
        await windowManager.hide();
      }
    }
  }

  /// 弹出关闭行为选择对话框，返回 'minimize' / 'exit' / null（取消）
  Future<String?> _showCloseActionDialog(StorageService storage) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CloseActionDialog(storage: storage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const OssSyncApp();
  }
}

/// 关闭行为选择对话框
class _CloseActionDialog extends StatefulWidget {
  final StorageService storage;
  const _CloseActionDialog({required this.storage});

  @override
  State<_CloseActionDialog> createState() => _CloseActionDialogState();
}

class _CloseActionDialogState extends State<_CloseActionDialog> {
  String _selected = 'minimize'; // 默认最小化到托盘
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.help_outline, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('关闭窗口'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请选择点击关闭按钮时的行为：',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _ActionOption(
              value: 'minimize',
              groupValue: _selected,
              title: '最小化到系统托盘',
              subtitle: '程序继续在后台运行，可从托盘图标恢复',
              icon: Icons.minimize,
              onChanged: (v) => setState(() => _selected = v!),
            ),
            const SizedBox(height: 8),
            _ActionOption(
              value: 'exit',
              groupValue: _selected,
              title: '退出程序',
              subtitle: '完全退出，停止所有同步任务',
              icon: Icons.exit_to_app,
              onChanged: (v) => setState(() => _selected = v!),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _remember = !_remember),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '记住我的选择，不再询问',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (!_remember)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  '提示：可在"控制台 → 应用设置"中随时更改',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            if (_remember) {
              await widget.storage.saveCloseAction(_selected);
              await widget.storage.setCloseActionConfirmed();
            }
            if (context.mounted) Navigator.of(context).pop(_selected);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 单个选项行（带单选框）
class _ActionOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _ActionOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 自定义圆形选中指示器（避免 Radio deprecated API）
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
