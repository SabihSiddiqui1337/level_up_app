import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:square_in_app_payments/in_app_payments.dart';
import 'package:square_in_app_payments/models.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../models/event.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import 'main_navigation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final dynamic team; // Can be Team or PickleballTeam
  final Event event;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.team,
    required this.event,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  bool _paymentCompleted = false;
  bool _squareInitialized = false;
  bool _applePayAvailable = false;
  bool _googlePayAvailable = false;
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _teamService = TeamService();
  final _pickleballTeamService = PickleballTeamService();

  String _cardType = 'unknown';
  int _maxCvvLength = 3;

  // Square Application ID - Replace with your actual ID
  static const String _squareApplicationId = 'sandbox-sq0idb-X0C_ewi4_MT4Xd-bqO_hew';

  @override
  void initState() {
    super.initState();
    _initializeSquare();
  }

  Future<void> _initializeSquare() async {
    try {
      await InAppPayments.setSquareApplicationId(_squareApplicationId);
      
      // Check for Apple Pay availability (iOS only)
      try {
        final applePayAvailable = await InAppPayments.canUseApplePay();
        setState(() {
          _applePayAvailable = applePayAvailable;
        });
        print('Apple Pay available: $applePayAvailable');
      } catch (e) {
        print('Apple Pay check failed (may not be iOS): $e');
        setState(() {
          _applePayAvailable = false;
        });
      }

      // Check for Google Pay availability (Android only)
      try {
        final googlePayAvailable = await InAppPayments.canUseGooglePay();
        setState(() {
          _googlePayAvailable = googlePayAvailable;
        });
        print('Google Pay available: $googlePayAvailable');
      } catch (e) {
        print('Google Pay check failed (may not be Android): $e');
        setState(() {
          _googlePayAvailable = false;
        });
      }

      setState(() {
        _squareInitialized = true;
      });
      print('✅ Square initialized successfully');
    } catch (e) {
      print('❌ Error initializing Square: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing payment system: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _detectCardType(String cardNumber) {
    // Remove all non-digit characters
    String digitsOnly = cardNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.startsWith('4')) {
      setState(() {
        _cardType = 'visa';
        _maxCvvLength = 3;
      });
    } else if (digitsOnly.startsWith('5') || digitsOnly.startsWith('2')) {
      setState(() {
        _cardType = 'mastercard';
        _maxCvvLength = 3;
      });
    } else if (digitsOnly.startsWith('3')) {
      if (digitsOnly.startsWith('34') || digitsOnly.startsWith('37')) {
        setState(() {
          _cardType = 'amex';
          _maxCvvLength = 4;
        });
      } else {
        setState(() {
          _cardType = 'diners';
          _maxCvvLength = 3;
        });
      }
    } else {
      setState(() {
        _cardType = 'unknown';
        _maxCvvLength = 3;
      });
    }
  }

  String _formatCardNumber(String value) {
    // Remove all non-digit characters
    String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (_cardType == 'amex') {
      // AMEX format: XXXX XXXXXX XXXXX
      if (digitsOnly.length <= 4) {
        return digitsOnly;
      } else if (digitsOnly.length <= 10) {
        return '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4)}';
      } else {
        return '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4, 10)} ${digitsOnly.substring(10, 15)}';
      }
    } else {
      // Other cards format: XXXX XXXX XXXX XXXX
      if (digitsOnly.length <= 4) {
        return digitsOnly;
      } else if (digitsOnly.length <= 8) {
        return '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4)}';
      } else if (digitsOnly.length <= 12) {
        return '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4, 8)} ${digitsOnly.substring(8)}';
      } else {
        return '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4, 8)} ${digitsOnly.substring(8, 12)} ${digitsOnly.substring(12, 16)}';
      }
    }
  }

  String _formatExpiryDate(String value) {
    // Remove all non-digit characters
    String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length <= 2) {
      return digitsOnly;
    } else if (digitsOnly.length >= 4) {
      return '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2, 4)}';
    } else {
      // Handle case where we have 3 digits - just add the slash
      return '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
    }
  }

  // Generate a unique idempotency key for the payment
  String _generateIdempotencyKey() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'payment_${timestamp}_${random.nextInt(10000)}';
  }

  Future<void> _processPaymentWithApplePay() async {
    if (!_squareInitialized || !_applePayAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apple Pay is not available. Please use another payment method.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Start Apple Pay flow
      await InAppPayments.startApplePayFlow(
        amount: widget.amount,
        currencyCode: 'USD',
        onApplePayNonceRequestSuccess: (CardDetails result) async {
          try {
            // Process payment with the nonce
            await _processPaymentWithNonce(result.nonce);
            
            // Complete Apple Pay
            await InAppPayments.completeApplePayAuthorization(
              isSuccess: true,
            );
            print('✅ Apple Pay completed successfully');
          } catch (e) {
            print('❌ Error processing Apple Pay: $e');
            // Complete with error
            await InAppPayments.completeApplePayAuthorization(
              isSuccess: false,
            );
            print('Apple Pay authorization failed');
          }
        },
        onApplePayCancel: () {
          print('Apple Pay cancelled by user');
          setState(() {
            _isProcessing = false;
          });
        },
      );
    } catch (e) {
      print('❌ Error starting Apple Pay: $e');
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting Apple Pay: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPaymentWithGooglePay() async {
    if (!_squareInitialized || !_googlePayAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Pay is not available. Please use another payment method.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Start Google Pay flow
      await InAppPayments.startGooglePayFlow(
        price: widget.amount.toStringAsFixed(2),
        priceStatus: 'FINAL',
        currencyCode: 'USD',
        onGooglePayNonceRequestSuccess: (CardDetails result) async {
          try {
            // Process payment with the nonce
            await _processPaymentWithNonce(result.nonce);
            
            // Complete Google Pay
            await InAppPayments.completeGooglePayAuthorization(
              isSuccess: true,
            );
            print('✅ Google Pay completed successfully');
          } catch (e) {
            print('❌ Error processing Google Pay: $e');
            // Complete with error
            await InAppPayments.completeGooglePayAuthorization(
              isSuccess: false,
            );
            print('Google Pay authorization failed');
          }
        },
        onGooglePayCancel: () {
          print('Google Pay cancelled by user');
          setState(() {
            _isProcessing = false;
          });
        },
      );
    } catch (e) {
      print('❌ Error starting Google Pay: $e');
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting Google Pay: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPaymentWithCard() async {
    if (!_squareInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment system not ready. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Start Square's card entry flow
      await InAppPayments.startCardEntryFlow(
        onCardNonceRequestSuccess: (CardDetails result) async {
          try {
            // Process payment with the card nonce
            await _processPaymentWithNonce(result.nonce);
            
            // Complete the card entry
            await InAppPayments.completeCardEntry(
              onCardEntryComplete: () {
                print('✅ Card entry completed successfully');
              },
            );
          } catch (e) {
            print('❌ Error processing payment: $e');
            // Show error to user
            await InAppPayments.showCardNonceProcessingError(e.toString());
          }
        },
        onCardEntryCancel: () {
          print('Card entry cancelled by user');
          setState(() {
            _isProcessing = false;
          });
        },
      );
    } catch (e) {
      print('❌ Error starting card entry: $e');
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPaymentWithNonce(String nonce) async {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase not initialized');
      }

      // Generate idempotency key
      final idempotencyKey = _generateIdempotencyKey();

      // Call Cloud Function to process payment
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('processSquarePayment');

      final result = await callable.call({
        'sourceId': nonce,
        'amount': widget.amount.toStringAsFixed(2),
        'idempotencyKey': idempotencyKey,
        'teamId': widget.team.id,
        'eventId': widget.event.id,
      });

      if (result.data['success'] == true) {
        print('✅ Payment processed successfully. Payment ID: ${result.data['paymentId']}');
        
        // Save the team after successful payment
        await _saveTeam();

        setState(() {
          _isProcessing = false;
          _paymentCompleted = true;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Payment successful! Your team has been registered.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }

        // Navigate to home after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
              (route) => false,
            );
          }
        });
      } else {
        throw Exception('Payment processing returned unsuccessful result');
      }
    } catch (e) {
      print('❌ Error processing payment with nonce: $e');
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _saveTeam() async {
    // Save the team to the appropriate service with correct eventId
    if (widget.team is Team) {
      final team = widget.team as Team;
      // Ensure eventId is set correctly from the event
      final teamWithEventId = Team(
        id: team.id,
        name: team.name,
        coachName: team.coachName,
        coachPhone: team.coachPhone,
        coachEmail: team.coachEmail,
        coachAge: team.coachAge,
        players: team.players,
        registrationDate: team.registrationDate,
        division: team.division,
        createdByUserId: team.createdByUserId,
        isPrivate: team.isPrivate,
        eventId: widget.event.id, // Ensure eventId is set from the event
      );
      print('Saving basketball team: ${teamWithEventId.name} with eventId: ${teamWithEventId.eventId}');
      await _teamService.addTeam(teamWithEventId);
      print('Basketball team saved successfully');
    } else if (widget.team is PickleballTeam) {
      final pickleballTeam = widget.team as PickleballTeam;
      // Ensure eventId is set correctly from the event
      final teamWithEventId = PickleballTeam(
        id: pickleballTeam.id,
        name: pickleballTeam.name,
        coachName: pickleballTeam.coachName,
        coachPhone: pickleballTeam.coachPhone,
        coachEmail: pickleballTeam.coachEmail,
        players: pickleballTeam.players,
        registrationDate: pickleballTeam.registrationDate,
        division: pickleballTeam.division,
        createdByUserId: pickleballTeam.createdByUserId,
        isPrivate: pickleballTeam.isPrivate,
        eventId: widget.event.id, // Ensure eventId is set from the event
      );
      print(
        'Saving pickleball team: ${teamWithEventId.name} with ID: ${teamWithEventId.id} and eventId: ${teamWithEventId.eventId}',
      );
      print(
        'Current teams before adding: ${_pickleballTeamService.teams.length}',
      );
      await _pickleballTeamService.addTeam(teamWithEventId);
      print(
        'Current teams after adding: ${_pickleballTeamService.teams.length}',
      );
      print('Pickleball team saved successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payment Summary Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payment, color: Color(0xFF1976D2), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Payment Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Team: ${widget.team.name}'),
                    Text('Event: ${widget.event.title}'),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Methods Card
            Card(
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
                        Icon(
                          Icons.payment,
                          color: _squareInitialized ? Colors.green : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Choose Payment Method',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _squareInitialized ? const Color(0xFF1976D2) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (!_squareInitialized) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Initializing payment system...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      // Apple Pay Button (iOS only)
                      if (_applePayAvailable) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_isProcessing || _paymentCompleted) ? null : _processPaymentWithApplePay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🍎',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pay with Apple Pay',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Google Pay Button (Android only)
                      if (_googlePayAvailable) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_isProcessing || _paymentCompleted) ? null : _processPaymentWithGooglePay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4285F4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/google_pay.png',
                                  height: 24,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.account_balance_wallet, size: 24);
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pay with Google Pay',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Divider if both Apple Pay and Google Pay are available
                      if ((_applePayAvailable || _googlePayAvailable)) ...[
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Card Entry Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: (_isProcessing || _paymentCompleted) ? null : _processPaymentWithCard,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1976D2), width: 2),
                            foregroundColor: const Color(0xFF1976D2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.credit_card, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Enter Card Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Processing Payment...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_paymentCompleted) ...[
              const SizedBox(height: 16),
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Payment Completed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
