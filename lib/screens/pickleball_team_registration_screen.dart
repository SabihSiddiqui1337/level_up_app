// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pickleball_team.dart';
import '../models/pickleball_player.dart';
import '../models/event.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/pickleball_team_service.dart';
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
  final Event? event; // Event being registered for

  const PickleballTeamRegistrationScreen({super.key, this.team, this.onSave, this.event});

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
  final AuthService _authService = AuthService();

  final List<PickleballPlayer> _players = [];
  String _selectedDuprRating = PickleballScreenKeys.duprRatingUnder35;
  bool _isSaving = false;

  final List<String> _duprRatings = [
    PickleballScreenKeys.duprRatingUnder35,
    PickleballScreenKeys.duprRatingOver4,
  ];

  @override
  void initState() {
    super.initState();
    // Set division from event if available
    if (widget.event?.division != null) {
      _selectedDuprRating = widget.event!.division!;
    } else if (widget.team != null) {
      _selectedDuprRating = widget.team!.division;
    }
    
    if (widget.team != null) {
      _teamNameController.text = widget.team!.name;
      _coachNameController.text = widget.team!.coachName;
      _coachPhoneController.text = widget.team!.coachPhone;
      _coachEmailController.text = widget.team!.coachEmail;
      _players.addAll(widget.team!.players);
    }
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _coachNameController.dispose();
    _coachPhoneController.dispose();
    _coachEmailController.dispose();
    super.dispose();
  }

  bool _isFormComplete() {
    // Check if all required fields are filled
    final isManagement = _authService.isManagement;

    if (isManagement) {
      // For management users, only require team name
      return _teamNameController.text.trim().isNotEmpty;
    } else {
      // For regular users, require all fields
      return _teamNameController.text.trim().isNotEmpty &&
          _coachNameController.text.trim().isNotEmpty &&
          _coachPhoneController.text.trim().isNotEmpty &&
          _coachEmailController.text.trim().isNotEmpty &&
          _players.isNotEmpty;
    }
  }

  void _addPlayer() {
    if (_players.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 1 player allowed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => _PickleballPlayerDialog(
            fixedDuprRating: widget.event?.division ?? _selectedDuprRating,
            onSave: (player) {
              setState(() {
                _players.add(player);
              });
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
            fixedDuprRating: widget.event?.division ?? _selectedDuprRating,
            onSave: (updatedPlayer) {
              setState(() {
                _players[index] = updatedPlayer;
              });
            },
          ),
    );
  }

  void _deletePlayer(int index) {
    setState(() {
      _players.removeAt(index);
    });
  }

  Future<void> _saveTeam() async {
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

      // Generate unique ID for new teams
      String teamId;
      if (widget.team != null) {
        // Editing existing team - keep same ID
        teamId = widget.team!.id;
      } else {
        // Creating new team - generate unique ID with random component
        teamId =
            'pickleball_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().hashCode}';
      }

      final currentUser = _authService.currentUser;
      final isAdmin =
          currentUser?.role == 'scoring' || currentUser?.role == 'owner';
      final isManagement = _authService.isManagement;

      final team = PickleballTeam(
        id: teamId,
        name: _teamNameController.text,
        coachName: _coachNameController.text,
        coachPhone: isManagement ? '000-000-0000' : _coachPhoneController.text,
        coachEmail: isManagement ? 'management@levelupsports.com' : _coachEmailController.text,
        players: List.from(_players), // Create a copy of the players list
        registrationDate: widget.team?.registrationDate ?? DateTime.now(),
        division: widget.event?.division ?? _selectedDuprRating,
        createdByUserId: currentUser?.id,
        isPrivate:
            !isAdmin && !isManagement,
        eventId: widget.event?.id ?? widget.team?.eventId ?? '',
      );

      // Create default event for pickleball tournament
      final event = Event(
        id: 'pickleball_tournament_2025',
        title: PickleballScreenKeys.tournamentTitle,
        date: DateTime(2025, 11, 8), // Convert string date to DateTime
        locationName: PickleballScreenKeys.tournamentLocation,
        locationAddress: PickleballScreenKeys.tournamentAddress,
        sportName: 'Pickleball',
        createdAt: DateTime.now(),
      );

      // Navigate to process registration screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return PickleballProcessRegistrationScreen(
              team: team,
              event: event,
            );
          },
        ),
      ).then((_) {
        // Reset saving state when returning
        setState(() {
          _isSaving = false;
        });
      });
    } else {
      setState(() {
        _isSaving = false;
      });
      if (_players.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PickleballScreenKeys.addPlayerMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveManagementTeam() async {
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      // Use existing team ID if updating, generate new one if creating
      final teamId =
          widget.team?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final currentUser = _authService.currentUser;
      final isAdmin = _authService.isManagement ||
          currentUser?.role == 'scoring' || currentUser?.role == 'owner';

      final team = PickleballTeam(
        id: teamId,
        name: _teamNameController.text,
        coachName: 'Management Created',
        coachPhone: '000-000-0000',
        coachEmail: 'management@levelupsports.com',
        players: [], // Empty players list for management
        registrationDate: widget.team?.registrationDate ?? DateTime.now(),
        division: widget.event?.division ?? _selectedDuprRating,
        createdByUserId: currentUser?.id,
        // Admin/management teams should be public (visible to all)
        // Regular user teams should be private (visible only to creator)
        isPrivate: !isAdmin,
        eventId: widget.event?.id ?? widget.team?.eventId ?? '',
      );

      // Save the team
      if (widget.onSave != null) {
        widget.onSave!(team);
      } else {
        // Persist via service when no callback is provided
        await PickleballTeamService().addTeam(team);
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
          _selectedDuprRating = PickleballScreenKeys.duprRatingUnder35;
        });
      }

      setState(() {
        _isSaving = false;
      });
    } else {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManagement = _authService.isManagement;

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
              if (isManagement) _buildManagementForm() else _buildRegularForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementForm() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event?.title ?? 'Register Team',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF38A169),
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
                prefixIcon: Icon(Icons.sports_tennis),
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

            // DUPR Rating Field - Show as read-only text if event has division, otherwise dropdown
            widget.event?.division != null
                ? TextFormField(
                    initialValue: widget.event!.division,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'DUPR Rating (Preset)',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      suffixIcon: Icon(Icons.info_outline, color: Colors.grey[500], size: 20),
                    ),
                    readOnly: true,
                  )
                : DropdownButtonFormField<String>(
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
                    onChanged: (value) {
                      setState(() {
                        _selectedDuprRating = value!;
                      });
                    },
                  ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveManagementTeam,
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
                          widget.team == null ? 'Create Team' : 'Update Team',
                          style: TextStyle(
                            fontSize: 16,
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

  Widget _buildRegularForm() {
    return Column(
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                      return 'Please enter phone number';
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
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // DUPR Rating Field - Show as read-only text if event has division, otherwise dropdown
                widget.event?.division != null
                    ? TextFormField(
                        initialValue: widget.event!.division,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'DUPR Rating (Preset)',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          suffixIcon: Icon(Icons.info_outline, color: Colors.grey[500], size: 20),
                        ),
                        readOnly: true,
                      )
                    : DropdownButtonFormField<String>(
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
                        onChanged: (value) {
                          setState(() {
                            _selectedDuprRating = value!;
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
                      'Players',
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
                            ? 'Max Players Added'
                            : 'Add Player',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _players.isNotEmpty
                                ? Colors.grey[400]
                                : const Color(0xFF38A169),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_players.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
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
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF38A169),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(player.name),
                          subtitle: Text('DUPR: ${player.duprRating}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editPlayer(index),
                                icon: const Icon(Icons.edit),
                                color: const Color(0xFF2196F3),
                              ),
                              IconButton(
                                onPressed: () => _deletePlayer(index),
                                icon: const Icon(Icons.delete),
                                color: Colors.red,
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
            onPressed: (_isSaving || !_isFormComplete()) ? null : _saveTeam,
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
                      widget.team == null ? 'Next' : 'Update Team',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
          ),
        ),
      ],
    );
  }
}

// Pickleball Player Dialog
class _PickleballPlayerDialog extends StatefulWidget {
  final PickleballPlayer? player;
  final Function(PickleballPlayer) onSave;
  final String fixedDuprRating; // Enforced DUPR rating (from team/event division)

  const _PickleballPlayerDialog({this.player, required this.onSave, required this.fixedDuprRating});

  @override
  State<_PickleballPlayerDialog> createState() =>
      _PickleballPlayerDialogState();
}

class _PickleballPlayerDialogState extends State<_PickleballPlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedDuprRating = PickleballScreenKeys.duprRatingUnder35;

  @override
  void initState() {
    super.initState();
    // Always lock the rating to the provided fixed rating
    _selectedDuprRating = widget.fixedDuprRating;
    if (widget.player != null) {
      _nameController.text = widget.player!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.player == null ? 'Add Player' : 'Edit Player'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Player Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter player name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Show locked DUPR rating (read-only)
              TextFormField(
                initialValue: _selectedDuprRating,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'DUPR Rating (Preset)',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  suffixIcon: Icon(Icons.info_outline, color: Colors.grey[500], size: 20),
                ),
                readOnly: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final player = PickleballPlayer(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text,
                duprRating: _selectedDuprRating,
              );
              widget.onSave(player);
              Navigator.of(context).pop();
            }
          },
          child: Text(widget.player == null ? 'Add Player' : 'Update Player'),
        ),
      ],
    );
  }
}
