import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Surface card with Google-style elevation transition on hover.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.s4),
    this.flat = false,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool flat;
  final EdgeInsetsGeometry margin;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shadows = widget.flat
        ? const <BoxShadow>[]
        : (_hovered ? AppShadows.shadow2 : AppShadows.shadow1);

    return Padding(
      padding: widget.margin,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadii.mdBorder,
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: shadows,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: AppRadii.mdBorder,
              hoverColor: theme.brightness == Brightness.dark
                  ? AppColors.darkSurfaceHover
                  : AppColors.surfaceHover,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.avatar,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    if (onSelected == null) {
      final theme = Theme.of(context);
      return Chip(
        avatar: avatar,
        label: Text(label),
        backgroundColor:
            selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.outlineVariant,
        ),
      );
    }
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      showCheckmark: false,
    );
  }
}

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.icon = Icons.workspace_premium_outlined,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: AppRadii.smBorder,
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: AppSpace.s2),
        Text(label, style: theme.textTheme.labelLarge),
      ],
    );
  }
}

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 4,
  });

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.pillBorder,
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.displayMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: AppSpace.s2, children: actions),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpace.s3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = status.toLowerCase();
    final Color bg;
    final Color fg;
    if (normalized == 'join_open') {
      bg = AppColors.successContainer;
      fg = AppColors.success;
    } else if (normalized == 'closed') {
      bg = AppColors.errorContainer;
      fg = AppColors.error;
    } else {
      bg = theme.colorScheme.primaryContainer;
      fg = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class AppDataRow extends StatefulWidget {
  const AppDataRow({
    super.key,
    required this.child,
    this.onTap,
    this.height = AppLayoutTokens.tableRowHeight,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double height;

  @override
  State<AppDataRow> createState() => _AppDataRowState();
}

class _AppDataRowState extends State<AppDataRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? (theme.brightness == Brightness.dark
                ? AppColors.darkSurfaceHover
                : AppColors.surfaceHover)
            : theme.colorScheme.surface,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: widget.height),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            alignment: Alignment.centerLeft,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
