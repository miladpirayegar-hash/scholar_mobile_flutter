import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFFF385C);
  static const primarySoft = Color(0xFFFFF1F2);
  static const text = Color(0xFF222222);
  static const subtext = Color(0xFF222222);
  static const muted = Color(0xFF222222);
  static const line = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF7F7F7);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(
      base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    ).copyWith(
      titleLarge: GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.subtext,
      ),
    );

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.text,
        surface: Colors.white,
      ),
      canvasColor: Colors.white,
      iconTheme: const IconThemeData(
        color: AppColors.text,
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.manrope(
          color: AppColors.subtext,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerColor: AppColors.line,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primarySoft;
          }
          return AppColors.line;
        }),
      ),
    );
  }

  static ThemeData datePickerTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.text,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        headerBackgroundColor: AppColors.surface,
        headerForegroundColor: AppColors.text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line),
        ),
      ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
    );
  }
}

class AppModal {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ModalShell(child: builder(ctx));
      },
    );
  }
}

class _ModalShell extends StatelessWidget {
  final Widget child;

  const _ModalShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      color: Colors.black54,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 60,
          bottom: bottom + 16,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: child,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showEditModal({
  required BuildContext context,
  required String title,
  required String initialValue,
  required String hintText,
  required String saveLabel,
  required ValueChanged<String> onSave,
}) async {
  final controller = TextEditingController(text: initialValue);
  await AppModal.show<void>(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                onSave(controller.text.trim());
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.text,
              ),
              child: Text(saveLabel),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showDeleteConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required VoidCallback onConfirm,
}) async {
  await AppModal.show<void>(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.subtext,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
              child: const Text('Confirm'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      );
    },
  );
}
