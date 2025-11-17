import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/team.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/team_service.dart';
import '../services/auth_service.dart';
import 'payment_screen.dart';
import 'main_navigation_screen.dart';

class ProcessRegistrationScreen extends StatefulWidget {
  final Team team;
  final Event event;

  const ProcessRegistrationScreen({
    super.key,
    required this.team,
    required this.event,
  });

  @override
  State<ProcessRegistrationScreen> createState() =>
      _ProcessRegistrationScreenState();
}

class _ProcessRegistrationScreenState extends State<ProcessRegistrationScreen> {
  final _discountCodeController = TextEditingController();

  // Get registration fee per player from event, or default to 350.0
  double get _pricePerPlayer => widget.event.amount ?? 350.0;
  bool get _isFreeEvent => widget.event.amount == null || widget.event.amount == 0;
  // Total registration fee = price per player * number of players
  double get _totalRegistrationFee => _isFreeEvent ? 0.0 : (_pricePerPlayer * widget.team.players.length);
  
  bool _discountApplied = false;
  double _discountPercentage = 0.0;
  double _discountAmount = 0.0;
  String _appliedDiscountCode = '';
  bool _isTypingDiscount = false;
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
    if (_discountCodeController.text.isNotEmpty && _discountApplied) {
      setState(() {
        _isTypingDiscount = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Process Registration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
            child: Column(
              children: [
                const SizedBox(height: 50),

                // Teams Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Teams Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Teams',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Team Information Details
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.sports_basketball,
                                    color: Color(0xFF1976D2),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Team Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1976D2),
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
                                      text: 'Team Name: ',
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
                                'Division: ${widget.team.division}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1976D2),
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
                                  (player) {
                                    // Get user profile if player is linked to a user
                                    User? linkedUser;
                                    final authService = AuthService();
                                    final currentUser = authService.currentUser;
                                    if (player.userId != null) {
                                      final users = authService.users;
                                      try {
                                        linkedUser = users.firstWhere((u) => u.id == player.userId);
                                      } catch (e) {
                                        linkedUser = null;
                                      }
                                    }
                                    
                                    final isCurrentUser = currentUser != null && player.userId == currentUser.id;
                                    
                                    // Price per player is the event amount
                                    final pricePerPlayer = _pricePerPlayer;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundImage: linkedUser?.profilePicturePath != null
                                                ? FileImage(File(linkedUser!.profilePicturePath!))
                                                : null,
                                            child: linkedUser?.profilePicturePath == null
                                                ? Text(player.name[0].toUpperCase())
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isCurrentUser ? '${player.name} (me)' : player.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Age: ${player.age}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      player.userId != null && linkedUser != null ? 'Registered' : 'Guest',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                        fontStyle: player.userId == null ? FontStyle.italic : FontStyle.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!_isFreeEvent)
                                            Text(
                                              '\$${pricePerPlayer.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),

                        // Total Footer
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_isFreeEvent && widget.team.players.isNotEmpty) ...[
                                Text(
                                  'Price per player: \$${_pricePerPlayer.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                _isFreeEvent 
                                    ? 'Total: Free'
                                    : 'Total: \$${_totalRegistrationFee.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Event Information Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.event,
                                color: Color(0xFF1976D2),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.event.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
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

                const SizedBox(height: 16),

                // Discount Code Section (only show if not free event)
                if (!_isFreeEvent) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Discount Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _discountCodeController,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter discount code',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed:
                                      (_discountApplied && !_isTypingDiscount) ||
                                              _isProcessingDiscount
                                          ? null
                                          : _applyDiscount,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      0,
                                      0,
                                      0,
                                    ),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    (_discountApplied && !_isTypingDiscount)
                                        ? 'Discount Applied'
                                        : _cooldownSeconds > 0
                                        ? 'Wait ${_cooldownSeconds}s'
                                        : 'Apply',
                                    style: TextStyle(
                                      color:
                                          _cooldownSeconds > 0
                                              ? Colors.white
                                              : Colors.white,
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
                  const SizedBox(height: 16),
                ],

                // Payment Summary Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Event and Team info
                          _buildPaymentRow('Event Name', widget.event.title, false),
                          const SizedBox(height: 4),
                          _buildPaymentRow('Team Name', widget.team.name, false),
                          const SizedBox(height: 16),
                          if (_isFreeEvent) ...[
                            _buildPaymentRow(
                              'Total',
                              'Free',
                              true,
                            ),
                          ] else ...[
                            _buildPaymentRow(
                              'Total',
                              '\$${_totalRegistrationFee.toStringAsFixed(2)}',
                              true,
                            ),
                            if (_discountApplied) ...[
                              const SizedBox(height: 8),
                              _buildPaymentRow(
                                'Discount: ${_discountPercentage.toStringAsFixed(0)}% ($_appliedDiscountCode)',
                                '\$${_discountAmount.toStringAsFixed(2)}',
                                false,
                              ),
                            ],
                            const SizedBox(height: 16),
                            _buildPaymentRow(
                              'Payable Amount',
                              '\$${_getPayableAmount().toStringAsFixed(2)}',
                              true,
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isFreeEvent ? _completeFreeRegistration : _processPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE67E22),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _isFreeEvent ? 'Complete Registration' : 'Proceed to Payment',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
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
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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

    if (code == 'hello') {
      setState(() {
        _discountApplied = true;
        _discountPercentage = 35.0;
        _discountAmount = _totalRegistrationFee * (_discountPercentage / 100);
        _appliedDiscountCode = 'hello';
        _isTypingDiscount = false;
        _isProcessingDiscount = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discount applied successfully!'),
          backgroundColor: Color(0xFF38A169),
        ),
      );
    } else if (code == 'hello2') {
      setState(() {
        _discountApplied = true;
        _discountPercentage = 50.0;
        _discountAmount = _totalRegistrationFee * (_discountPercentage / 100);
        _appliedDiscountCode = 'hello2';
        _isTypingDiscount = false;
        _isProcessingDiscount = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discount applied successfully!'),
          backgroundColor: Color(0xFF38A169),
        ),
      );
    } else {
      setState(() {
        _isProcessingDiscount = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid discount code'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );

      // Start cooldown timer for invalid codes
      _startCooldownTimer();
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownSeconds = 3; // 3 second cooldown

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _cooldownSeconds--;
        });

        if (_cooldownSeconds <= 0) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  double _getPayableAmount() {
    if (_discountApplied) {
      return _totalRegistrationFee - _discountAmount;
    }
    return _totalRegistrationFee;
  }

  void _processPayment() {
    // Navigate to payment screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PaymentScreen(
              team: widget.team,
              event: widget.event,
              amount: _getPayableAmount(),
            ),
      ),
    );
  }
  
  void _completeFreeRegistration() async {
    // For free events, skip payment and complete registration directly
    // Save the team to the database with correct eventId
    final teamService = TeamService();
    // Ensure eventId is set correctly from the event
    final teamWithEventId = Team(
      id: widget.team.id,
      name: widget.team.name,
      coachName: widget.team.coachName,
      coachPhone: widget.team.coachPhone,
      coachEmail: widget.team.coachEmail,
      coachAge: widget.team.coachAge,
      players: widget.team.players,
      registrationDate: widget.team.registrationDate,
      division: widget.team.division,
      createdByUserId: widget.team.createdByUserId,
      isPrivate: widget.team.isPrivate,
      eventId: widget.event.id, // Ensure eventId is set from the event
    );
    await teamService.addTeam(teamWithEventId);
    
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
}
