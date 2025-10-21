class ValidationUtils {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName';
    }
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Username validation
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your username';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  // Phone number validation
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }
    final phoneRegex = RegExp(r'^\d{3}-\d{3}-\d{4}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number (XXX-XXX-XXXX)';
    }
    return null;
  }

  // Team name validation
  static String? validateTeamName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter team name';
    }
    if (value.trim().length > 30) {
      return 'Team name must be 30 characters or less';
    }
    return null;
  }

  // Player name validation
  static String? validatePlayerName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter player name';
    }
    return null;
  }

  // Age validation
  static String? validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter age';
    }
    final age = int.tryParse(value.trim());
    if (age == null) {
      return 'Please enter a valid age';
    }
    return null;
  }

  // Discount code validation
  static String? validateDiscountCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter discount code';
    }
    return null;
  }

  // Generic length validation
  static String? validateLength(
    String? value,
    int minLength,
    int maxLength,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    if (value.trim().length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (value.trim().length > maxLength) {
      return '$fieldName must be $maxLength characters or less';
    }
    return null;
  }
}
