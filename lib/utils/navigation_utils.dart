import 'package:flutter/material.dart';

class NavigationUtils {
  // Navigate to screen with replacement
  static Future<T?> pushReplacement<T extends Object?>(
    BuildContext context,
    Widget screen, {
    String? routeName,
  }) {
    return Navigator.pushReplacement(
      context,
      MaterialPageRoute<T>(
        builder: (context) => screen,
        settings: routeName != null ? RouteSettings(name: routeName) : null,
      ),
    );
  }

  // Navigate to screen
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget screen, {
    String? routeName,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute<T>(
        builder: (context) => screen,
        settings: routeName != null ? RouteSettings(name: routeName) : null,
      ),
    );
  }

  // Navigate and remove all previous routes
  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    Widget screen, {
    String? routeName,
    bool Function(Route<dynamic>)? predicate,
  }) {
    return Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<T>(
        builder: (context) => screen,
        settings: routeName != null ? RouteSettings(name: routeName) : null,
      ),
      predicate ?? (route) => false,
    );
  }

  // Pop current screen
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.pop(context, result);
  }

  // Pop until condition
  static void popUntil(
    BuildContext context,
    bool Function(Route<dynamic>) predicate,
  ) {
    Navigator.popUntil(context, predicate);
  }

  // Pop to root
  static void popToRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // Pop to specific route
  static void popToRoute(BuildContext context, String routeName) {
    Navigator.popUntil(context, (route) {
      return route.settings.name == routeName || route.isFirst;
    });
  }

  // Show confirmation dialog
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
    Color? confirmColor,
    Color? cancelColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: cancelColor ?? Colors.grey[600],
                ),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: confirmColor ?? const Color(0xFF2196F3),
                ),
                child: Text(confirmText),
              ),
            ],
          ),
    );
  }

  // Show info dialog
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onPressed?.call();
                },
                child: Text(buttonText),
              ),
            ],
          ),
    );
  }

  // Show error dialog
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              title,
              style: const TextStyle(color: Color(0xFFE53E3E)),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onPressed?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE53E3E),
                ),
                child: Text(buttonText),
              ),
            ],
          ),
    );
  }

  // Show success dialog
  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              title,
              style: const TextStyle(color: Color(0xFF38A169)),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onPressed?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF38A169),
                ),
                child: Text(buttonText),
              ),
            ],
          ),
    );
  }
}
