import 'package:flutter/material.dart';

class SnackBarUtils {
  /// Show a snackbar with proper positioning and auto-cleanup
  static void showSnackbar(
    BuildContext context, {
    required String message,
    Color backgroundColor = Colors.green,
    Duration duration = const Duration(seconds: 4),
    bool hideOnNavigation = true,
  }) {
    // Hide any existing snackbar first
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 100, // Position above bottom navigation
        ),
        elevation: 4,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showSnackbar(
      context,
      message: message,
      backgroundColor: Colors.green,
      duration: duration,
    );
  }

  /// Show error snackbar
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 5),
  }) {
    showSnackbar(
      context,
      message: message,
      backgroundColor: Colors.red,
      duration: duration,
    );
  }

  /// Show warning snackbar
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showSnackbar(
      context,
      message: message,
      backgroundColor: Colors.orange,
      duration: duration,
    );
  }

  /// Hide current snackbar
  static void hideCurrent(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Navigate with snackbar cleanup
  static void navigateWithCleanup(
    BuildContext context,
    Widget destination, {
    bool clearStack = false,
  }) {
    // Hide any current snackbar before navigating
    hideCurrent(context);

    if (clearStack) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => destination),
        (route) => false,
      );
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => destination));
    }
  }

  /// Pop with snackbar cleanup
  static void popWithCleanup(BuildContext context) {
    // Hide any current snackbar before popping
    hideCurrent(context);
    Navigator.of(context).pop();
  }
}
