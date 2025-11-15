// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/team.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/team_service.dart';
import '../screens/main_navigation_screen.dart'; // Added import for MainNavigationScreen
import '../screens/process_registration_screen.dart'; // Added import for ProcessRegistrationScreen
import '../screens/player_stats_screen.dart'; // For navigating to player profiles

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

class AgeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 2 digits
    if (digitsOnly.length > 2) {
      digitsOnly = digitsOnly.substring(0, 2);
    }

    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}

class TeamRegistrationScreen extends StatefulWidget {
  final Team? team; // For editing existing team
  final Function(Team)? onSave;
  final Event? event; // Event being registered for

  const TeamRegistrationScreen({super.key, this.team, this.onSave, this.event});

  @override
  State<TeamRegistrationScreen> createState() => _TeamRegistrationScreenState();
}

class _TeamRegistrationScreenState extends State<TeamRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _coachNameController = TextEditingController();
  final _coachPhoneController = TextEditingController();
  final _coachEmailController = TextEditingController();
  final _coachAgeController = TextEditingController();
  final AuthService _authService = AuthService();

  final List<Player> _players = [];
  String? _selectedDivision; // Will be set from event if available
  bool _hasUnsavedChanges = false;
  bool _isSaving = false; // Add flag to prevent rapid saving
  bool _allowGuestUsers = false; // Enable/disable guest players section
  
  // Validation states for real-time validation
  final Map<String, String?> _fieldErrors = {};
  bool _hasAttemptedValidation = false;

  final List<String> _divisions = ['Youth (18 or under)', 'Adult 18+'];

  // Get max players for the sport
  int _getMaxPlayersForSport() {
    if (widget.event == null) return 8; // Default
    
    final sportName = widget.event!.sportName.toLowerCase();
    if (sportName.contains('pickleball') || sportName.contains('pickelball')) {
      return 1;
    } else if (sportName.contains('volleyball')) {
      return 8;
    } else if (sportName.contains('basketball')) {
      return 6;
    } else if (sportName.contains('soccer')) {
      return 10;
    }
    return 8; // Default
  }

  @override
  void initState() {
    super.initState();

    // Add a small delay to ensure proper initialization and prevent keyboard event issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeForm();
    });
  }

  void _initializeForm() {
    // Set division from event if available, otherwise use team's division or default
    if (widget.event?.division != null) {
      _selectedDivision = widget.event!.division;
    } else if (widget.team != null) {
      // Map old division values to new ones
      String existingDivision = widget.team!.division;
      if (existingDivision == 'Adult (18-35)' ||
          existingDivision == 'Adult 18+') {
        _selectedDivision = 'Adult 18+';
      } else if (existingDivision == 'Youth (18 or under)') {
        _selectedDivision = 'Youth (18 or under)';
      } else {
        // Default to Adult 18+ if division doesn't match
        _selectedDivision = 'Adult 18+';
      }
    } else {
      _selectedDivision = 'Adult 18+'; // Default
    }
    
    if (widget.team != null) {
      _teamNameController.text = widget.team!.name;
      _coachNameController.text = widget.team!.coachName;
      _coachPhoneController.text = widget.team!.coachPhone;
      _coachEmailController.text = widget.team!.coachEmail;
      _coachAgeController.text = widget.team!.coachAge.toString();

      // Load existing players and trigger UI update
      _players.clear();
      _players.addAll(widget.team!.players);

      // Force UI update to show existing players
      if (mounted) {
        setState(() {});
      }
    } else {
      // New team registration: Auto-add current user as a player
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final autoPlayer = Player(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: currentUser.name,
          position: 'Player',
          jerseyNumber: int.tryParse(currentUser.jerseyNumber ?? '0') ?? 0,
          phoneNumber: currentUser.phone,
          email: currentUser.email,
          age: currentUser.age ?? 25,
          height: double.tryParse(currentUser.height ?? '0') ?? 0.0,
          weight: double.tryParse(currentUser.weight ?? '0') ?? 0.0,
          userId: currentUser.id, // Link to user profile
        );
        _players.add(autoPlayer);
        if (mounted) {
          setState(() {});
        }
      }
    }

    // Add listeners to track form changes and validate in real-time
    _teamNameController.addListener(() {
      _onFormChanged();
      _validateField('teamName', _teamNameController.text);
    });
    _coachNameController.addListener(() {
      _onFormChanged();
      _validateField('coachName', _coachNameController.text);
    });
    _coachPhoneController.addListener(() {
      _onFormChanged();
      _validateField('coachPhone', _coachPhoneController.text);
    });
    _coachEmailController.addListener(() {
      _onFormChanged();
      _validateField('coachEmail', _coachEmailController.text);
    });
    _coachAgeController.addListener(() {
      _onFormChanged();
      _validateField('coachAge', _coachAgeController.text);
    });
  }
  
  void _validateField(String fieldName, String value) {
    if (!_hasAttemptedValidation) return;
    
    String? error;
    switch (fieldName) {
      case 'teamName':
        if (value.isEmpty) {
          error = 'Please enter team name';
        }
        break;
      case 'coachName':
        if (value.isEmpty) {
          error = 'Please enter captain name';
        }
        break;
      case 'coachPhone':
        if (value.isEmpty) {
          error = 'Please enter captain phone';
        } else {
          final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
          if (digitsOnly.length != 10) {
            error = 'Enter 10-digit number';
          }
        }
        break;
      case 'coachEmail':
        if (value.isEmpty) {
          error = 'Please enter captain email';
        } else if (!value.contains('@')) {
          error = 'Please enter a valid email';
        }
        break;
      case 'coachAge':
        if (value.isEmpty) {
          error = 'Please enter captain age';
        } else {
          final age = int.tryParse(value);
          if (age == null) {
            error = 'Please enter a valid age';
          } else if (_selectedDivision == 'Youth (18 or under)') {
            if (age > 18) {
              error = 'Captain age must be 18 or under for Youth division';
            }
          } else if (_selectedDivision == 'Adult 18+') {
            if (age < 18) {
              error = 'Captain age must be 18 or older for Adult division';
            }
          }
        }
        break;
    }
    
    if (mounted) {
      setState(() {
        if (error != null) {
          _fieldErrors[fieldName] = error;
        } else {
          _fieldErrors.remove(fieldName);
        }
      });
    }
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _coachNameController.dispose();
    _coachPhoneController.dispose();
    _coachEmailController.dispose();
    _coachAgeController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    // Add defensive programming to prevent keyboard event issues
    if (mounted) {
      try {
        setState(() {
          _hasUnsavedChanges = true;
          // This will trigger a rebuild to update button state
        });
      } catch (e) {
        // Handle any potential state update issues
        print('Form change handler error: $e');
      }
    }
  }

  // Add registered player (from search/profile)
  void _addRegisteredPlayer() {
    showDialog(
      context: context,
      builder:
          (context) => _PlayerDialog(
            selectedDivision: _selectedDivision ?? 'Adult 18+',
            allowGuest: false, // Only allow registered users
            onSave: (player) {
              print('Adding registered player to team: ${player.name}'); // Debug print
              setState(() {
                _players.add(player);
                _hasUnsavedChanges = true;
              });
              print('Total players now: ${_players.length}'); // Debug print
            },
          ),
    );
  }

  // Add guest player (manual entry)
  void _addGuestPlayer() {
    showDialog(
      context: context,
      builder:
          (context) => _PlayerDialog(
            selectedDivision: _selectedDivision ?? 'Adult 18+',
            allowGuest: true, // Force guest mode
            onSave: (player) {
              print('Adding guest player to team: ${player.name}'); // Debug print
              setState(() {
                _players.add(player);
                _hasUnsavedChanges = true;
              });
              print('Total players now: ${_players.length}'); // Debug print
            },
          ),
    );
  }

  void _editPlayer(int index) {
    showDialog(
      context: context,
      builder:
          (context) => _PlayerDialog(
            player: _players[index],
            selectedDivision: _selectedDivision ?? 'Adult 18+',
            onSave: (player) {
              setState(() {
                _players[index] = player;
                _hasUnsavedChanges = true;
                // This will trigger button state update
              });
            },
          ),
    );
  }

  void _removePlayer(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Player'),
          content: Text('Are you sure you want to delete this player?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _players.removeAt(index);
                  _hasUnsavedChanges = true;
                  // This will trigger button state update
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _saveTeam() async {
    if (_isSaving) return; // Prevent rapid clicking

    // Check if event still exists (if registering for an event)
    if (widget.event != null) {
      final eventService = EventService();
      await eventService.initialize();
      final existingEvent = eventService.getEventById(widget.event!.id);
      if (existingEvent == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This event has been deleted. Registration is no longer available.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
    }

    // Mark that user has attempted validation
    _hasAttemptedValidation = true;
    
    // Validate all fields
    _validateField('teamName', _teamNameController.text);
    _validateField('coachName', _coachNameController.text);
    _validateField('coachPhone', _coachPhoneController.text);
    _validateField('coachEmail', _coachEmailController.text);
    _validateField('coachAge', _coachAgeController.text);
    
    if (_formKey.currentState!.validate() && _players.isNotEmpty && _fieldErrors.isEmpty) {
      setState(() {
        _isSaving = true;
      });
      print('Saving team with ${_players.length} players'); // Debug print
      final currentUser = _authService.currentUser;
      final isAdmin = currentUser?.role == 'scoring' || currentUser?.role == 'owner';

      final team = Team(
        id: widget.team?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _teamNameController.text,
        coachName: _coachNameController.text,
        coachPhone: _coachPhoneController.text,
        coachEmail: _coachEmailController.text,
        coachAge:
            int.tryParse(_coachAgeController.text) ??
            25, // Default to 25 if invalid
        players: List.from(_players), // Create a copy of the players list
        registrationDate: widget.team?.registrationDate ?? DateTime.now(),
        // Always use event division if set, otherwise use selected division
        // This ensures division is locked when event has it set
        division: (widget.event != null && 
                   widget.event!.division != null && 
                   widget.event!.division!.trim().isNotEmpty)
                  ? widget.event!.division!
                  : (_selectedDivision ?? 'Adult 18+'),
        createdByUserId: currentUser?.id,
        isPrivate:
            !isAdmin, // Regular users create private teams, admins create public teams
        eventId: widget.event?.id ?? widget.team?.eventId ?? '',
      );
      print('Team created with ${team.players.length} players'); // Debug print
      print(
        'Team players: ${team.players.map((p) => p.name).toList()}',
      ); // Debug print

      // Reset saving state before navigation
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
      }

      // Navigate to summary/process registration screen, then payment
      // Only navigate if we have an event (required for payment flow)
      if (widget.event != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessRegistrationScreen(
              team: team,
              event: widget.event!,
            ),
          ),
        );
      } else {
        // If no event, save directly (for editing existing teams or when event is not provided)
        if (widget.team != null && widget.onSave != null) {
          // If editing an existing team, call onSave callback
          widget.onSave!(team);
          if (mounted) {
            Navigator.pop(context);
          }
        } else if (widget.onSave != null) {
          // If callback provided for new team, use it
          widget.onSave!(team);
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          // Persist via TeamService when no callback is provided
          await TeamService().addTeam(team);
          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.team == null
                      ? 'Team "${team.name}" created successfully!'
                      : 'Team "${team.name}" updated successfully!',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            // Navigate to My Team tab after registering (index 2)
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigationScreen(initialIndex: 2)),
              (route) => false,
            );
          }
        }
      }
    } else if (_players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one player',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.event != null && widget.event!.title.isNotEmpty
                  ? '${widget.event!.title} Registration'
                  : (widget.team == null ? 'Register Team' : 'Edit Team'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          backgroundColor: const Color(0xFF1976D2),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Show simplified form for management users
                if (_authService.isManagement)
                  _buildManagementForm()
                else
                  _buildRegularForm(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _validatePlayersForDivision() {
    // Check if any existing players don't match the new division
    List<Player> playersToRemove = [];

    for (int i = 0; i < _players.length; i++) {
      final player = _players[i];
      bool isValid = true;

      if (_selectedDivision == 'Youth (18 or under)' && player.age > 18) {
        isValid = false;
      } else if (_selectedDivision == 'Adult 18+' && player.age < 18) {
        isValid = false;
      }

      if (!isValid) {
        playersToRemove.add(player);
      }
    }

    // Show confirmation dialog if players need to be removed
    if (playersToRemove.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Division Change'),
            content: Text(
              'Changing to "$_selectedDivision" will remove ${playersToRemove.length} player(s) who don\'t meet the age requirements:\n\n'
              '${playersToRemove.map((p) => '• ${p.name} (age ${p.age})').join('\n')}\n\n'
              'Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Revert division change
                  setState(() {
                    _selectedDivision =
                        _selectedDivision == 'Youth (18 or under)'
                            ? 'Adult 18+'
                            : 'Youth (18 or under)';
                  });
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Remove incompatible players
                  setState(() {
                    for (var player in playersToRemove) {
                      _players.remove(player);
                    }
                    _hasUnsavedChanges = true;
                  });

                  // Show confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${playersToRemove.length} player(s) removed due to age requirements for $_selectedDivision division',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Remove Players'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true; // Allow navigation if no changes
    }

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Exit without saving?'),
                content: const Text(
                  'You have unsaved changes. Are you sure you want to exit without completing the form?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  String _getAgeRequirementText() {
    if (_selectedDivision == 'Youth (18 or under)') {
      return 'Age must be 18 or under for Youth division';
    } else if (_selectedDivision == 'Adult 18+') {
      return 'Age must be 18 or older for Adult division';
    }
    return 'Enter captain age';
  }

  Widget _buildManagementForm() {
    return Column(
      children: [
        // Team Information Card
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
                Text(
                  widget.event?.title ?? 'Register Team',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 24),

                // Team Name Field
                TextFormField(
                  controller: _teamNameController,
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    labelText: 'Team Name',
                    prefixIcon: Icon(Icons.sports_basketball),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter team name';
                    }
                    if (value.length > 30) {
                      return 'Team name must be 30 characters or less';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Division Field - Always locked when event has division set (for ALL users)
                // If event exists and has a division set, it MUST be locked and read-only
                (widget.event != null && 
                 widget.event!.division != null && 
                 widget.event!.division!.trim().isNotEmpty)
                    ? TextFormField(
                        initialValue: widget.event!.division,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Division (Preset)',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          hintText: 'Set by event organizer',
                        ),
                        readOnly: true,
                        enabled: false,
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedDivision,
                        decoration: const InputDecoration(
                          labelText: 'Division',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _divisions.map((String division) {
                              return DropdownMenuItem<String>(
                                value: division,
                                child: Text(division),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedDivision = newValue!;
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                const SizedBox(height: 24),

                // Save Button
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient:
                        _isFormComplete()
                            ? LinearGradient(
                              colors: [
                                const Color(0xFF2196F3),
                                const Color(0xFF1976D2),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                            : LinearGradient(
                              colors: [Colors.grey[300]!, Colors.grey[400]!],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow:
                        _isFormComplete()
                            ? [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ]
                            : [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                  ),
                  child: ElevatedButton(
                    onPressed:
                        (_isSaving || !_isFormComplete())
                            ? null
                            : _saveManagementTeam,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_forward, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          _isSaving
                              ? 'Saving...'
                              : (widget.team == null
                                  ? 'Create Team'
                                  : 'Update Team'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
      ],
    );
  }

  Widget _buildRegularForm() {
    return Column(
      children: [
        // Team Information Card
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
                Text(
                  'Team Information',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1976D2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Division Field - Only show for Basketball and Pickleball
                // For Volleyball and Soccer, hide division field
                Builder(
                  builder: (context) {
                    final sportName = (widget.event != null) 
                        ? widget.event!.sportName.toLowerCase() 
                        : '';
                    final isVolleyball = sportName.contains('volleyball');
                    final isSoccer = sportName.contains('soccer');
                    
                    // Hide division for Volleyball and Soccer
                    if (isVolleyball || isSoccer) {
                      return const SizedBox.shrink();
                    }
                    
                    // Show division for Basketball and Pickleball
                    return (widget.event != null && 
                     widget.event!.division != null && 
                     widget.event!.division!.trim().isNotEmpty)
                        ? TextFormField(
                            initialValue: widget.event!.division,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Division (Preset)',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              hintText: 'Set by event organizer',
                            ),
                            readOnly: true,
                            enabled: false,
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedDivision,
                            decoration: const InputDecoration(
                              labelText: 'Division',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                _divisions.map((String division) {
                                  return DropdownMenuItem<String>(
                                    value: division,
                                    child: Text(division),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDivision = newValue!;
                                _hasUnsavedChanges = true;
                              });
                              _validatePlayersForDivision();
                              // Re-validate age field when division changes
                              _validateField('coachAge', _coachAgeController.text);
                              _formKey.currentState?.validate();
                            },
                          );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Team Captain Information Card
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Team Captain Information',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final currentUser = _authService.currentUser;
                        if (currentUser != null) {
                          setState(() {
                            _coachNameController.text = currentUser.name;
                            _coachPhoneController.text = currentUser.phone;
                            _coachEmailController.text = currentUser.email;
                            _hasUnsavedChanges = true;
                            _hasAttemptedValidation = true; // Enable validation
                          });
                          // Trigger validation after filling
                          _validateField('coachName', currentUser.name);
                          _validateField('coachPhone', currentUser.phone);
                          _validateField('coachEmail', currentUser.email);
                          // Also validate team name field
                          _validateField('teamName', _teamNameController.text);
                          if (_formKey.currentState != null) {
                            _formKey.currentState!.validate();
                          }
                          // Trigger form change to enable Next button
                          _onFormChanged();
                        }
                      },
                      icon: const Icon(Icons.person, size: 18),
                      label: const Text('Myself'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _coachNameController,
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Team Captain Name',
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                    errorText: _hasAttemptedValidation ? _fieldErrors['coachName'] : null,
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter team captain name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _coachPhoneController,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Captain Phone Number',
                    prefixIcon: const Icon(Icons.phone),
                    border: const OutlineInputBorder(),
                    hintText: 'XXX-XXX-XXXX',
                    errorText: _hasAttemptedValidation ? _fieldErrors['coachPhone'] : null,
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 12,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    PhoneNumberFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter captain phone number';
                    }
                    final digitsOnly = value.replaceAll('-', '');
                    if (digitsOnly.length != 10) {
                      return 'Enter 10-digit number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _coachEmailController,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Captain Email',
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                    errorText: _hasAttemptedValidation ? _fieldErrors['coachEmail'] : null,
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter captain email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _coachAgeController,
                  inputFormatters: [AgeFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Captain Age',
                    prefixIcon: const Icon(Icons.cake),
                    border: const OutlineInputBorder(),
                    helperText: _getAgeRequirementText(),
                    helperStyle: TextStyle(
                      color:
                          _selectedDivision == 'Youth (18 or under)'
                              ? Colors.blue[700]
                              : Colors.green[700],
                      fontSize: 12,
                    ),
                    errorText: _hasAttemptedValidation ? _fieldErrors['coachAge'] : null,
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter captain age';
                    }
                    final age = int.tryParse(value);
                    if (age == null) {
                      return 'Please enter a valid age';
                    }

                    if (_selectedDivision == 'Youth (18 or under)') {
                      if (age > 18) {
                        return 'Captain age must be 18 or under for Youth division';
                      }
                    } else if (_selectedDivision == 'Adult 18+') {
                      if (age < 18) {
                        return 'Captain age must be 18 or older for Adult division';
                      }
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section 1 - Registered Players (Always Enabled)
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
                Text(
                  'Section 1 - Registered Players',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1976D2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Team Name Field (in Section 1)
                TextFormField(
                  controller: _teamNameController,
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: InputDecoration(
                    labelText: 'Team Name',
                    prefixIcon: const Icon(Icons.sports_basketball),
                    border: const OutlineInputBorder(),
                    counterText: '',
                    errorText: _hasAttemptedValidation ? _fieldErrors['teamName'] : null,
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter team name';
                    }
                    if (value.length > 30) {
                      return 'Team name must be 30 characters or less';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Check max players excluding auto-added player
                      final maxPlayers = _getMaxPlayersForSport();
                      final currentUser = _authService.currentUser;
                      // Count only players that are NOT the auto-added current user
                      final nonAutoAddedPlayers = _players.where((p) => p.userId != currentUser?.id).length;
                      
                      if (nonAutoAddedPlayers >= maxPlayers) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Max player reached'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      _addRegisteredPlayer();
                    },
                    icon: const Icon(Icons.add),
                    label: Builder(
                      builder: (context) {
                        final maxPlayers = _getMaxPlayersForSport();
                        final currentUser = _authService.currentUser;
                        final nonAutoAddedPlayers = _players.where((p) => p.userId != currentUser?.id).length;
                        return Text(
                          nonAutoAddedPlayers >= maxPlayers ? 'Max $maxPlayers players' : 'Add Player',
                        );
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section 2 - Guest Players (Disabled until checkbox)
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
                CheckboxListTile(
                  title: const Text(
                    'Guest Users',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text('Enable manual guest player entry'),
                  value: _allowGuestUsers,
                  onChanged: (value) {
                    setState(() {
                      _allowGuestUsers = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: !_allowGuestUsers || _players.length >= _getMaxPlayersForSport()
                        ? null
                        : _addGuestPlayer,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _players.length >= _getMaxPlayersForSport() ? 'Max ${_getMaxPlayersForSport()} players' : 'Add Player',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allowGuestUsers
                          ? const Color(0xFF2196F3)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Players Overview Section (Always Visible)
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
                Text(
                  'Players Overview (${_players.length})',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1976D2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_players.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No players added yet. Add players from Section 1 or Section 2.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _players.length,
                    itemBuilder: (context, index) {
                      final player = _players[index];
                      // Get user profile if player is linked to a user
                      User? linkedUser;
                      if (player.userId != null) {
                        final users = _authService.users;
                        try {
                          linkedUser = users.firstWhere((u) => u.id == player.userId);
                        } catch (e) {
                          linkedUser = null;
                        }
                      }
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: linkedUser?.profilePicturePath != null
                                ? FileImage(File(linkedUser!.profilePicturePath!))
                                : null,
                            child: linkedUser?.profilePicturePath == null
                                ? Text(player.name[0].toUpperCase())
                                : null,
                          ),
                          title: Text(player.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Age: ${player.age}'),
                              if (player.userId != null && linkedUser != null)
                                Text(
                                  'ID: ${player.userId}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                )
                              else if (player.userId == null)
                                Text(
                                  'Guest',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                          onTap: player.userId != null && linkedUser != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlayerStatsScreen(user: linkedUser!),
                                    ),
                                  );
                                }
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (player.userId != null && linkedUser != null)
                                IconButton(
                                  icon: const Icon(Icons.person, size: 20),
                                  tooltip: 'View Profile',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PlayerStatsScreen(user: linkedUser!),
                                      ),
                                    );
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editPlayer(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removePlayer(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),

        // Save Button
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient:
                _isFormComplete()
                    ? LinearGradient(
                      colors: [
                        const Color(0xFF2196F3),
                        const Color(0xFF1976D2),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                    : LinearGradient(
                      colors: [Colors.grey[400]!, Colors.grey[500]!],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                _isFormComplete()
                    ? [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
          ),
          child: ElevatedButton(
            onPressed: (_isSaving || !_isFormComplete()) ? null : _saveTeam,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_forward, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _isSaving
                      ? 'Saving...'
                      : (widget.team == null ? 'Next' : 'Update Team'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _saveManagementTeam() {
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final currentUser = _authService.currentUser;
      final isAdmin = _authService.isManagement ||
          currentUser?.role == 'scoring' || currentUser?.role == 'owner';

      final team = Team(
        id: widget.team?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _teamNameController.text,
        coachName: 'Management Team', // Default for management
        coachPhone: '000-000-0000', // Default for management
        coachEmail: 'management@levelup.com', // Default for management
        coachAge: 25, // Default age
        players: [], // Empty players list for management
        registrationDate: widget.team?.registrationDate ?? DateTime.now(),
        // Always use event division if set, otherwise use selected division
        // This ensures division is locked when event has it set
        division: (widget.event != null && 
                   widget.event!.division != null && 
                   widget.event!.division!.trim().isNotEmpty)
                  ? widget.event!.division!
                  : (_selectedDivision ?? 'Adult 18+'),
        createdByUserId: currentUser?.id,
        // Admin/management teams should be public (visible to all)
        // Regular user teams should be private (visible only to creator)
        isPrivate: !isAdmin,
        eventId: widget.event?.id ?? widget.team?.eventId ?? '',
      );

      // If editing an existing team, call onSave callback
      if (widget.team != null && widget.onSave != null) {
        widget.onSave!(team);
        setState(() {
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Save the team directly for management users
        if (widget.onSave != null) {
          widget.onSave!(team);
        } else {
          // Persist via TeamService when no callback is provided
          TeamService().addTeam(team);
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.team == null
                  ? 'Team "${team.name}" created successfully!'
                  : 'Team "${team.name}" updated successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Reset form only if creating new team
        if (widget.team == null) {
          _teamNameController.clear();
          setState(() {
            _selectedDivision = 'Adult 18+'; // Reset to default
          });
        }

        // Reset unsaved changes flag
        setState(() {
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
      }
    }
  }

  bool _isFormComplete() {
    // Check if all required fields are filled based on user role
    final isManagement = _authService.isManagement;

    if (isManagement) {
      // For management users, only require team name and division
      return _teamNameController.text.trim().isNotEmpty;
    } else {
      // For regular users, require all fields
      return _teamNameController.text.trim().isNotEmpty &&
          _coachNameController.text.trim().isNotEmpty &&
          _coachPhoneController.text.trim().isNotEmpty &&
          _coachEmailController.text.trim().isNotEmpty &&
          _coachAgeController.text.trim().isNotEmpty &&
          _players.isNotEmpty;
    }
  }
}

class _PlayerDialog extends StatefulWidget {
  final Player? player;
  final String selectedDivision;
  final Function(Player) onSave;
  final bool allowGuest; // If true, force guest mode; if false, only allow registered users

  const _PlayerDialog({
    this.player,
    required this.selectedDivision,
    required this.onSave,
    this.allowGuest = true, // Default to allowing guest mode
  });

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isGuest = false;
  User? _selectedUser;
  List<User> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.player != null) {
      _nameController.text = widget.player!.name;
      _ageController.text = widget.player!.age.toString();
      _isGuest = widget.player!.userId == null;
      // If player has userId, try to find the user
      if (widget.player!.userId != null) {
        final users = _authService.users;
        try {
          _selectedUser = users.firstWhere((u) => u.id == widget.player!.userId);
        } catch (e) {
          _selectedUser = null;
        }
      }
    } else {
      // New player: if allowGuest is false, force registered user mode (not guest)
      // If allowGuest is true, start with guest mode
      _isGuest = widget.allowGuest;
      // If allowGuest is false, ensure we're not in guest mode
      if (!widget.allowGuest) {
        _isGuest = false;
      }
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      final allUsers = _authService.users;
      _searchResults = allUsers.where((user) {
        final queryLower = query.toLowerCase();
        return user.name.toLowerCase().contains(queryLower) ||
               user.username.toLowerCase().contains(queryLower) ||
               user.email.toLowerCase().contains(queryLower) ||
               user.id.toLowerCase().contains(queryLower) ||
               user.phone.replaceAll(RegExp(r'[^\d]'), '').contains(query.replaceAll(RegExp(r'[^\d]'), ''));
      }).toList();
    });
  }

  void _selectUser(User user) {
    setState(() {
      _selectedUser = user;
      _isGuest = false;
      _nameController.text = user.name;
      _ageController.text = user.age?.toString() ?? '25';
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _toggleGuest(bool? value) {
    // Only allow toggling if allowGuest is true
    if (!widget.allowGuest && value == true) {
      return;
    }
    setState(() {
      _isGuest = value ?? false;
      if (_isGuest) {
        _selectedUser = null;
        _nameController.clear();
        _ageController.clear();
      }
    });
  }

  void _savePlayer() {
    print('_savePlayer called'); // Debug print
    print(
      'Name: "${_nameController.text}", Age: "${_ageController.text}", Guest: $_isGuest, UserId: ${_selectedUser?.id}',
    ); // Debug print

    if (_formKey.currentState!.validate()) {
      // If allowGuest is false, user MUST select a registered user
      if (!widget.allowGuest && _selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please search and select a registered player profile'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // If allowGuest is true, validate that either a user is selected OR guest is checked
      if (widget.allowGuest) {
        if (!_isGuest && _selectedUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please search and select a player profile, or check Guest to add manually'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (_isGuest && _nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter player name for guest player'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      print('Form validation passed'); // Debug print
      final player = Player(
        id:
            widget.player?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        position: 'Player', // Default position
        jerseyNumber: int.tryParse(_selectedUser?.jerseyNumber ?? '0') ?? 0, // Use user's jersey number if available
        phoneNumber: _selectedUser?.phone ?? '', // Use user's phone if available
        email: _selectedUser?.email ?? '', // Use user's email if available
        age: int.parse(_ageController.text),
        height: 6.0, // Default height
        weight: 180.0, // Default weight
        userId: _isGuest ? null : _selectedUser?.id, // Link to user profile if not guest
      );

      print('Player created: ${player.name}'); // Debug print
      widget.onSave(player);
      Navigator.pop(context);
    } else {
      print('Form validation failed!'); // Debug print
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.player == null ? 'Add Player' : 'Edit Player'),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search field for player profiles
                // Show if: (not in guest mode) OR (allowGuest is false - force registered user mode)
                if (!_isGuest || !widget.allowGuest) ...[
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Player Profile',
                      hintText: 'Enter player name, ID, username, email, or phone number',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchResults = [];
                                  _isSearching = false;
                                  _selectedUser = null;
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => _onSearchChanged(),
                  ),
                  const SizedBox(height: 8),
                  
                  // Search results
                  if (_isSearching && _searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.profilePicturePath != null
                                  ? FileImage(File(user.profilePicturePath!))
                                  : null,
                              child: user.profilePicturePath == null
                                  ? Text(user.name[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(user.name),
                            subtitle: Text('@${user.username}'),
                            onTap: () => _selectUser(user),
                          );
                        },
                      ),
                    ),
                  
                  
                  if (_isSearching && _searchResults.isEmpty && _searchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No players found',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Selected user display
                  if (_selectedUser != null && !_isSearching)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: _selectedUser!.profilePicturePath != null
                                ? FileImage(File(_selectedUser!.profilePicturePath!))
                                : null,
                            child: _selectedUser!.profilePicturePath == null
                                ? Text(_selectedUser!.name[0].toUpperCase())
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedUser!.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '@${_selectedUser!.username}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                _selectedUser = null;
                                _nameController.clear();
                                _ageController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                ],
                
                // Guest checkbox (only show if guest mode is allowed)
                if (widget.allowGuest) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Guest Player'),
                    subtitle: const Text('Add a player manually without linking to a profile'),
                    value: _isGuest,
                    onChanged: _toggleGuest,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Player Name and Age fields (only shown when Guest is checked)
                if (_isGuest) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Player Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _formKey.currentState?.validate();
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter player name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _formKey.currentState?.validate();
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter age';
                      }
                      final age = int.tryParse(value);
                      if (age == null) {
                        return 'Invalid age';
                      }
                      if (age < 1 || age > 99) {
                        return 'Age must be between 1 and 99';
                      }

                      // Division-based age validation
                      if (widget.selectedDivision == 'Youth (18 or under)' &&
                          age > 18) {
                        return 'Player must be 18 or under for Youth division';
                      }
                      if (widget.selectedDivision == 'Adult 18+' && age < 18) {
                        return 'Player must be 18 or older for Adult division';
                      }

                      return null;
                    },
                  ),
                ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _savePlayer,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          child: Text(widget.player == null ? 'Add Player' : 'Update Player'),
        ),
      ],
    );
  }
}
