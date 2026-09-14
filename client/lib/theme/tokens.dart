import 'package:flutter/material.dart';

/// Google Skills / Cloud–inspired design tokens.
/// Prefer these (or Theme.of(context)) — never hardcode hex in widgets.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF0B57D0);
  static const primaryHover = Color(0xFF0842A0);
  static const primaryContainer = Color(0xFFD3E3FD);
  static const onPrimary = Color(0xFFFFFFFF);

  // Neutrals (light)
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8F9FA);
  static const surfaceHover = Color(0xFFF1F3F4);
  static const border = Color(0xFFDADCE0);
  static const borderStrong = Color(0xFFC4C7C5);

  // Text (light)
  static const textPrimary = Color(0xFF1F1F1F);
  static const textSecondary = Color(0xFF444746);
  static const textDisabled = Color(0xFFA0A4A8);

  // Semantic
  static const success = Color(0xFF1E8E3E);
  static const successContainer = Color(0xFFE6F4EA);
  static const warning = Color(0xFFF9AB00);
  static const warningContainer = Color(0xFFFEF7E0);
  static const error = Color(0xFFD93025);
  static const errorContainer = Color(0xFFFCE8E6);
  static const info = Color(0xFF1A73E8);

  // Dark theme
  static const darkSurface = Color(0xFF131314);
  static const darkSurfaceAlt = Color(0xFF1E1F20);
  static const darkSurfaceHover = Color(0xFF28292A);
  static const darkBorder = Color(0xFF3C4043);
  static const darkBorderStrong = Color(0xFF5F6368);
  static const darkPrimary = Color(0xFFA8C7FA);
  static const darkPrimaryContainer = Color(0xFF0842A0);
  static const darkOnPrimary = Color(0xFF062E6F);
  static const darkTextPrimary = Color(0xFFE3E3E3);
  static const darkTextSecondary = Color(0xFFC4C7C5);
  static const darkTextDisabled = Color(0xFF8E918F);

  static const scrim = Color(0x66000000);
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;

  static final smBorder = BorderRadius.circular(sm);
  static final mdBorder = BorderRadius.circular(md);
  static final lgBorder = BorderRadius.circular(lg);
  static final pillBorder = BorderRadius.circular(pill);
}

abstract final class AppSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
  static const s8 = 64.0;
}

abstract final class AppShadows {
  static const shadow1 = [
    BoxShadow(
      color: Color(0x4D3C4043),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color(0x263C4043),
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 1,
    ),
  ];

  static const shadow2 = [
    BoxShadow(
      color: Color(0x4D3C4043),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color(0x263C4043),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 2,
    ),
  ];

  static const shadow3 = [
    BoxShadow(
      color: Color(0x263C4043),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 3,
    ),
    BoxShadow(
      color: Color(0x4D3C4043),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
  ];
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const curve = Curves.easeOut;
}

abstract final class AppLayoutTokens {
  static const topBarHeight = 64.0;
  static const navExpandedWidth = 240.0;
  static const navCollapsedWidth = 72.0;
  static const contentMaxWidth = 1280.0;
  static const contentGutter = 24.0;
  static const contentGutterWide = 32.0;
  static const breakpointCollapse = 1024.0;
  static const breakpointDrawer = 768.0;
  static const buttonHeight = 40.0;
  static const searchHeight = 48.0;
  static const tableRowHeight = 52.0;
  static const avatarSize = 32.0;
  static const iconSize = 24.0;
}

abstract final class AppBrand {
  static const name = 'DevFest Live Quiz';
  static const shortName = 'DevFest';
  static const eventName = 'DevFest 2026';
  static const tagline = 'Join a session or manage live quizzes.';
}
