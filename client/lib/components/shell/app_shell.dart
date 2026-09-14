import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/tokens.dart';

enum AppNavDestination {
  home,
  join,
  events,
  sessions,
  users,
}

extension AppNavDestinationX on AppNavDestination {
  String get label => switch (this) {
        AppNavDestination.home => 'Home',
        AppNavDestination.join => 'Join quiz',
        AppNavDestination.events => 'Events',
        AppNavDestination.sessions => 'Sessions',
        AppNavDestination.users => 'Users',
      };

  /// Short label for the compact mobile bottom bar.
  String get shortLabel => switch (this) {
        AppNavDestination.home => 'Home',
        AppNavDestination.join => 'Join',
        AppNavDestination.events => 'Events',
        AppNavDestination.sessions => 'Sessions',
        AppNavDestination.users => 'Users',
      };

  IconData get icon => switch (this) {
        AppNavDestination.home => Icons.home_outlined,
        AppNavDestination.join => Icons.qr_code_2_outlined,
        AppNavDestination.events => Icons.event_outlined,
        AppNavDestination.sessions => Icons.quiz_outlined,
        AppNavDestination.users => Icons.group_outlined,
      };

  IconData get selectedIcon => switch (this) {
        AppNavDestination.home => Icons.home,
        AppNavDestination.join => Icons.qr_code_2,
        AppNavDestination.events => Icons.event,
        AppNavDestination.sessions => Icons.quiz,
        AppNavDestination.users => Icons.group,
      };

  bool requiresAdmin() => switch (this) {
        AppNavDestination.events ||
        AppNavDestination.sessions ||
        AppNavDestination.users =>
          true,
        _ => false,
      };
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.authService,
    required this.destination,
    required this.body,
    this.title,
    this.actions = const [],
    this.showSearch = true,
    this.showNav = true,
    this.floatingActionButton,
    this.maxContentWidth = AppLayoutTokens.contentMaxWidth,
  });

  final AuthService authService;
  final AppNavDestination? destination;
  final Widget body;
  final String? title;
  final List<Widget> actions;
  final bool showSearch;
  final bool showNav;
  final Widget? floatingActionButton;
  final double maxContentWidth;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _navCollapsed = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppNavDestination> _destinations(bool isAdmin) {
    return [
      AppNavDestination.home,
      AppNavDestination.join,
      if (isAdmin) ...[
        AppNavDestination.events,
        AppNavDestination.sessions,
        AppNavDestination.users,
      ],
    ];
  }

  void _navigate(AppNavDestination dest) {
    if (dest == widget.destination) return;

    final nav = Navigator.of(context);
    switch (dest) {
      case AppNavDestination.home:
        nav.popUntil((route) => route.isFirst);
      case AppNavDestination.join:
        nav.pushNamed('/join');
      case AppNavDestination.events:
        nav.pushNamed('/admin/events');
      case AppNavDestination.sessions:
        nav.pushNamed('/admin/sessions');
      case AppNavDestination.users:
        nav.pushNamed('/admin/users');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AppLayoutTokens.breakpointDrawer;
    final autoCollapse = width < AppLayoutTokens.breakpointCollapse;
    final collapsed = widget.showNav && (autoCollapse || _navCollapsed);
    final user = widget.authService.user;
    final isAdmin = user?.isAdmin ?? false;
    final destinations = _destinations(isAdmin);
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBottomNav = isMobile && widget.showNav;

    final navRail = widget.showNav && !isMobile
        ? _NavRail(
            destinations: destinations,
            selected: widget.destination,
            collapsed: collapsed,
            onSelect: _navigate,
            onToggleCollapse: autoCollapse
                ? null
                : () => setState(() => _navCollapsed = !_navCollapsed),
          )
        : null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: widget.floatingActionButton,
      body: Column(
        children: [
          _TopAppBar(
            title: widget.title,
            showSearch: widget.showSearch && !isMobile,
            searchController: _searchController,
            actions: widget.actions,
            authService: widget.authService,
            showBack: canPop && (!widget.showNav || widget.destination == null),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?navRail,
                Expanded(
                  child: ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: widget.maxContentWidth,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: width >= AppLayoutTokens.breakpointCollapse
                                ? AppLayoutTokens.contentGutterWide
                                : AppSpace.s4,
                            vertical: AppSpace.s4,
                          ),
                          child: widget.body,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showBottomNav)
            _BottomNavBar(
              destinations: destinations,
              selected: widget.destination,
              onSelect: _navigate,
            ),
        ],
      ),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({
    required this.authService,
    required this.searchController,
    required this.actions,
    required this.showSearch,
    required this.showBack,
    this.title,
  });

  final AuthService authService;
  final TextEditingController searchController;
  final List<Widget> actions;
  final bool showSearch;
  final bool showBack;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = authService.user;

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        height: AppLayoutTokens.topBarHeight,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outline),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
            _BrandMark(compact: MediaQuery.sizeOf(context).width < 600),
            if (title != null) ...[
              const SizedBox(width: AppSpace.s3),
              Container(
                width: 1,
                height: 24,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: AppSpace.s3),
              Flexible(
                child: Text(
                  title!,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
            if (showSearch) ...[
              const SizedBox(width: AppSpace.s5),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _SearchField(controller: searchController),
                  ),
                ),
              ),
            ] else
              const Spacer(),
            ...actions,
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No new notifications')),
                );
              },
              icon: const Icon(Icons.notifications_outlined),
            ),
            const SizedBox(width: AppSpace.s1),
            _ProfileMenu(authService: authService, userEmail: user?.email),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: AppRadii.smBorder,
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: AppRadii.smBorder,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.bolt_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Text(
              compact ? AppBrand.shortName : AppBrand.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppLayoutTokens.searchHeight,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search sessions, events…',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: theme.scaffoldBackgroundColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          border: OutlineInputBorder(
            borderRadius: AppRadii.pillBorder,
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadii.pillBorder,
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.pillBorder,
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.authService,
    required this.userEmail,
  });

  final AuthService authService;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (userEmail != null && userEmail!.isNotEmpty)
        ? userEmail![0].toUpperCase()
        : '?';

    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      offset: const Offset(0, 8),
      onSelected: (value) async {
        if (value == 'signout') {
          await authService.signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authService.user?.displayName ?? 'Signed in',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                userEmail ?? '',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'signout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
            dense: true,
          ),
        ),
      ],
      child: CircleAvatar(
        radius: AppLayoutTokens.avatarSize / 2,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.primary,
        child: Text(
          initial,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.destinations,
    required this.selected,
    required this.onSelect,
  });

  final List<AppNavDestination> destinations;
  final AppNavDestination? selected;
  final ValueChanged<AppNavDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outline),
          ),
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final dest in destinations)
                Expanded(
                  child: _BottomNavItem(
                    destination: dest,
                    selected: dest == selected,
                    onTap: () => onSelect(dest),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s1,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: AppRadii.pillBorder,
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.shortLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                letterSpacing: 0,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.destinations,
    required this.selected,
    required this.collapsed,
    required this.onSelect,
    required this.onToggleCollapse,
  });

  final List<AppNavDestination> destinations;
  final AppNavDestination? selected;
  final bool collapsed;
  final ValueChanged<AppNavDestination> onSelect;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = collapsed
        ? AppLayoutTokens.navCollapsedWidth
        : AppLayoutTokens.navExpandedWidth;

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
      child: Column(
        children: [
          if (onToggleCollapse != null)
            Align(
              alignment: collapsed ? Alignment.center : Alignment.centerRight,
              child: IconButton(
                tooltip: collapsed ? 'Expand navigation' : 'Collapse navigation',
                onPressed: onToggleCollapse,
                icon: Icon(
                  collapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s2,
                vertical: AppSpace.s2,
              ),
              children: [
                for (final dest in destinations)
                  _NavItem(
                    destination: dest,
                    selected: dest == selected,
                    collapsed: collapsed,
                    onTap: () => onSelect(dest),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final bg = selected
        ? theme.colorScheme.primaryContainer
        : _hovered
            ? (theme.brightness == Brightness.dark
                ? AppColors.darkSurfaceHover
                : AppColors.surfaceHover)
            : Colors.transparent;
    final fg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s1),
      child: Tooltip(
        message: widget.collapsed ? widget.destination.label : '',
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            color: bg,
            borderRadius: AppRadii.pillBorder,
            child: InkWell(
              borderRadius: AppRadii.pillBorder,
              onTap: widget.onTap,
              child: Semantics(
                button: true,
                selected: selected,
                label: widget.destination.label,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                  height: 48,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.collapsed ? 0 : AppSpace.s4,
                  ),
                  alignment:
                      widget.collapsed ? Alignment.center : Alignment.centerLeft,
                  child: widget.collapsed
                      ? Icon(
                          selected
                              ? widget.destination.selectedIcon
                              : widget.destination.icon,
                          color: fg,
                        )
                      : Row(
                          children: [
                            Icon(
                              selected
                                  ? widget.destination.selectedIcon
                                  : widget.destination.icon,
                              color: fg,
                            ),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(
                              child: Text(
                                widget.destination.label,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: fg,
                                  fontWeight: selected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Focus layout for quiz play / auth — top chrome only, no nav rail.
class AppFocusShell extends StatelessWidget {
  const AppFocusShell({
    super.key,
    required this.authService,
    required this.body,
    this.title,
    this.actions = const [],
    this.centerBody = true,
    this.maxContentWidth = 720,
  });

  final AuthService authService;
  final Widget body;
  final String? title;
  final List<Widget> actions;
  final bool centerBody;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      authService: authService,
      destination: null,
      title: title,
      actions: actions,
      showSearch: false,
      showNav: false,
      maxContentWidth: maxContentWidth,
      body: centerBody
          ? Center(
              child: SingleChildScrollView(child: body),
            )
          : body,
    );
  }
}
