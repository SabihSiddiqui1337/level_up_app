// ignore_for_file: avoid_print, valid_regexps

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/snackbar_utils.dart';
import '../utils/navigation_utils.dart';
import 'login_screen.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 10 digits
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }

    // Format as XXX-XXX-XXXX
    String formatted = '';

    if (digitsOnly.isNotEmpty) {
      // First 3 digits
      if (digitsOnly.length <= 3) {
        formatted = digitsOnly;
      } else if (digitsOnly.length <= 6) {
        formatted = '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3)}';
      } else {
        formatted =
            '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class DateOfBirthFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    
    // Remove all non-digit characters
    String digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 8 digits (MMDDYYYY)
    if (digitsOnly.length > 8) {
      digitsOnly = digitsOnly.substring(0, 8);
    }
    
    // Format as MM/DD/YYYY
    String formatted = '';
    
    if (digitsOnly.isNotEmpty) {
      // Month (2 digits)
      if (digitsOnly.length <= 2) {
        formatted = digitsOnly;
      }
      // Month + Day (up to 4 digits)
      else if (digitsOnly.length <= 4) {
        formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
      }
      // Month + Day + Year (up to 8 digits)
      else {
        formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2, 4)}/${digitsOnly.substring(4)}';
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class HeightFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    
    // Allow digits, decimal point, and apostrophe
    String cleaned = text.replaceAll(RegExp(r"[^\d.'']"), '');
    
    // Count numbers (digits)
    int digitCount = cleaned.replaceAll(RegExp(r'[^\d]'), '').length;
    
    // Limit to 2 digits total
    if (digitCount > 2) {
      // If we're adding a digit, remove the last one
      if (text.length > oldValue.text.length) {
        // Find the last digit and remove it
        String newCleaned = oldValue.text.replaceAll(RegExp(r"[^\d.'']"), '');
        int oldDigitCount = newCleaned.replaceAll(RegExp(r'[^\d]'), '').length;
        if (oldDigitCount >= 2) {
          cleaned = oldValue.text.replaceAll(RegExp(r"[^\d.'']"), '');
        }
      } else {
        cleaned = oldValue.text.replaceAll(RegExp(r"[^\d.'']"), '');
      }
    }
    
    // Auto-format: Convert decimal to apostrophe (6.4 → 6'4)
    if (cleaned.contains('.')) {
      cleaned = cleaned.replaceAll('.', "'");
    }
    
    // Ensure only one apostrophe
    int apostropheCount = cleaned.split("'").length - 1;
    
    if (apostropheCount > 1) {
      cleaned = oldValue.text.replaceAll(RegExp(r'[^\d.\'']'), '');
      if (cleaned.contains('.')) {
        cleaned = cleaned.replaceAll('.', "'");
      }
      // Keep only the first apostrophe
      int firstApostrophe = cleaned.indexOf("'");
      if (firstApostrophe >= 0) {
        cleaned = cleaned.substring(0, firstApostrophe + 1) + 
                 cleaned.substring(firstApostrophe + 1).replaceAll("'", '');
      }
    }
    
    // Auto-format: If 2 digits without separator, format as feet'inches (45 → 4'5, 64 → 6'4)
    String digitsOnly = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length == 2 && !cleaned.contains("'")) {
      cleaned = "${digitsOnly[0]}'${digitsOnly[1]}";
    }
    
    // Limit format: ensure only 1 digit before apostrophe and 1 digit after (6'4 format)
    if (cleaned.contains("'")) {
      List<String> parts = cleaned.split("'");
      if (parts.length == 2) {
        String before = parts[0].replaceAll(RegExp(r'[^\d]'), '');
        String after = parts[1].replaceAll(RegExp(r'[^\d]'), '');
        // Limit before to 1 digit, after to 1 digit
        if (before.length > 1) before = before.substring(0, 1);
        if (after.length > 1) after = after.substring(0, 1);
        cleaned = "$before'$after";
      }
    } else {
      // No separator, limit to 2 digits (will auto-format to feet'inches when 2 digits)
      if (digitsOnly.length > 2) {
        cleaned = digitsOnly.substring(0, 2);
        // Auto-format if we have 2 digits
        if (cleaned.length == 2) {
          cleaned = "${cleaned[0]}'${cleaned[1]}";
        }
      }
    }
    
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  final _jerseyNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _authService.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _dateOfBirthController.dispose();
    _jerseyNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  String _formatDate(DateTime date) {
    // Format as MM/DD/YYYY with leading zeros
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
  }

  DateTime? _parseDate(String dateString) {
    // Parse MM/DD/YYYY format
    final parts = dateString.split('/');
    if (parts.length == 3) {
      try {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 1900) {
          return DateTime(year, month, day);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('SignUp: Attempting to register user');
      print('Email: ${_emailController.text.trim()}');
      print('Username: ${_usernameController.text.trim()}');
      print('Name: ${_nameController.text.trim()}');
      print('Phone: ${_phoneController.text.trim()}');

      await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
        height: _heightController.text.trim().isEmpty ? null : _heightController.text.trim(),
        weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        jerseyNumber: _jerseyNumberController.text.trim().isEmpty ? null : _jerseyNumberController.text.trim(),
      );

      print('SignUp: Registration successful');

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          message: 'Account created successfully!',
        );
        NavigationUtils.pushReplacement(context, const LoginScreen());
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = '';
        String errorString = e.toString();
        
        if (errorString.contains('EMAIL_TAKEN')) {
          errorMessage = 'This email is already taken. Please use a different email address.';
        } else if (errorString.contains('USERNAME_TAKEN')) {
          errorMessage = 'This username is already taken. Please choose a different username.';
        } else if (errorString.contains('PHONE_TAKEN')) {
          errorMessage = 'This phone number is already registered. Please use a different phone number.';
        } else {
          errorMessage = errorString.replaceFirst('Exception: ', '');
          if (errorMessage.contains('already exists')) {
            errorMessage = 'Email is already taken. Please use a different email.';
          } else if (errorMessage.contains('Username is already taken')) {
            errorMessage = 'Username is already taken. Please try again.';
          }
        }
        
        SnackBarUtils.showError(context, message: errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/app_logo.jpg',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Join Level Up Sports',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1976D2),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  'Create your team manager account',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Sign Up Form
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            autocorrect: false,
                            enableSuggestions: true,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(
                                Icons.person,
                                color: const Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              // Clear validation error when user starts typing
                              if (value.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            textCapitalization: TextCapitalization.none,
                            autocorrect: false,
                            enableSuggestions: true,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(
                                Icons.account_circle,
                                color: const Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              // Clear validation error when user starts typing
                              if (value.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            textCapitalization: TextCapitalization.none,
                            autocorrect: false,
                            enableSuggestions: true,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(
                                Icons.email,
                                color: const Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              // Clear validation error when user starts typing
                              if (value.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'xxx-xxx-xxxx',
                              prefixIcon: Icon(
                                Icons.phone,
                                color: const Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                12,
                              ), // XXX-XXX-XXXX = 12 characters
                              PhoneNumberFormatter(), // Custom formatter
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              // Clear validation error when user starts typing
                              if (value.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _heightController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              HeightFormatter(),
                              LengthLimitingTextInputFormatter(4), // Max: 6'4 or 6.2 (4 chars)
                            ],
                            decoration: InputDecoration(
                              labelText: 'Height',
                              hintText: 'e.g., 6.2 or 6\'4',
                              prefixIcon: Icon(
                                Icons.height,
                                color: const Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your height';
                              }
                              // Validate format: allow 6.2 or 6'4 (2 digits max)
                              final cleaned = value.trim().replaceAll("'", '.');
                              final heightValue = double.tryParse(cleaned);
                              if (heightValue == null || heightValue <= 0) {
                                return 'Please enter a valid height (e.g., 6.2 or 6\'4)';
                              }
                              // Check digit count (max 2)
                              final digitCount = value.replaceAll(RegExp(r'[^\d]'), '').length;
                              if (digitCount > 2) {
                                return 'Height can only contain 2 numbers';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3), // Max 3 digits
                            ],
                            decoration: InputDecoration(
                              labelText: 'Weight',
                              hintText: 'e.g., 180 (lbs)',
                              prefixIcon: Icon(
                                Icons.monitor_weight,
                                color: const Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your weight';
                              }
                              final weightValue = double.tryParse(value.trim());
                              if (weightValue == null || weightValue <= 0) {
                                return 'Please enter a valid weight';
                              }
                              // Check digit count (max 3)
                              final digitCount = value.replaceAll(RegExp(r'[^\d]'), '').length;
                              if (digitCount > 3) {
                                return 'Weight can only contain 3 numbers';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dateOfBirthController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              DateOfBirthFormatter(),
                              LengthLimitingTextInputFormatter(10), // MM/DD/YYYY
                            ],
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              hintText: 'MM/DD/YYYY',
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: const Color(0xFF2196F3),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: Color(0xFF2196F3),
                                            onPrimary: Colors.white,
                                            onSurface: Colors.black87,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                          child: child!,
                                        ),
                                      );
                                    },
                                  );
                                  if (picked != null && picked != _selectedDateOfBirth) {
                                    setState(() {
                                      _selectedDateOfBirth = picked;
                                      _dateOfBirthController.text = _formatDate(picked);
                                      // Update validation
                                      _formKey.currentState?.validate();
                                    });
                                  }
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              // Parse the input and update _selectedDateOfBirth
                              if (value.length == 10) { // MM/DD/YYYY format
                                final parsed = _parseDate(value);
                                if (parsed != null) {
                                  setState(() {
                                    _selectedDateOfBirth = parsed;
                                    // Update validation
                                    _formKey.currentState?.validate();
                                  });
                                }
                              } else if (value.isEmpty) {
                                setState(() {
                                  _selectedDateOfBirth = null;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your date of birth';
                              }
                              if (value.length != 10) {
                                return 'Please enter date in MM/DD/YYYY format';
                              }
                              final parsed = _parseDate(value);
                              if (parsed == null) {
                                return 'Please enter a valid date';
                              }
                              if (parsed.isAfter(DateTime.now())) {
                                return 'Date of birth cannot be in the future';
                              }
                              // Check if age is reasonable (not more than 150 years old)
                              final age = _calculateAge(parsed);
                              if (age > 150) {
                                return 'Please enter a valid date of birth';
                              }
                              return null;
                            },
                          ),
                          if (_selectedDateOfBirth != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 16),
                              child: Text(
                                'Age: ${_calculateAge(_selectedDateOfBirth!)} years',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _jerseyNumberController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3), // Max 3 digits
                            ],
                            decoration: InputDecoration(
                              labelText: 'Jersey Number',
                              hintText: 'Enter your jersey number',
                              prefixIcon: Icon(
                                Icons.confirmation_number,
                                color: const Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your jersey number';
                              }
                              final jerseyNum = int.tryParse(value.trim());
                              if (jerseyNum == null || jerseyNum <= 0) {
                                return 'Please enter a valid jersey number';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(
                                Icons.lock,
                                color: const Color(0xFF2196F3),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: const Color(0xFF2196F3),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            obscureText: _obscureConfirmPassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              // Clear validation error when user starts typing
                              if (value.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already have an account? "),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: const Color(0xFF1976D2),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
