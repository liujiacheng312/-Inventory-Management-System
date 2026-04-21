import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import 'admin_panel.dart';
import 'inventory_page.dart';
import 'login_page.dart';
import 'record_page.dart';

class HomePage extends StatefulWidget {
  final User user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _compactBreakpoint = 720;

  int _currentIndex = 0;
  late final List<Widget> _pages;
  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _pages = [
      InventoryPage(isAdmin: widget.user.isAdmin),
      RecordPage(isAdmin: widget.user.isAdmin),
      if (widget.user.isAdmin) AdminPanel(isSuperAdmin: widget.user.isSuperAdmin),
    ];

    _navItems = [
      const _NavItem(
        label: '库存',
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
      ),
      const _NavItem(
        label: '记录',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
      ),
      if (widget.user.isAdmin)
        const _NavItem(
          label: '管理',
          icon: Icons.tune_outlined,
          activeIcon: Icons.tune_rounded,
        ),
    ];
  }

  String get _currentTitle => _navItems[_currentIndex].label;

  Future<void> _logout() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width < _compactBreakpoint ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.panel.withOpacity(0.82),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: AppTheme.softShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          final isCompact = constraints.maxWidth < _compactBreakpoint;
          final roleLabel = widget.user.isAdmin ? '管理员' : '普通用户';
          final description = widget.user.isAdmin
              ? '管理员工作台，集中处理库存、审批与批量导入。'
              : '查看库存状态、提交领用并追踪个人记录。';

          final userChip = _InfoChip(
            icon: Icons.person_outline_rounded,
            label: widget.user.username,
            color: AppTheme.mint,
          );

          final leading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTitle,
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: isCompact ? 26 : 30,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: isCompact ? 14 : null,
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(height: 18),
                userChip,
              ],
            ],
          );

          final trailing = Column(
            crossAxisAlignment:
                isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.ink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前身份',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.74),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleLabel,
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('退出登录'),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentTitle,
                        style: textTheme.headlineMedium?.copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Icon(Icons.logout_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppTheme.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    userChip,
                    _InfoChip(
                      icon: Icons.verified_user_outlined,
                      label: '身份 · $roleLabel',
                      color: AppTheme.ink,
                    ),
                  ],
                ),
              ],
            );
          }

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: leading),
                const SizedBox(width: 20),
                Expanded(child: trailing),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(height: 18),
              trailing,
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavigation(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < _compactBreakpoint;

    return Container(
      padding: EdgeInsets.all(isCompact ? 6 : 8),
      decoration: BoxDecoration(
        color: AppTheme.panel.withOpacity(0.82),
        borderRadius: BorderRadius.circular(isCompact ? 24 : 28),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: AppTheme.softShadow,
      ),
      child: NavigationBar(
        height: isCompact ? 64 : null,
        selectedIndex: _currentIndex,
        backgroundColor: Colors.transparent,
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < _compactBreakpoint;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 14 : 20,
              isCompact ? 12 : 18,
              isCompact ? 14 : 20,
              isCompact ? 12 : 20,
            ),
            child: Column(
              children: [
                _buildHeader(context),
                SizedBox(height: isCompact ? 14 : 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.panel.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(isCompact ? 24 : 34),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isCompact ? 24 : 34),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _pages,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 14 : 18),
                _buildNavigation(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < _HomePageState._compactBreakpoint;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 14,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 16 : 18, color: color),
          SizedBox(width: isCompact ? 6 : 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: isCompact ? 12 : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
