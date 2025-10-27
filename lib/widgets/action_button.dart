import 'package:flutter/material.dart';

/// Reusable action button with consistent styling
class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final bool isExpanded;

  const ActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.isExpanded = true,
  });

  const ActionButton.compact({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? const Color(0xFF2196F3),
        foregroundColor: foregroundColor ?? Colors.white,
        padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    if (isExpanded) {
      return Expanded(child: button);
    }

    return button;
  }
}

/// Specialized button styles for common actions
class ActionButtonStyles {
  static Color get primary => const Color(0xFF2196F3);
  static Color get green => Colors.green;
  static Color get grey => Colors.grey[400]!;
  static Color get grey700 => Colors.grey[700]!;
  static Color get red => Colors.red[400]!;
}

/// Helper class for building consistent button combinations
class ActionButtonRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ActionButtonRow({super.key, required this.children, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          children.expand((child) {
            final index = children.indexOf(child);
            return index > 0 ? [SizedBox(width: spacing), child] : [child];
          }).toList(),
    );
  }
}
