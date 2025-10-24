// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailVerified = false;
  String _verificationCode = '';
  int _resendCountdown = 0;
  Timer? _resendTimer;
  bool _isProcessing = false; // Add flag to prevent rapid clicks

  @override
  void initState() {
    super.initState();
    _authService.initialize();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),

                  // Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      size: 50,
                      color: Color(0xFF2196F3),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Title
                  Text(
                    'Forgot Password?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2196F3),
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _emailVerified
                        ? 'Enter the verification code sent to your email'
                        : 'Enter your email address to reset your password',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  if (!_emailVerified) ...[
                    // Email Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email Address',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: const Color(0xFF2196F3),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email address';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _formKey.currentState?.validate();
                        },
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            (_isLoading || _isProcessing) ? null : _verifyEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF2196F3).withOpacity(0.3),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'Send Verification Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ] else ...[
                    // Code Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _codeController,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Code',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            letterSpacing: 0,
                          ),
                          prefixIcon: Icon(
                            Icons.security,
                            color: const Color(0xFF2196F3),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the verification code';
                          }
                          if (value != _verificationCode) {
                            return 'Invalid verification code';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _formKey.currentState?.validate();
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Resend Code Button
                    TextButton(
                      onPressed: _resendCountdown > 0 ? null : _resendCode,
                      child: Text(
                        _resendCountdown > 0
                            ? 'Resend Code in ${_resendCountdown}s'
                            : 'Resend Code',
                        style: TextStyle(
                          color:
                              _resendCountdown > 0
                                  ? Colors.grey[400]
                                  : const Color(0xFF2196F3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Verify Code Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38A169),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF38A169).withOpacity(0.3),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'Verify Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Back to Login Button
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Back to Login',
                      style: TextStyle(
                        color: const Color(0xFF2196F3),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verifyEmail() async {
    if (!_formKey.currentState!.validate()) return;

    // Prevent multiple rapid clicks
    if (_isProcessing) return;

    setState(() {
      _isLoading = true;
      _isProcessing = true;
    });

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Check if email exists in database
      final emailExists = await _authService.checkEmailExists(
        _emailController.text.trim(),
      );

      if (emailExists) {
        // Generate a simple verification code (in real app, this would be sent via email)
        _verificationCode = _generateVerificationCode();

        setState(() {
          _emailVerified = true;
          _isLoading = false;
          _isProcessing = false;
        });

        // Start the resend countdown timer
        _startResendCountdown();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification code sent to ${_emailController.text.trim()}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF38A169),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'The email address entered wasn\'t found in the database! Please check that you entered the correct email',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFE53E3E),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Add delay before allowing another attempt
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFE53E3E),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      if (_codeController.text.trim() == _verificationCode) {
        // Code is correct - show success and navigate back to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Password reset successful! You can now log in with your new password.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF38A169),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Navigate back to login screen
        Navigator.pop(context);
      } else {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Invalid verification code. Please try again.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFE53E3E),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFE53E3E),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _resendCode() {
    // Immediately disable the button and start countdown
    _startResendCountdown();

    _verificationCode = _generateVerificationCode();
    _codeController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'New verification code sent to ${_emailController.text.trim()}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF38A169),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _startResendCountdown() {
    _resendTimer?.cancel(); // Cancel any existing timer
    _resendCountdown = 15; // Start with 15 seconds

    // Immediately update the UI to disable the button
    setState(() {});

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCountdown--;
      });

      if (_resendCountdown <= 0) {
        timer.cancel();
      }
    });
  }

  String _generateVerificationCode() {
    // Generate a 6-digit verification code
    return (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
        .toString();
  }
}
