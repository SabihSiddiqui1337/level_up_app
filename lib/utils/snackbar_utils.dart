import 'package:flutter/material.dart';

class SnackBarUtils {
  // Success snackbar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF38A169),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Error snackbar
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53E3E),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Warning snackbar
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE67E22),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Info snackbar
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2196F3),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Custom snackbar
  static void showCustom(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? const Color(0xFF2196F3),
        duration: duration ?? const Duration(seconds: 3),
        action: action,
      ),
    );
  }

  // Clear all snackbars
  static void clearAll(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
}
