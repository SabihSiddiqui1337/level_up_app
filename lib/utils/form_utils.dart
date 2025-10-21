import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FormUtils {
  // Common form field builder
  static Widget buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    bool obscureText = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      onChanged: onChanged,
      obscureText: obscureText,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.black54,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF2196F3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        counterText: maxLength != null ? '' : null,
      ),
    );
  }

  // Phone number field with formatting
  static Widget buildPhoneField({
    required TextEditingController controller,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return buildFormField(
      controller: controller,
      label: 'Phone Number',
      icon: Icons.phone,
      keyboardType: TextInputType.phone,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
        PhoneNumberFormatter(),
      ],
    );
  }

  // Email field
  static Widget buildEmailField({
    required TextEditingController controller,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return buildFormField(
      controller: controller,
      label: 'Email',
      icon: Icons.email,
      keyboardType: TextInputType.emailAddress,
      validator: validator,
      onChanged: onChanged,
    );
  }

  // Password field
  static Widget buildPasswordField({
    required TextEditingController controller,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    bool obscureText = true,
  }) {
    return buildFormField(
      controller: controller,
      label: 'Password',
      icon: Icons.lock,
      keyboardType: TextInputType.visiblePassword,
      validator: validator,
      onChanged: onChanged,
      obscureText: obscureText,
    );
  }

  // Name field with word capitalization
  static Widget buildNameField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return buildFormField(
      controller: controller,
      label: label,
      icon: Icons.person,
      validator: validator,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.words,
    );
  }
}

// Phone number formatter
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length <= 3) {
      return newValue;
    } else if (text.length <= 6) {
      return TextEditingValue(
        text: '${text.substring(0, 3)}-${text.substring(3)}',
        selection: TextSelection.collapsed(offset: text.length + 1),
      );
    } else {
      return TextEditingValue(
        text:
            '${text.substring(0, 3)}-${text.substring(3, 6)}-${text.substring(6, text.length > 10 ? 10 : text.length)}',
        selection: TextSelection.collapsed(offset: text.length + 2),
      );
    }
  }
}
