import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/sync_provider.dart';
import '../screens/home_screen.dart';
import '../screens/accounts_screen.dart';
import '../screens/sync_tasks_screen.dart';
import '../screens/logs_screen.dart';

/// 主框架：左侧导航 + 右侧 IndexedStack 页面区域
/// 完全使用原生 Navigator，不依赖 go_router
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _SideNav(
            currentIndex: _currentIndex,
            onTap: _switchTab,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _AnimatedIndexedStack(
              index: _currentIndex,
              children: const [
                HomeScreen(),
                AccountsScreen(),
                SyncTasksScreen(),
                LogsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 带淡入淡出动画的 IndexedStack
class _AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _AnimatedIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  State<_AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<_AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _index = widget.index;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: IndexedStack(
        index: _index,
        children: widget.children,
      ),
    );
  }
}

/// 左侧导航栏
class _SideNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SideNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.read<ThemeProvider>();
    final syncProvider = context.watch<SyncProvider>();

    return Container(
      width: 200,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // 应用标题
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.cloud_sync,
                    color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'OSS Sync',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: '控制台',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts,
            label: '账户管理',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.sync_outlined,
            activeIcon: Icons.sync,
            label: '同步任务',
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
            badge: syncProvider.hasAnySyncing ? '●' : null,
          ),
          _NavItem(
            icon: Icons.history_outlined,
            activeIcon: Icons.history,
            label: '同步日志',
            isActive: currentIndex == 3,
            onTap: () => onTap(3),
          ),
          const Spacer(),
          const Divider(height: 1),
          // 主题切换
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  isDark ? '深色模式' : '浅色模式',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isDark,
                  onChanged: (_) => themeProvider.toggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final bgColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey(isActive),
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (badge != null) ...[
                  const Spacer(),
                  Text(
                    badge!,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
