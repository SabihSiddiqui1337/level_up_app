class ValidationUtils {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    String email = value.trim().toLowerCase();

    // Basic format validation - must have @ and proper structure
    if (!email.contains('@')) {
      return 'Email must contain @ symbol';
    }

    // Split email into local and domain parts
    List<String> parts = email.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email format';
    }

    String localPart = parts[0];
    String domainPart = parts[1];

    // Validate local part (before @)
    if (localPart.isEmpty || localPart.length > 64) {
      return 'Email username is too long or empty';
    }

    // Check for valid characters in local part
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(localPart)) {
      return 'Email username contains invalid characters';
    }

    // Check for consecutive dots or starting/ending with dots
    if (localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..')) {
      return 'Email username format is invalid';
    }

    // Validate domain part (after @)
    if (domainPart.isEmpty || domainPart.length > 253) {
      return 'Email domain is too long or empty';
    }

    // Check for valid domain format
    if (!RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(domainPart)) {
      return 'Email domain contains invalid characters';
    }

    // Check for valid TLD (top-level domain)
    if (!RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(domainPart)) {
      return 'Email must have a valid domain (e.g., .com, .org, .edu)';
    }

    // Check for consecutive dots in domain
    if (domainPart.contains('..')) {
      return 'Email domain format is invalid';
    }

    // Check for valid TLD length (2-63 characters)
    String tld = domainPart.split('.').last;
    if (tld.length < 2 || tld.length > 63) {
      return 'Email domain extension is invalid';
    }

    // Additional comprehensive regex check
    if (!RegExp(
      r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      return 'Please enter a valid email address';
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
