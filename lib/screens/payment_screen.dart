import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _teamService = TeamService();
  final _pickleballTeamService = PickleballTeamService();

  String _cardType = 'unknown';
  int _maxCvvLength = 3;

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

  void _processPayment() async {
    // Validate all form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

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

    setState(() {
      _isProcessing = false;
      _paymentCompleted = true;
    });

    // Show success snackbar and navigate to home
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

            // Payment Form
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card Type Indicator
                      if (_cardType != 'unknown')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _cardType == 'visa'
                                    ? Colors.blue.withOpacity(0.1)
                                    : _cardType == 'mastercard'
                                    ? Colors.red.withOpacity(0.1)
                                    : _cardType == 'amex'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  _cardType == 'visa'
                                      ? Colors.blue
                                      : _cardType == 'mastercard'
                                      ? Colors.red
                                      : _cardType == 'amex'
                                      ? Colors.green
                                      : Colors.grey,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 16,
                                color:
                                    _cardType == 'visa'
                                        ? Colors.blue
                                        : _cardType == 'mastercard'
                                        ? Colors.red
                                        : _cardType == 'amex'
                                        ? Colors.green
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _cardType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _cardType == 'visa'
                                          ? Colors.blue
                                          : _cardType == 'mastercard'
                                          ? Colors.red
                                          : _cardType == 'amex'
                                          ? Colors.green
                                          : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_cardType != 'unknown') const SizedBox(height: 12),

                      // Card Number
                      TextFormField(
                        controller: _cardNumberController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter card number';
                          }
                          // Remove spaces and check if it's a valid card number
                          String digitsOnly = value.replaceAll(' ', '');
                          if (digitsOnly.length < 13 ||
                              digitsOnly.length > 19) {
                            return 'Please enter a valid card number';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Card Number',
                          hintText:
                              _cardType == 'amex'
                                  ? '1234 567890 12345'
                                  : '1234 5678 9012 3456',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            _cardType == 'visa'
                                ? Icons.credit_card
                                : _cardType == 'mastercard'
                                ? Icons.credit_card
                                : _cardType == 'amex'
                                ? Icons.credit_card
                                : Icons.credit_card,
                          ),
                          suffixIcon:
                              _cardType != 'unknown'
                                  ? Icon(
                                    _cardType == 'visa'
                                        ? Icons.credit_card
                                        : _cardType == 'mastercard'
                                        ? Icons.credit_card
                                        : _cardType == 'amex'
                                        ? Icons.credit_card
                                        : Icons.credit_card,
                                    color:
                                        _cardType == 'visa'
                                            ? Colors.blue
                                            : _cardType == 'mastercard'
                                            ? Colors.red
                                            : _cardType == 'amex'
                                            ? Colors.green
                                            : Colors.grey,
                                  )
                                  : null,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          // Remove all non-digit characters first
                          String digitsOnly = value.replaceAll(
                            RegExp(r'[^\d]'),
                            '',
                          );

                          // Check if we've exceeded the maximum length
                          int maxLength = _cardType == 'amex' ? 15 : 16;
                          if (digitsOnly.length > maxLength) {
                            digitsOnly = digitsOnly.substring(0, maxLength);
                          }

                          _detectCardType(digitsOnly);
                          String formatted = _formatCardNumber(digitsOnly);

                          if (formatted != value) {
                            _cardNumberController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            _cardType == 'amex'
                                ? 15
                                : 19, // Allow for spaces in formatted number
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Expiry and CVV
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter expiry date';
                                }
                                if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
                                  return 'Please enter valid expiry (MM/YY)';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Expiry (MM/YY)',
                                hintText: '12/25',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                String formatted = _formatExpiryDate(value);
                                if (formatted != value) {
                                  _expiryController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                      offset: formatted.length,
                                    ),
                                  );
                                }
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _cvvController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter CVV';
                                }
                                if (value.length < 3 || value.length > 4) {
                                  return 'Please enter valid CVV';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'CVV',
                                hintText: _cardType == 'amex' ? '1234' : '123',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(_maxCvvLength),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cardholder Name
                      TextFormField(
                        controller: _nameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter cardholder name';
                          }
                          if (value.trim().length < 2) {
                            return 'Please enter full name';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Cardholder Name',
                          hintText: 'John Doe',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Process Payment Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_isProcessing || _paymentCompleted)
                        ? null
                        : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isProcessing
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Processing Payment...'),
                          ],
                        )
                        : _paymentCompleted
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Payment Completed'),
                          ],
                        )
                        : const Text(
                          'Complete Payment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
