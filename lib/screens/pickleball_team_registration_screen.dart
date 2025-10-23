// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pickleball_team.dart';
import '../models/pickleball_player.dart';
import '../models/event.dart';
import '../keys/pickleball_screen/pickleball_screen_keys.dart';
import 'pickleball_process_registration_screen.dart';

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

class PickleballTeamRegistrationScreen extends StatefulWidget {
  final PickleballTeam? team; // For editing existing team
  final Function(PickleballTeam)? onSave;

  const PickleballTeamRegistrationScreen({super.key, this.team, this.onSave});

  @override
  State<PickleballTeamRegistrationScreen> createState() =>
      _PickleballTeamRegistrationScreenState();
}

class _PickleballTeamRegistrationScreenState
    extends State<PickleballTeamRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _coachNameController = TextEditingController();
  final _coachPhoneController = TextEditingController();
  final _coachEmailController = TextEditingController();

  final List<PickleballPlayer> _players = [];
  String _selectedDuprRating = PickleballScreenKeys.duprRatingUnder35;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  final List<String> _duprRatings = [
    PickleballScreenKeys.duprRatingUnder35,
    PickleballScreenKeys.duprRatingOver4,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.team != null) {
      _teamNameController.text = widget.team!.name;
      _coachNameController.text = widget.team!.coachName;
      _coachPhoneController.text = widget.team!.coachPhone;
      _coachEmailController.text = widget.team!.coachEmail;
      _selectedDuprRating = widget.team!.division;
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
    if (_players.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 1 player allowed for pickleball'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('_addPlayer called'); // Debug print
    showDialog(
      context: context,
      builder:
          (context) => _PickleballPlayerDialog(
            onSave: (player) {
              setState(() {
                _players.add(player);
                _hasUnsavedChanges = true;
              });
              print('Player added: ${player.name}'); // Debug print
              print('Total players: ${_players.length}'); // Debug print
            },
          ),
    );
  }

  void _editPlayer(int index) {
    showDialog(
      context: context,
      builder:
          (context) => _PickleballPlayerDialog(
            player: _players[index],
            onSave: (updatedPlayer) {
              setState(() {
                _players[index] = updatedPlayer;
                _hasUnsavedChanges = true;
              });
            },
          ),
    );
  }

  void _deletePlayer(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Player'),
          content: const Text('Are you sure you want to delete this player?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _players.removeAt(index);
                  _hasUnsavedChanges = true;
                });
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTeam() async {
    if (_isSaving) return; // Prevent rapid clicking

    print('_saveTeam called - validating form'); // Debug print

    if (_formKey.currentState!.validate() && _players.isNotEmpty) {
      setState(() {
        _isSaving = true;
      });
      print('Form validation passed - creating team'); // Debug print

      // Generate unique ID for new teams
      String teamId;
      if (widget.team != null) {
        // Editing existing team - keep same ID
        teamId = widget.team!.id;
        print('Editing existing pickleball team with ID: $teamId');
      } else {
        // Creating new team - generate unique ID with random component
        teamId =
            'pickleball_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().hashCode}';
        print('Creating new pickleball team with ID: $teamId');
      }

      final team = PickleballTeam(
        id: teamId,
        name: _teamNameController.text,
        coachName: _coachNameController.text,
        coachPhone: _coachPhoneController.text,
        coachEmail: _coachEmailController.text,
        players: List.from(_players), // Create a copy of the players list
        registrationDate: widget.team?.registrationDate ?? DateTime.now(),
        division: _selectedDuprRating,
      );
      print('Team created with ${team.players.length} players'); // Debug print
      print(
        'Team players: ${team.players.map((p) => p.name).toList()}',
      ); // Debug print

      // Create default event for pickleball tournament
      const event = Event(
        id: 'pickleball_tournament_2025',
        title: PickleballScreenKeys.tournamentTitle,
        date: PickleballScreenKeys.tournamentDate,
        location: PickleballScreenKeys.tournamentLocation,
        address: PickleballScreenKeys.tournamentAddress,
      );

      print('Navigating to process registration screen'); // Debug print
      print(
        'Team data: name=${team.name}, captain=${team.coachName}, players=${team.players.length}',
      ); // Debug print

      // Add a small delay to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 100));

      // If editing an existing team, call onSave callback
      if (widget.team != null && widget.onSave != null) {
        widget.onSave!(team);
        setState(() {
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
      } else {
        // Navigate to process registration screen for new teams
        if (!mounted) return;

        try {
          Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    print(
                      'Building PickleballProcessRegistrationScreen',
                    ); // Debug print
                    return PickleballProcessRegistrationScreen(
                      team: team,
                      event: event,
                    );
                  },
                ),
              )
              .then((_) {
                // Reset flags after navigation completes
                setState(() {
                  _hasUnsavedChanges = false;
                  _isSaving = false;
                });
                print('Navigation completed, flags reset'); // Debug print
              })
              .catchError((error, stackTrace) {
                print('Navigation error: $error'); // Debug print
                print('Stack trace: $stackTrace'); // Debug print
                if (mounted) {
                  setState(() {
                    _isSaving = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
        } catch (e, stackTrace) {
          print('Exception during navigation: $e'); // Debug print
          print('Stack trace: $stackTrace'); // Debug print
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    } else {
      print('Form validation failed or no players'); // Debug print
      if (_players.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PickleballScreenKeys.addPlayerMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please fill in all required fields',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(PickleballScreenKeys.screenTitle),
        backgroundColor: const Color(0xFF38A169),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team Information Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team Information',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF38A169),
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
                        onChanged: (value) {
                          // Clear validation error when user starts typing
                          if (value.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
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
                          labelText: 'Captain Email',
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedDuprRating,
                        decoration: InputDecoration(
                          labelText: 'DUPR Rating',
                          prefixIcon: const Icon(Icons.star),
                          border: const OutlineInputBorder(),
                        ),
                        items:
                            _duprRatings.map((String rating) {
                              return DropdownMenuItem<String>(
                                value: rating,
                                child: Text(rating),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedDuprRating = newValue!;
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Players Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF38A169),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _players.isNotEmpty ? null : _addPlayer,
                            icon: const Icon(Icons.add),
                            label: Text(
                              _players.isNotEmpty
                                  ? 'Max 1 Player'
                                  : PickleballScreenKeys.addPlayerButton,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _players.isNotEmpty
                                      ? Colors.grey
                                      : const Color(0xFF38A169),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_players.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No players added yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add 1 player to your pickleball team',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
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
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF38A169),
                                  child: Text(
                                    player.name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(player.name),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editPlayer(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deletePlayer(index),
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
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38A169),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            'Next',
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
    );
  }
}

// Pickleball Player Dialog
class _PickleballPlayerDialog extends StatefulWidget {
  final PickleballPlayer? player;
  final Function(PickleballPlayer) onSave;

  const _PickleballPlayerDialog({this.player, required this.onSave});

  @override
  State<_PickleballPlayerDialog> createState() =>
      _PickleballPlayerDialogState();
}

class _PickleballPlayerDialogState extends State<_PickleballPlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.player != null) {
      _nameController.text = widget.player!.name;
      // For pickleball, we'll use a default age since we only store name
      _ageController.text = '25'; // Default age
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
      final player = PickleballPlayer(
        id:
            widget.player?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        duprRating:
            PickleballScreenKeys.duprRatingUnder35, // Default DUPR rating
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
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
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
                const SizedBox(height: 12),
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
