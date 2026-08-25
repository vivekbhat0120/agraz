import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_l10n.dart';
import 'l10n/locale_controller.dart';

/// AgRaz design system — a modern, professional and cohesive look.
///
/// Central place for colours, typography, theme and reusable UI primitives
/// (headers, cards, fields, buttons, chips) used across the app.

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF17714B);
  static const Color primaryDark = Color(0xFF105A3C);
  static const Color primaryDeep = Color(0xFF0B4630);
  static const Color primaryLight = Color(0xFF2E9265);
  static const Color primarySoft = Color(0xFFE3F3EA);

  static const Color accent = Color(0xFFE9A13B);
  static const Color accentSoft = Color(0xFFFCF2E1);

  // Semantic
  static const Color income = Color(0xFF16A34A);
  static const Color incomeSoft = Color(0xFFE6F7EC);
  static const Color expense = Color(0xFFDC2626);
  static const Color expenseSoft = Color(0xFFFDEBEA);
  static const Color info = Color(0xFF2E7CF6);
  static const Color infoSoft = Color(0xFFE9F2FE);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFCF0E1);

  // Surfaces
  static const Color background = Color(0xFFF6F8F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEEF3F0);
  static const Color field = Color(0xFFF0F4F2);

  // Text
  static const Color textPrimary = Color(0xFF14281D);
  static const Color textSecondary = Color(0xFF5C6B63);
  static const Color textMuted = Color(0xFF8A9890);

  // Misc
  static const Color border = Color(0xFFE3EAE6);

  static const List<Color> headerGradient = [
    Color(0xFF0B4630),
    Color(0xFF17714B),
    Color(0xFF2E9265),
  ];

  static const List<Color> buttonGradient = [
    Color(0xFF1B8358),
    Color(0xFF0F5939),
  ];

  static const List<Color> ctaGradient = [
    Color(0xFF0F5939),
    Color(0xFF1B8358),
    Color(0xFF2E9265),
  ];

  static final BoxShadow cardShadow = BoxShadow(
    color: const Color(0xFF14281D).withValues(alpha: 0.06),
    blurRadius: 18,
    offset: const Offset(0, 6),
  );

  static final BoxShadow softShadow = BoxShadow(
    color: const Color(0xFF14281D).withValues(alpha: 0.04),
    blurRadius: 10,
    offset: const Offset(0, 3),
  );
}

class AppText {
  AppText._();

  static TextStyle _kn(TextStyle style) {
    if (!LocaleController.instance.isKannada) return style;
    return GoogleFonts.notoSansKannada(
      textStyle: style.copyWith(height: (style.height ?? 1.3) + 0.12),
    );
  }

  static TextStyle get h1 => _kn(const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  ));

  static TextStyle get h2 => _kn(const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  ));

  static TextStyle get h3 => _kn(const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  ));

  static TextStyle get title => _kn(const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  ));

  static TextStyle get subtitle => _kn(const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textSecondary,
  ));

  static TextStyle get body => _kn(const TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  ));

  static TextStyle get bodyStrong => _kn(const TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.textPrimary,
  ));

  static TextStyle get small => _kn(const TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.textSecondary,
  ));

  static TextStyle get label => _kn(const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  ));

  static TextStyle get caption => _kn(const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.textMuted,
  ));
}

class AppTheme {
  AppTheme._();

  static TextTheme _textThemeFor(TextTheme base) {
    final isKn = LocaleController.instance.isKannada;
    // Noto Sans Kannada avoids clipped / missing glyphs for KN UI.
    TextStyle kn(TextStyle style) {
      if (!isKn) return style;
      return GoogleFonts.notoSansKannada(
        textStyle: style.copyWith(height: (style.height ?? 1.3) + 0.15),
      );
    }

    return base.copyWith(
      displaySmall: kn(AppText.h1),
      headlineMedium: kn(AppText.h2),
      titleLarge: kn(AppText.h3),
      titleMedium: kn(AppText.title),
      bodyLarge: kn(AppText.body),
      bodyMedium: kn(AppText.body),
      labelLarge: kn(const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      )),
    );
  }

  static ThemeData get light {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      error: AppColors.expense,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textThemeFor(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: LocaleController.instance.isKannada
            ? GoogleFonts.notoSansKannada(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.35,
              )
            : const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13.5,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.expense, width: 1.4),
        ),
        errorStyle: const TextStyle(color: AppColors.expense, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppText.h3,
        contentTextStyle: AppText.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surface,
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: Colors.white,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: Color(0x3317714B),
        selectionHandleColor: AppColors.primary,
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: AppColors.primarySoft.withValues(alpha: 0.4),
    );
  }

  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF57C08A),
      onPrimary: const Color(0xFF042114),
      secondary: AppColors.accent,
      surface: const Color(0xFF101A15),
      onSurface: const Color(0xFFE3EDE7),
      error: AppColors.expense,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0E1612),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF18221D),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF18221D),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF18221D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  Reusable UI primitives                                                     */
/* -------------------------------------------------------------------------- */

class TintedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double boxSize;
  final double radius;
  final Color? backgroundColor;

  const TintedIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 18,
    this.boxSize = 36,
    this.radius = 10,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TintedIcon(icon: icon, color: color, boxSize: 30, size: 16, radius: 9),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(title), style: AppText.title),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(tr(subtitle!), style: AppText.small),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color color;
  final VoidCallback? onTap;
  final bool hasShadow;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 18,
    this.color = AppColors.surface,
    this.onTap,
    this.hasShadow = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: hasShadow ? [AppColors.cardShadow] : null,
      ),
      // Only wrap with InkWell when tappable — a null-onTap InkWell can
      // still compete in the gesture arena and block child buttons.
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;
  final List<Color> colors;
  final double bottomRadius;

  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBack = true,
    this.onBack,
    this.trailing,
    this.colors = AppColors.headerGradient,
    this.bottomRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(bottomRadius),
          bottomRight: Radius.circular(bottomRadius),
        ),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            Material(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(title),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(subtitle),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool centerTitle;

  const GradientAppBar({
    super.key,
    this.title,
    this.actions,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
      title: title == null
          ? null
          : Text(
              tr(title!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
      centerTitle: centerTitle,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.headerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: actions,
    );
  }
}

class AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final FormFieldSetter<String>? onSaved;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final bool required;
  final bool enabled;
  final VoidCallback? onTap;

  const AppField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.required = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Flutter asserts minLines <= maxLines. A 2-line field (Dairy narration)
    // used to pick minLines: 3 whenever maxLines > 1.
    final cap = maxLines < 1 ? 1 : maxLines;
    final fallbackMin = cap > 1 ? (cap < 3 ? cap : 3) : 1;
    final linesMin = (minLines ?? fallbackMin).clamp(1, cap).toInt();
    final multi = cap > 1 || linesMin > 1;
    return TextFormField(
      controller: controller,
      onTap: onTap,
      enabled: enabled,
      keyboardType: multi
          ? TextInputType.multiline
          : keyboardType,
      minLines: linesMin,
      maxLines: cap,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onSaved: onSaved,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: required ? '${tr(label)} *' : tr(label),
        hintText: hint == null ? null : tr(hint!),
        prefixIcon: Icon(icon, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
        alignLabelWithHint: multi,
      ),
    );
  }
}

class AppDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final bool required;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    this.validator,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final selected =
        (value == null || !items.contains(value)) ? null : value;
    return DropdownButtonFormField<String>(
      key: ValueKey('dd-$label-$selected'),
      initialValue: selected,
      onChanged: (v) {
        // Defer so dropdown overlay can close before parent rebuilds
        // (avoids InheritedWidget _dependents.isEmpty crash).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onChanged(v);
        });
      },
      isExpanded: true,
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.isEmpty)
                  ? trf('Please select {0}', [tr(label)])
                  : null
              : null),
      decoration: InputDecoration(
        labelText: required ? '${tr(label)} *' : tr(label),
        prefixIcon: Icon(icon, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
      ),
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      dropdownColor: AppColors.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(tr(e), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final List<Color> gradient;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.height = 54,
    this.gradient = AppColors.buttonGradient,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon!, color: Colors.white, size: 20),
                            const SizedBox(width: 9),
                          ],
                          Text(
                            tr(label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_ios_rounded, size: 17),
        label: Text(tr(label)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.55), width: 1.4),
          backgroundColor: color.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const InfoChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon!, color: color, size: 12), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TintedIcon(icon: icon, color: color, boxSize: 64, size: 30, radius: 20),
            const SizedBox(height: 14),
            Text(title, style: AppText.title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: AppText.small, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
