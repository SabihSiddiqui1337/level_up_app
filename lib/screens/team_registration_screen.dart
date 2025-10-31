// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../screens/main_navigation_screen.dart'; // Added import for MainNavigationScreen

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

  final List<String> _divisions = ['Youth (18 or under)', 'Adult 18+'];

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
    }

    // Add listeners to track form changes
    _teamNameController.addListener(_onFormChanged);
    _coachNameController.addListener(_onFormChanged);
    _coachPhoneController.addListener(_onFormChanged);
    _coachEmailController.addListener(_onFormChanged);
    _coachAgeController.addListener(_onFormChanged);
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

  void _addPlayer() {
    print('_addPlayer called'); // Debug print
    showDialog(
      context: context,
      builder:
          (context) => _PlayerDialog(
            selectedDivision: _selectedDivision ?? 'Adult 18+',
            onSave: (player) {
              print('Adding player to team: ${player.name}'); // Debug print
              setState(() {
                _players.add(player);
                _hasUnsavedChanges = true;
                // This will trigger button state update
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

    if (_formKey.currentState!.validate() && _players.isNotEmpty) {
      setState(() {
        _isSaving = true;
      });
      print('Saving team with ${_players.length} players'); // Debug print
      final currentUser = _authService.currentUser;
      final isAdmin =
          currentUser?.role == 'scoring' || currentUser?.role == 'owner';

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
        division: widget.event?.division ?? _selectedDivision ?? 'Adult 18+',
        createdByUserId: currentUser?.id,
        isPrivate:
            !isAdmin, // Regular users create private teams, admins create public teams
        eventId: widget.event?.id ?? '',
      );
      print('Team created with ${team.players.length} players'); // Debug print
      print(
        'Team players: ${team.players.map((p) => p.name).toList()}',
      ); // Debug print

      // Navigate to schedule tab after registering
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen(initialIndex: 2)),
        (route) => false,
      );

      // Reset unsaved changes flag
      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });
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
          title: Text(
            widget.team == null ? 'Register Team' : 'Edit Team',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
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

                // Division Field - Show as read-only text if event has division, otherwise dropdown
                widget.event?.division != null
                    ? TextFormField(
                        initialValue: widget.event!.division,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Division',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        readOnly: true,
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
                const SizedBox(height: 16),
                // Division Field - Show as read-only text if event has division, otherwise dropdown
                widget.event?.division != null
                    ? TextFormField(
                        initialValue: widget.event!.division,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Division',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        readOnly: true,
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
                          _formKey.currentState?.validate();
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
                Text(
                  'Team Captain Information',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1976D2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _coachNameController,
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Team Captain Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: 'Captain Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    hintText: 'XXX-XXX-XXXX',
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
                  decoration: const InputDecoration(
                    labelText: 'Captain Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
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

        // Players Section
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
                      'Players (${_players.length})',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _players.length >= 8 ? null : _addPlayer,
                      icon: const Icon(Icons.add),
                      label: Text(
                        _players.length >= 8 ? 'Max 8 players' : 'Add Player',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_players.isEmpty)
                  const Center(
                    child: Text(
                      'No players added yet. Click "Add Player" to get started.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(player.name),
                          subtitle: Text('Age: ${player.age}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
      final isAdmin =
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
        division: widget.event?.division ?? _selectedDivision ?? 'Adult 18+',
        createdByUserId: currentUser?.id,
        isPrivate: !isAdmin,
        eventId: widget.event?.id ?? '',
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

  const _PlayerDialog({
    this.player,
    required this.selectedDivision,
    required this.onSave,
  });

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.player != null) {
      _nameController.text = widget.player!.name;
      _ageController.text = widget.player!.age.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _savePlayer() {
    print('_savePlayer called'); // Debug print
    print(
      'Name: "${_nameController.text}", Age: "${_ageController.text}"',
    ); // Debug print

    if (_formKey.currentState!.validate()) {
      print('Form validation passed'); // Debug print
      final player = Player(
        id:
            widget.player?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        position: 'Player', // Default position
        jerseyNumber: 0, // Default jersey number
        phoneNumber: '', // Default phone
        email: '', // Default email
        age: int.parse(_ageController.text),
        height: 6.0, // Default height
        weight: 180.0, // Default weight
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
              children: [
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
            ),
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
