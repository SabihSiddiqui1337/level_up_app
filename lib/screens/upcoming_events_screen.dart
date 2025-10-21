// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_app_bar.dart';
import 'main_navigation_screen.dart';

class UpcomingEventsScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const UpcomingEventsScreen({super.key, this.onHomePressed});

  @override
  State<UpcomingEventsScreen> createState() => _UpcomingEventsScreenState();
}

class _UpcomingEventsScreenState extends State<UpcomingEventsScreen> {
  bool _isCopying = false; // Add flag to prevent rapid copying

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
            child: SafeArea(
              child: Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Upcoming Events',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE67E22),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // Events List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildSimpleEventCard(
                          'BasketBall Tournament 2025',
                          'Sat. Nov. 8. 2025',
                          'Masjid Istiqlal',
                          '123 Main Street,\nSugar Land, TX\n77498',
                        ),
                        const SizedBox(height: 16),
                        _buildSimpleEventCard(
                          'Thanksgiving Picketball Tournament',
                          'Sat. Nov. 22. 2025',
                          'Masjid Istiqlal',
                          '123 Main Street,\nSugar Land, TX\n77498',
                        ),
                      ],
                    ),
                  ),

                  // Registration Cart
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildSimpleEventCard(
    String title,
    String date,
    String location,
    String address,
  ) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey[50]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              // Date with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF2196F3),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      date,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Location with icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE67E22).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFE67E22),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap:
                                  _isCopying
                                      ? null
                                      : () => _copyToClipboard(address),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2196F3,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.copy,
                                  size: 16,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    const MainNavigationScreen(initialIndex: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.app_registration, size: 18),
                      label: const Text('REGISTER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE67E22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Show details dialog or navigate to details screen
                        _showEventDetails(title, date, location, address);
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('DETAILS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetails(
    String title,
    String date,
    String location,
    String address,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.calendar_today, 'Date', date),
              const SizedBox(height: 12),
              _buildDetailRowWithAddress(
                Icons.location_on,
                'Location',
                location,
                address,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            const MainNavigationScreen(initialIndex: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                foregroundColor: Colors.white,
              ),
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2196F3)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRowWithAddress(
    IconData icon,
    String label,
    String location,
    String address,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2196F3)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isCopying ? null : () => _copyToClipboard(address),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) async {
    if (_isCopying) return; // Prevent rapid clicking

    setState(() {
      _isCopying = true;
    });

    // Convert multi-line address to single line for copying
    final singleLineText = text.replaceAll('\n', ' ');
    await Clipboard.setData(ClipboardData(text: singleLineText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Address copied to clipboard!',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF38A169),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Add delay before allowing another copy
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isCopying = false;
    });
  }
}
