import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pickleball_team.dart';
import '../models/event.dart';
import '../services/pickleball_team_service.dart';
import 'payment_screen.dart';
import 'main_navigation_screen.dart';

class PickleballProcessRegistrationScreen extends StatefulWidget {
  final PickleballTeam team;
  final Event event;

  const PickleballProcessRegistrationScreen({
    super.key,
    required this.team,
    required this.event,
  });

  @override
  State<PickleballProcessRegistrationScreen> createState() =>
      _PickleballProcessRegistrationScreenState();
}

class _PickleballProcessRegistrationScreenState
    extends State<PickleballProcessRegistrationScreen> {
  final _discountCodeController = TextEditingController();

  // Get registration fee from event, or default to 250.0
  double get _registrationFee => widget.event.amount ?? 250.0;
  bool get _isFreeEvent => widget.event.amount == null || widget.event.amount == 0;
  
  bool _discountApplied = false;
  double _discountPercentage = 0.0;
  double _discountAmount = 0.0;
  String _appliedDiscountCode = '';
  bool _isProcessingDiscount = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _discountCodeController.addListener(_onDiscountCodeChanged);
  }

  @override
  void dispose() {
    _discountCodeController.removeListener(_onDiscountCodeChanged);
    _discountCodeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _onDiscountCodeChanged() {
    // Handle discount code changes if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Process Pickleball Registration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF38A169),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E8), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 50),

                // Team Information Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.sports_tennis,
                                color: Color(0xFF38A169),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Team Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF38A169),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Team Name
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Team: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(
                                  text: widget.team.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Team Captain Information
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Team Captain: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(
                                  text: widget.team.coachName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Phone: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(
                                  text: widget.team.coachPhone,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Email: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(
                                  text: widget.team.coachEmail,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Division Information
                          Text(
                            'DUPR Rating: ${widget.team.division}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF38A169),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Players List
                          Text(
                            'Players (${widget.team.players.length}):',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.team.players.isEmpty)
                            const Text(
                              'No players registered',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            ...widget.team.players.map(
                              (player) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Color(0xFF38A169),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      player.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Event Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.event,
                                color: Color(0xFF38A169),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.event.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF38A169),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Date: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(
                                  text: _formatFullDate(widget.event.date),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Location: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(
                                  text: widget.event.locationName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.event.locationAddress,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Payment Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.payment,
                                color: Color(0xFF38A169),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Payment Summary',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF38A169),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Event and Team info
                          _buildPaymentRow('Event', widget.event.title, false),
                          const SizedBox(height: 4),
                          _buildPaymentRow('Team', widget.team.name, false),
                          const SizedBox(height: 16),

                          // Discount Code Section (only show if not free event)
                          if (!_isFreeEvent) ...[
                            Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Discount Code (Optional)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _discountCodeController,
                                        decoration: InputDecoration(
                                          hintText: 'Enter discount code',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed:
                                          _isProcessingDiscount ||
                                                  _cooldownSeconds > 0
                                              ? null
                                              : _applyDiscount,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF38A169,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child:
                                          _isProcessingDiscount
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                              : Text(
                                                _cooldownSeconds > 0
                                                    ? '$_cooldownSeconds'
                                                    : 'Apply',
                                              ),
                                    ),
                                  ],
                                ),
                                if (_discountApplied) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF38A169,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF38A169),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Discount applied: $_appliedDiscountCode (${_discountPercentage.toInt()}% off)',
                                          style: const TextStyle(
                                            color: Color(0xFF38A169),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Payment Breakdown
                          if (_isFreeEvent) ...[
                            _buildPaymentRow(
                              'Total',
                              'Free',
                              true,
                            ),
                          ] else ...[
                            _buildPaymentRow(
                              'Registration Fee',
                              '\$${_registrationFee.toStringAsFixed(2)}',
                              false,
                            ),
                            if (_discountApplied) ...[
                              _buildPaymentRow(
                                'Discount (${_discountPercentage.toInt()}%)',
                                '-\$${_discountAmount.toStringAsFixed(2)}',
                                false,
                              ),
                            ],
                            const Divider(),
                            _buildPaymentRow(
                              'Total',
                              '\$${(_registrationFee - _discountAmount).toStringAsFixed(2)}',
                              true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Complete Registration Button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isFreeEvent ? _completeFreeRegistration : _completeRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38A169),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isFreeEvent ? 'Complete Registration' : 'Next: Payment',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildPaymentRow(String label, String amount, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _applyDiscount() {
    if (_isProcessingDiscount || _cooldownSeconds > 0) {
      return; // Prevent rapid clicks
    }

    final code = _discountCodeController.text.trim().toLowerCase();

    setState(() {
      _isProcessingDiscount = true;
    });

    if (code == 'pickleball') {
      setState(() {
        _discountApplied = true;
        _discountPercentage = 30.0;
        _discountAmount = _registrationFee * (_discountPercentage / 100);
        _appliedDiscountCode = 'pickleball';
        _isProcessingDiscount = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickleball discount applied successfully!'),
          backgroundColor: Color(0xFF38A169),
        ),
      );
    } else if (code == 'earlybird') {
      setState(() {
        _discountApplied = true;
        _discountPercentage = 40.0;
        _discountAmount = _registrationFee * (_discountPercentage / 100);
        _appliedDiscountCode = 'earlybird';
        _isProcessingDiscount = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Early bird discount applied successfully!'),
          backgroundColor: Color(0xFF38A169),
        ),
      );
    } else {
      setState(() {
        _isProcessingDiscount = false;
      });

      // Start cooldown timer
      _cooldownSeconds = 3;
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _cooldownSeconds--;
        });
        if (_cooldownSeconds <= 0) {
          timer.cancel();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid discount code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatFullDate(DateTime date) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday $month ${date.day} ${date.year}';
  }

  void _completeRegistration() {
    // Navigate to payment screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PaymentScreen(
              team: widget.team,
              event: widget.event,
              amount: _registrationFee - _discountAmount,
            ),
      ),
    );
  }
  
  void _completeFreeRegistration() async {
    // For free events, skip payment and complete registration directly
    // Save the team to the database
    final teamService = PickleballTeamService();
    await teamService.addTeam(widget.team);
    
    if (mounted) {
      // Navigate to My Team tab after registering (index 2)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen(initialIndex: 2)),
        (route) => false,
      );
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration completed successfully!'),
          backgroundColor: Color(0xFF38A169),
        ),
      );
    }
  }
}
