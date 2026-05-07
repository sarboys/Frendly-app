import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static final ThemeData light = _buildTheme(AppColors.lightTheme);
  static final ThemeData dark = _buildTheme(AppColors.darkTheme);

  static ThemeData _buildTheme(BigBreakThemeColors colors) {
    final brightness = colors.isDark ? Brightness.dark : Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.primaryForeground,
        secondary: colors.secondary,
        onSecondary: colors.secondaryForeground,
        error: colors.destructive,
        onError: colors.destructiveForeground,
        surface: colors.card,
        onSurface: colors.foreground,
      ),
      textTheme: AppTextStyles.theme(colors),
      primaryTextTheme: AppTextStyles.theme(colors),
      dividerColor: colors.border,
      cardColor: colors.card,
      extensions: [colors],
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.foreground,
          iconSize: 20,
          padding: const EdgeInsets.all(10),
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.primaryForeground,
        shape: const CircleBorder(),
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: AppTextStyles.button.copyWith(fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryForeground,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryForeground,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
          foregroundColor: colors.foreground,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: colors.border),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: const StadiumBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: AppTextStyles.caption.copyWith(color: colors.inkSoft),
        secondaryLabelStyle:
            AppTextStyles.caption.copyWith(color: colors.primaryForeground),
        backgroundColor: colors.card,
        selectedColor: colors.primary,
        disabledColor: colors.muted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: colors.border),
        shape: const StadiumBorder(),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTextStyles.itemTitle.copyWith(
          color: colors.foreground,
        ),
        subtitleTextStyle: AppTextStyles.bodySoft.copyWith(
          color: colors.inkSoft,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: colors.primary,
        labelTextStyle: WidgetStatePropertyAll(
          AppTextStyles.caption.copyWith(color: colors.inkSoft),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: colors.inkSoft, size: 20),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: AppTextStyles.button.copyWith(fontSize: 13),
        unselectedLabelStyle: AppTextStyles.button.copyWith(fontSize: 13),
        labelColor: colors.foreground,
        unselectedLabelColor: colors.inkMute,
        indicatorColor: colors.primary,
        dividerColor: Colors.transparent,
      ),
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 56,
        titleTextStyle: AppTextStyles.sectionTitle.copyWith(
          color: colors.foreground,
        ),
        toolbarTextStyle: AppTextStyles.meta.copyWith(
          color: colors.inkSoft,
        ),
        iconTheme: IconThemeData(color: colors.foreground, size: 20),
        actionsIconTheme: IconThemeData(color: colors.foreground, size: 20),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        modalBackgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: colors.foreground.withValues(alpha: 0.5),
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: colors.border,
        dragHandleSize: const Size(36, 4),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: const BoxConstraints(maxWidth: 440),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.cardTitle.copyWith(
          color: colors.foreground,
        ),
        contentTextStyle: AppTextStyles.bodySoft.copyWith(
          color: colors.inkSoft,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        menuPadding: const EdgeInsets.symmetric(vertical: 8),
        textStyle: AppTextStyles.meta.copyWith(color: colors.foreground),
        labelTextStyle: WidgetStatePropertyAll(
          AppTextStyles.meta.copyWith(color: colors.foreground),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: colors.card,
        hintStyle: AppTextStyles.bodySoft.copyWith(color: colors.inkMute),
        labelStyle: AppTextStyles.meta.copyWith(color: colors.inkSoft),
        floatingLabelStyle: AppTextStyles.meta.copyWith(color: colors.primary),
        helperStyle: AppTextStyles.caption.copyWith(color: colors.inkMute),
        errorStyle: AppTextStyles.caption.copyWith(color: colors.destructive),
        prefixIconColor: colors.inkMute,
        suffixIconColor: colors.inkMute,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.foreground,
        selectionColor: colors.primarySoft,
        selectionHandleColor: colors.foreground,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.primary,
        contentTextStyle: AppTextStyles.meta.copyWith(
          color: colors.primaryForeground,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      focusColor: Colors.transparent,
    );
  }
}
