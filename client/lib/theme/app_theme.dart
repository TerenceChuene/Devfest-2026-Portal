import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Material 3 theme restrained to Google Cloud / Skills house style.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.darkPrimary : AppColors.primary,
      onPrimary: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary,
      primaryContainer:
          isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
      onPrimaryContainer:
          isDark ? AppColors.darkPrimary : AppColors.primaryHover,
      secondary: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      onSecondary: isDark ? AppColors.darkSurface : AppColors.surface,
      secondaryContainer:
          isDark ? AppColors.darkSurfaceHover : AppColors.surfaceHover,
      onSecondaryContainer:
          isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      tertiary: AppColors.info,
      onTertiary: AppColors.onPrimary,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.error,
      surface: isDark ? AppColors.darkSurface : AppColors.surface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      onSurfaceVariant:
          isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      outline: isDark ? AppColors.darkBorder : AppColors.border,
      outlineVariant:
          isDark ? AppColors.darkBorderStrong : AppColors.borderStrong,
      shadow: const Color(0xFF3C4043),
      scrim: AppColors.scrim,
      inverseSurface:
          isDark ? AppColors.surfaceAlt : AppColors.darkSurfaceAlt,
      onInverseSurface:
          isDark ? AppColors.textPrimary : AppColors.darkTextPrimary,
      inversePrimary: isDark ? AppColors.primary : AppColors.darkPrimary,
      surfaceTint: Colors.transparent,
    );

    final display = GoogleFonts.figtreeTextTheme();
    final body = GoogleFonts.robotoTextTheme();

    final textTheme = TextTheme(
      displayLarge: display.displayLarge?.copyWith(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        letterSpacing: 0,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        letterSpacing: 0,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleSmall: body.titleSmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
    );

    final pageBg = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: pageBg,
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outline,
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge,
        toolbarHeight: AppLayoutTokens.topBarHeight,
        shape: Border(
          bottom: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdBorder,
          side: BorderSide(color: colorScheme.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.outline.withValues(alpha: 0.4),
          disabledForegroundColor:
              isDark ? AppColors.darkTextDisabled : AppColors.textDisabled,
          minimumSize: const Size(64, AppLayoutTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return (isDark ? AppColors.primary : AppColors.primaryHover)
                  .withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.pressed)) {
              return Colors.black.withValues(alpha: 0.12);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size(64, AppLayoutTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: textTheme.labelLarge,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return isDark ? AppColors.darkSurfaceHover : AppColors.surfaceHover;
            }
            return Colors.transparent;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(64, AppLayoutTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pageBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s3,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.smBorder,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.smBorder,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.smBorder,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.smBorder,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: isDark ? AppColors.darkTextDisabled : AppColors.textDisabled,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: pageBg,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge!,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.lgBorder),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceHover : AppColors.textPrimary,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smBorder),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
        minVerticalPadding: AppSpace.s3,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smBorder),
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: AppLayoutTokens.iconSize,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceHover : AppColors.textPrimary,
          borderRadius: AppRadii.smBorder,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.surface,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(
          color: colorScheme.primary,
          size: AppLayoutTokens.iconSize,
        ),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: AppLayoutTokens.iconSize,
        ),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        dividerColor: colorScheme.outline,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdBorder,
          side: BorderSide(color: colorScheme.outline),
        ),
        textStyle: textTheme.bodyLarge,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(pageBg),
        headingTextStyle: textTheme.labelSmall?.copyWith(
          letterSpacing: 0.4,
          fontWeight: FontWeight.w500,
        ),
        dataTextStyle: textTheme.bodyLarge,
        dividerThickness: 1,
        horizontalMargin: AppSpace.s4,
        headingRowHeight: AppLayoutTokens.tableRowHeight,
        dataRowMinHeight: AppLayoutTokens.tableRowHeight,
        dataRowMaxHeight: AppLayoutTokens.tableRowHeight,
      ),
    );
  }
}
