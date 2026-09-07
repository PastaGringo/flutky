import 'package:flutter/material.dart';

const kBackground = Color(0xFF05070A);
const kSurface = Color(0xFF11161E);
const kBorder = Color(0xFF1F2937);
const kAccent = Color(0xFF3BE7B6);
const kText = Color(0xFFE8EDF3);
const kTextMuted = Color(0xFF94A3B8);
const kDanger = Color(0xFFFF6B6B);

final flutkyTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBackground,
  colorScheme: const ColorScheme.dark(
    primary: kAccent,
    onPrimary: Color(0xFF04120E),
    surface: kSurface,
    onSurface: kText,
    error: kDanger,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    titleMedium: TextStyle(fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(height: 1.5, color: kText),
    bodySmall: TextStyle(height: 1.45, color: kTextMuted),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
);

/// Panel used for every boxed block, so the app reads as one surface system.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: child,
      );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kDanger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kDanger.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: kDanger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: kDanger, height: 1.45, fontSize: 14),
              ),
            ),
          ],
        ),
      );
}
