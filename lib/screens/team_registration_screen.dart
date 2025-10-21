// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/event.dart';
import 'process_registration_screen.dart';

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

class TeamRegistrationScreen extends StatefulWidget {
  final Team? team; // For editing existing team
  final Function(Team)? onSave;

  const TeamRegistrationScreen({super.key, this.team, this.onSave});

  @override
  State<TeamRegistrationScreen> createState() => _TeamRegistrationScreenState();
}

class _TeamRegistrationScreenState extends State<TeamRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _coachNameController = TextEditingController();
  final _coachPhoneController = TextEditingController();
  final _coachEmailController = TextEditingController();

  final List<Player> _players = [];
  String _selectedDivision = 'Adult (18-35)';
  bool _hasUnsavedChanges = false;
  bool _isSaving = false; // Add flag to prevent rapid saving

  final List<String> _divisions = [
    'Youth (Under 18)',
    'Adult (18-35)',
    'Senior (35+)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.team != null) {
      _teamNameController.text = widget.team!.name;
      _coachNameController.text = widget.team!.coachName;
      _coachPhoneController.text = widget.team!.coachPhone;
      _coachEmailController.text = widget.team!.coachEmail;
      _selectedDivision = widget.team!.division;
      _players.addAll(widget.team!.players);
    }

    // Add listeners to track form changes
    _teamNameController.addListener(_onFormChanged);
    _coachNameController.addListener(_onFormChanged);
    _coachPhoneController.addListener(_onFormChanged);
    _coachEmailController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _coachNameController.dispose();
    _coachPhoneController.dispose();
    _coachEmailController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  void _addPlayer() {
    print('_addPlayer called'); // Debug print
    showDialog(
      context: context,
      builder:
          (context) => _PlayerDialog(
            onSave: (player) {
              print('Adding player to team: ${player.name}'); // Debug print
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
            onSave: (player) {
              setState(() {
                _players[index] = player;
                _hasUnsavedChanges = true;
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

  void _saveTeam() {
    if (_isSaving) return; // Prevent rapid clicking

    if (_formKey.currentState!.validate() && _players.isNotEmpty) {
      setState(() {
        _isSaving = true;
      });
      print('Saving team with ${_players.length} players'); // Debug print
      final team = Team(
        id: widget.team?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _teamNameController.text,
        coachName: _coachNameController.text,
        coachPhone: _coachPhoneController.text,
        coachEmail: _coachEmailController.text,
        players: List.from(_players), // Create a copy of the players list
        registrationDate: widget.team?.registrationDate ?? DateTime.now(),
        division: _selectedDivision,
      );
      print('Team created with ${team.players.length} players'); // Debug print
      print(
        'Team players: ${team.players.map((p) => p.name).toList()}',
      ); // Debug print

      // Create default event for basketball tournament
      const event = Event(
        id: 'basketball_tournament_2025',
        title: 'Basketball Tournament 2025',
        date: 'Sat. Nov. 8. 2025',
        location: 'Masjid Istiqlal',
        address: '123 Main Street,\nSugar Land, TX\n77498',
      );

      // Navigate to process registration screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProcessRegistrationScreen(team: team, event: event),
        ),
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
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
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
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(30),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Team Name',
                            prefixIcon: Icon(Icons.sports_basketball),
                            border: OutlineInputBorder(),
                            counterText: '', // Hide character counter
                          ),
                          onChanged: (value) {
                            // Clear validation error when user starts typing
                            if (value.isNotEmpty) {
                              _formKey.currentState?.validate();
                            }
                          },
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
                        DropdownButtonFormField<String>(
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
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Coach Information Card
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
                          'Coach Information',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
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
                            labelText: 'Coach Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            // Clear validation error when user starts typing
                            if (value.isNotEmpty) {
                              _formKey.currentState?.validate();
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter coach name';
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
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                            hintText: 'XXX-XXX-XXXX',
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 12, // 10 digits + 2 dashes
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(
                              10,
                            ), // Only allow 10 digits
                            PhoneNumberFormatter(), // Custom formatter
                          ],
                          onChanged: (value) {
                            // Clear validation error when user starts typing
                            if (value.isNotEmpty) {
                              _formKey.currentState?.validate();
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter phone number';
                            }
                            // Remove dashes for validation
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
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            // Clear validation error when user starts typing
                            if (value.isNotEmpty) {
                              _formKey.currentState?.validate();
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
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
                              onPressed:
                                  _players.length >= 8 ? null : _addPlayer,
                              icon: const Icon(Icons.add),
                              label: Text(
                                _players.length >= 8
                                    ? 'Max 8 players'
                                    : 'Add Player',
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
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2196F3),
                        const Color(0xFF1976D2),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTeam,
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
                          widget.team == null ? 'Next' : 'Update Team',
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
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
}

class _PlayerDialog extends StatefulWidget {
  final Player? player;
  final Function(Player) onSave;

  const _PlayerDialog({this.player, required this.onSave});

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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
