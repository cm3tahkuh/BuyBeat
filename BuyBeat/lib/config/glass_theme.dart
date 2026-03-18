import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─── Liquid Glass Design System ───────────────────────────────────────────
/// Inspired by Apple's Liquid Glass (iOS 26) aesthetic.
/// Frosted panels, soft gradients, translucent layers, Inter font.

class LG {
  LG._();

  // ─── Background ────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0A0A0F);
  static const Color bgLight = Color(0xFF141418);

  // ─── Glass panel fills ─────────────────────────────────────────────
  static Color panelFill = Colors.white.withValues(alpha: 0.05);
  static Color panelFillLight = Colors.white.withValues(alpha: 0.08);
  static Color panelFillAccent = const Color(0xFFCDFF00).withValues(alpha: 0.06);

  // ─── Borders ───────────────────────────────────────────────────────
  static Color border = Colors.white.withValues(alpha: 0.08);
  static Color borderLight = Colors.white.withValues(alpha: 0.14);
  static Color borderAccent = const Color(0xFFCDFF00).withValues(alpha: 0.25);

  // ─── Accent colors ────────────────────────────────────────────────
  static const Color accent = Color(0xFFCDFF00);        // lime green
  static const Color accentLight = Color(0xFFE0FF66);    // light lime
  static const Color cyan = Color(0xFF4FC3F7);           // light blue
  static const Color blue = Color(0xFF5B8DEF);           // blue
  static const Color pink = Color(0xFFF78FB3);           // soft pink
  static const Color green = Color(0xFF4ADE80);          // emerald
  static const Color orange = Color(0xFFFDAA5E);         // warm orange
  static const Color red = Color(0xFFFF6B6B);            // soft red

  // ─── Good text ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF5B5F6B);

  // ─── Gradients ─────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A0A0F), Color(0xFF101015), Color(0xFF0A0A0F)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFCDFF00), Color(0xFF9ACD32)],
  );

  static const LinearGradient accentGradientV = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFCDFF00), Color(0xFF9ACD32)],
  );

  static const LinearGradient cardShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x0DFFFFFF), Color(0x03FFFFFF)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF161618), Color(0xFF0A0A0F)],
  );

  // ─── Blur values ───────────────────────────────────────────────────
  static const double blurLight = 6;
  static const double blurMedium = 12;
  static const double blurHeavy = 18;

  // ─── Radii ─────────────────────────────────────────────────────────
  static const double radiusS = 12;
  static const double radiusM = 16;
  static const double radiusL = 20;
  static const double radiusXL = 28;

  // ─── FONTS ─────────────────────────────────────────────────────────
  //
  // Inter is configured to closely mimic Apple SF Pro / Helvetica Neue:
  //  • cv05 — single-story lowercase 'a'   (Helvetica / SF hallmark)
  //  • cv08 — single-story lowercase 'g'   (Helvetica / SF hallmark)
  //  • kern  — optical kerning
  //  • calt  — contextual alternates (ligatures/joins)
  //  • liga  — standard ligatures
  // Letter-spacing follows Apple's SF Pro tracking curve:
  //   large titles negative, body slightly negative, captions near zero.

  static const List<FontFeature> _sfFeatures = [
    FontFeature('cv05'), // single-story 'a'
    FontFeature('cv08'), // single-story 'g'
    FontFeature('kern', 1),
    FontFeature('calt', 1),
    FontFeature('liga', 1),
  ];

  /// SF Pro / Helvetica-like tracking (letter-spacing in logical pixels)
  static double _sfTracking(double size) {
    if (size >= 34) return -0.80;
    if (size >= 28) return -0.60;
    if (size >= 22) return -0.40;
    if (size >= 18) return -0.25;
    if (size >= 16) return -0.20;
    if (size >= 14) return -0.15;
    if (size >= 12) return -0.08;
    return 0.07; // caption-size — slightly open, like SF Caption
  }

  /// SF Pro / Helvetica-like line height
  static double _sfHeight(double size) {
    if (size >= 22) return 1.18;
    if (size >= 16) return 1.30;
    return 1.45;
  }

  static TextStyle font({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? _sfHeight(size),
      letterSpacing: letterSpacing ?? _sfTracking(size),
      decoration: decoration,
      fontFeatures: fontFeatures ?? _sfFeatures,
    );
  }

  static TextStyle h1 = GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary,
    letterSpacing: -0.72, height: 1.15, fontFeatures: _sfFeatures,
  );
  static TextStyle h2 = GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary,
    letterSpacing: -0.45, height: 1.20, fontFeatures: _sfFeatures,
  );
  static TextStyle h3 = GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
    letterSpacing: -0.25, height: 1.25, fontFeatures: _sfFeatures,
  );
  static TextStyle body = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary,
    letterSpacing: -0.15, height: 1.45, fontFeatures: _sfFeatures,
  );
  static TextStyle bodyS = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary,
    letterSpacing: -0.10, height: 1.45, fontFeatures: _sfFeatures,
  );
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500, color: textMuted,
    letterSpacing: 0.07, height: 1.45, fontFeatures: _sfFeatures,
  );
  static TextStyle label = GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary,
    letterSpacing: -0.04, height: 1.40, fontFeatures: _sfFeatures,
  );
  static TextStyle button = GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary,
    letterSpacing: -0.18, height: 1.30, fontFeatures: _sfFeatures,
  );

  // ─── Theme Data ────────────────────────────────────────────────────
  static ThemeData themeData() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: cyan,
        surface: bgLight,
        error: red,
        onPrimary: Color(0xFF0A0A0F),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        // Apply SF-like tracking & features to the base Material text theme
        displayLarge: GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.w300, color: textPrimary, letterSpacing: -0.80, height: 1.12, fontFeatures: _sfFeatures),
        displayMedium: GoogleFonts.inter(fontSize: 45, fontWeight: FontWeight.w300, color: textPrimary, letterSpacing: -0.60, height: 1.15, fontFeatures: _sfFeatures),
        displaySmall: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w400, color: textPrimary, letterSpacing: -0.50, height: 1.18, fontFeatures: _sfFeatures),
        headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.72, height: 1.20, fontFeatures: _sfFeatures),
        headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.45, height: 1.22, fontFeatures: _sfFeatures),
        headlineSmall: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.30, height: 1.25, fontFeatures: _sfFeatures),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.25, height: 1.28, fontFeatures: _sfFeatures),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary, letterSpacing: -0.20, height: 1.35, fontFeatures: _sfFeatures),
        titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary, letterSpacing: -0.15, height: 1.40, fontFeatures: _sfFeatures),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary, letterSpacing: -0.20, height: 1.50, fontFeatures: _sfFeatures),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary, letterSpacing: -0.15, height: 1.45, fontFeatures: _sfFeatures),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary, letterSpacing: -0.08, height: 1.45, fontFeatures: _sfFeatures),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary, letterSpacing: -0.15, height: 1.40, fontFeatures: _sfFeatures),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary, letterSpacing: -0.04, height: 1.40, fontFeatures: _sfFeatures),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted, letterSpacing: 0.07, height: 1.45, fontFeatures: _sfFeatures),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.25,
          height: 1.28,
          fontFeatures: _sfFeatures,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.07, fontFeatures: _sfFeatures),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.07, fontFeatures: _sfFeatures),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelFill,
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14, letterSpacing: -0.15, fontFeatures: _sfFeatures),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14, letterSpacing: -0.15, fontFeatures: _sfFeatures),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF0A0A0F),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.18, fontFeatures: _sfFeatures),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: accent,
        labelColor: textPrimary,
        unselectedLabelColor: textMuted,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.10, fontFeatures: _sfFeatures),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, letterSpacing: -0.10, fontFeatures: _sfFeatures),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgLight,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 14, letterSpacing: -0.15, fontFeatures: _sfFeatures),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── REUSABLE GLASS WIDGETS ────────────────────────────────────────────────

/// Full-screen background with gradient + optional decorative blobs
class GlassScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool showBlobs;

  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.showBlobs = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: LG.bg,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          // Gradient background
          Container(decoration: const BoxDecoration(gradient: LG.bgGradient)),
          // Decorative blobs
          if (showBlobs) ...[
            Positioned(
              top: -80,
              right: -60,
              child: _blob(160, LG.accent.withValues(alpha: 0.08)),
            ),
            Positioned(
              bottom: 100,
              left: -40,
              child: _blob(120, LG.cyan.withValues(alpha: 0.06)),
            ),
          ],
          // Body
          body,
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

/// Frosted glass panel (card/container)
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final double blur;
  final Color? fill;
  final Color? borderColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 0,
    this.fill,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fill ?? LG.panelFill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? LG.border, width: 0.5),
      ),
      child: child,
    );
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: blur > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: decorated,
              )
            : decorated,
      ),
    );
  }
}

/// Glass AppBar
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const GlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(bottom != null ? 96 : 56);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.03),
          elevation: 0,
          leading: leading ?? (showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => Navigator.pop(context),
                )
              : null),
          title: titleWidget ?? (title != null ? Text(title!, style: LG.h3) : null),
          actions: actions,
          bottom: bottom,
        ),
      ),
    );
  }
}

/// Gradient accent button
class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const GlassButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.icon,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: onTap != null && !isLoading ? LG.accentGradient : null,
          color: onTap == null || isLoading ? LG.textMuted.withValues(alpha: 0.3) : null,
          borderRadius: BorderRadius.circular(LG.radiusM),
          boxShadow: onTap != null && !isLoading
              ? [BoxShadow(color: LG.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0A0F)))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[  
                      Icon(icon, color: const Color(0xFF0A0A0F), size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(text, style: LG.button.copyWith(color: const Color(0xFF0A0A0F))),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Glass input field
class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const GlassTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: LG.font(size: 14, color: LG.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: LG.textMuted, size: 20)
            : null,
      ),
    );
  }
}

/// Chip with glass effect
class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  const GlassChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? LG.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : LG.panelFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.withValues(alpha: 0.5) : LG.border,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? c : LG.textMuted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: LG.font(
                size: 12,
                weight: FontWeight.w600,
                color: selected ? c : LG.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
