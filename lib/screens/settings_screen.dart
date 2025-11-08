// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';
import 'team_registration_screen.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const SettingsScreen({super.key, this.onHomePressed});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Person Information
            _buildSettingsCard([
              _buildSettingsItem(
                'Person Information',
                Icons.person,
                () {
                  _navigateToProfile();
                },
                trailing: Icons.keyboard_arrow_right,
              ),
            ]),

            const SizedBox(height: 16),

            // App Feedback
            _buildSettingsCard([
              _buildSettingsItem('App Feedback', Icons.feedback, () {
                _navigateToAppFeedback();
              }, trailing: Icons.keyboard_arrow_right),
            ]),

            const SizedBox(height: 16),

            // About
            _buildSettingsCard([
              _buildSettingsItem('About', Icons.info, () {
                _navigateToAbout();
              }, trailing: Icons.keyboard_arrow_right),
            ]),

            const SizedBox(height: 32),

            // App Version (auto from UpdateService)
            Center(
              child: FutureBuilder(
                future: Future.wait([
                  UpdateService.getCurrentVersion(),
                  UpdateService.getBuildNumber(),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      'v—',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    );
                  }
                  final data = snapshot.data as List<String>;
                  final version = data[0];
                  final build = data[1];
                  return Text(
                    'v$version + $build',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    IconData? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        trailing ?? Icons.keyboard_arrow_right,
        color: Colors.grey[400],
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
    );
    // Refresh the screen when returning from profile edit
    setState(() {});
  }

  void _navigateToAppFeedback() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('App Feedback'),
            content: const Text('Coming soon'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _navigateToAbout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About'),
            content: const Text('Coming soon'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _authService.logout();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = _authService.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update profile using AuthService
      final success = await _authService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile Information'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF2196F3),
                      radius: 40,
                      child: Text(
                        _nameController.text.isNotEmpty
                            ? _nameController.text.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text
                          : 'User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _emailController.text.isNotEmpty
                          ? _emailController.text
                          : 'user@example.com',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form Fields
              _buildFormField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildFormField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildPhoneField(),

              const SizedBox(height: 32),

              // Update Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Update Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 12, // 10 digits + 2 dashes
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10), // Only allow 10 digits
        PhoneNumberFormatter(), // Custom formatter
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your phone number';
        }
        // Remove dashes for validation
        final digitsOnly = value.replaceAll('-', '');
        if (digitsOnly.length != 10) {
          return 'Enter 10-digit number';
        }
        return null;
      },
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: 'XXX-XXX-XXXX',
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
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
        filled: true,
        fillColor: Colors.white,
        counterText: '', // Hide character counter
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: true,
      validator: validator,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
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
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

class AppFeedbackScreen extends StatefulWidget {
  const AppFeedbackScreen({super.key});

  @override
  State<AppFeedbackScreen> createState() => _AppFeedbackScreenState();
}

class _AppFeedbackScreenState extends State<AppFeedbackScreen> {
  final _feedbackController = TextEditingController();
  final _authService = AuthService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter your feedback',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
          elevation: 4,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user info
      final currentUser = _authService.currentUser;
      final userName = currentUser?.name ?? 'Anonymous User';
      final userEmail = currentUser?.email ?? 'No email provided';

      // Create email content
      final emailBody = '''
App Feedback from Level Up Sports App

User Information:
- Name: $userName
- Email: $userEmail
- User ID: ${currentUser?.id ?? 'N/A'}

Feedback:
${_feedbackController.text.trim()}

---
Sent from Level Up Sports App
Time: ${DateTime.now().toString()}
''';

      // Show options dialog first (iOS workaround)
      _showEmailOptionsDialog(emailBody);
    } catch (e) {
      print('DEBUG: Error preparing email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error preparing email: $e',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
            elevation: 4,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showEmailOptionsDialog(String emailBody) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Feedback'),
          content: const Text(
            'Choose how you\'d like to send your feedback:',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _feedbackController.clear();
                Navigator.pop(context); // Go back to settings
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _tryLaunchEmailClient(emailBody);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Email App'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showFallbackDialog(emailBody);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Copy Content'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _tryLaunchEmailClient(String emailBody) async {
    try {
      // Get current user info
      final currentUser = _authService.currentUser;
      final userName = currentUser?.name ?? 'Anonymous User';

      // Create mailto URL
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'levelupsports96@gmail.com',
        query:
            'subject=${Uri.encodeComponent('App Feedback from $userName')}&body=${Uri.encodeComponent(emailBody)}',
      );

      // Try to launch email client with better error handling
      print('DEBUG: Attempting to launch email URI: $emailUri');

      try {
        // First try to launch directly without checking canLaunchUrl (iOS issue workaround)
        final launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          print('DEBUG: Email client launched successfully');
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Email client opened. Please send the email to submit your feedback.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                elevation: 4,
              ),
            );

            // Clear form and navigate back
            _feedbackController.clear();
            Navigator.pop(context);
          }
        } else {
          throw Exception('Failed to launch email client');
        }
      } catch (e) {
        print('DEBUG: Direct launch failed: $e');
        // If direct launch fails, try with canLaunchUrl check
        try {
          if (await canLaunchUrl(emailUri)) {
            final launched = await launchUrl(
              emailUri,
              mode: LaunchMode.externalApplication,
            );
            if (launched) {
              print('DEBUG: Email client launched successfully after retry');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Email client opened. Please send the email to submit your feedback.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 100,
                    ),
                    elevation: 4,
                  ),
                );

                _feedbackController.clear();
                Navigator.pop(context);
              }
            } else {
              throw Exception('Failed to launch email client after retry');
            }
          } else {
            throw Exception('No email client available on this device');
          }
        } catch (e2) {
          print('DEBUG: Both launch attempts failed: $e2');
          rethrow; // Re-throw to trigger fallback dialog
        }
      }
    } catch (e) {
      print('DEBUG: Error launching email client: $e');
      if (mounted) {
        // Show fallback dialog with email content
        _showFallbackDialog(emailBody);
      }
    }
  }

  void _showFallbackDialog(String emailBody) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Client Not Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please copy the following information and send it to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'levelupsports96@gmail.com',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Email Content:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  emailBody,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _feedbackController.clear();
                Navigator.pop(context); // Go back to settings
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // Copy to clipboard
                Clipboard.setData(ClipboardData(text: emailBody));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email content copied to clipboard!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.of(context).pop();
                _feedbackController.clear();
                Navigator.pop(context); // Go back to settings
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Copy & Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('App Feedback'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summarize your feedback for the Level Up Sports App',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _feedbackController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Enter your feedback here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child:
                    _isSubmitting
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Submitting...'),
                          ],
                        )
                        : const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // App Icon
            Center(
              child: Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/app_logo.jpg',
                    width: 85,
                    height: 85,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Version
            Center(
              child: FutureBuilder(
                future: Future.wait([
                  UpdateService.getCurrentVersion(),
                  UpdateService.getBuildNumber(),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      'Version: v—',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    );
                  }
                  final data = snapshot.data as List<String>;
                  final version = data[0];
                  final build = data[1];
                  return Text(
                    'Version: v$version + $build',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),

            // Rate Us as a settings row
            _buildSettingsCard([
              _buildSettingsItem('Rate Us', Icons.star, () {
                // Handle rate us functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for rating our app!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }, trailing: Icons.keyboard_arrow_right),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    IconData? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        trailing ?? Icons.keyboard_arrow_right,
        color: Colors.grey[400],
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
