// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/event_service.dart';
import '../models/event.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import '../widgets/simple_app_bar.dart';
import '../widgets/custom_app_bar.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../utils/role_utils.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();
  final TeamService _teamService = TeamService();
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _eventService.initialize();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.loadUsers();
      _users = _authService.users;
    } catch (e) {
      print('Error loading users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Manage Event
          _buildSettingsCard([
            _buildSettingsItem('Manage Event', Icons.event_note, () {
              _navigateToManageEvent();
            }, trailing: Icons.keyboard_arrow_right),
          ]),
          const SizedBox(height: 16),
          // User Management
          _buildSettingsCard([
            _buildSettingsItem('User Management', Icons.people, () {
              _navigateToUserManagement();
            }, trailing: Icons.keyboard_arrow_right),
          ]),
          const SizedBox(height: 16),
          // Team Registered
          _buildSettingsCard([
            _buildSettingsItem('Team Registered', Icons.group, () {
              _showTeamRegisteredDialog();
            }, trailing: Icons.keyboard_arrow_right),
          ]),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    IconData? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        trailing ?? Icons.keyboard_arrow_right,
        color: Colors.grey[400],
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _navigateToManageEvent() {
    final hasEvents = _eventService.events.isNotEmpty;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2196F3),
                          const Color(0xFF2196F3).withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_note,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Manage Events',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create, edit, or delete events',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Action Cards - 3 columns
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.add_circle_outline,
                          title: 'Create',
                          subtitle: 'New Event',
                          color: Colors.green,
                          onTap: () {
                            Navigator.pop(context);
                            _showCreateEventDialog();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.edit_outlined,
                          title: 'Edit',
                          subtitle: 'Event',
                          color: const Color(0xFF2196F3),
                          onTap: () {
                            Navigator.pop(context);
                            _showEditEventDialog();
                          },
                          enabled: hasEvents,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Only show Delete button for owner role
                      if (_authService.currentUser?.role == 'owner')
                        Expanded(
                          child: _buildActionCard(
                            icon: Icons.delete_outline,
                            title: 'Delete',
                            subtitle: 'Event',
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              _showDeleteEventDialog();
                            },
                            enabled: hasEvents,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    Color textColor;
    if (color == Colors.green) {
      textColor = Colors.green[700]!;
    } else if (color == Colors.red) {
      textColor = Colors.red[700]!;
    } else {
      textColor = color;
    }

    final opacity = enabled ? 1.0 : 0.4;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: textColor, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToUserManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => _UserManagementScreen(
              authService: _authService,
              onUserAdded: () => _loadUsers(),
            ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final userCount = _users.where((u) => u.role == RoleUtils.userRole).length;
    final scoringCount =
        _users.where((u) => u.role == RoleUtils.scoringRole).length;
    final ownerCount =
        _users.where((u) => u.role == RoleUtils.ownerRole).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Users',
            userCount.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Scoring',
            scoringCount.toString(),
            Icons.sports_score,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Owners',
            ownerCount.toString(),
            Icons.admin_panel_settings,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _showDeleteEventDialog() {
    final events = _eventService.events;

    if (events.isEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_busy,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Events',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'There are no events to delete.',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red[700],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Delete Event',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Events List
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: events.length,
                      separatorBuilder:
                          (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return FutureBuilder<bool>(
                          future: _eventService.isEventCompleted(event.id),
                          builder: (context, snapshot) {
                            final isCompleted = snapshot.data ?? false;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                          style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                            color: isCompleted ? Colors.grey[600] : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          event.date.toString().split(' ')[0],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.sports,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          event.sportName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                              ),
                                            ),
                                            if (isCompleted) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Completed',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Only show delete button for owner role
                              if (_authService.currentUser?.role == 'owner')
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    // Show confirmation dialog directly without popping
                                    // The confirmation will handle closing all dialogs
                                    _confirmDeleteEvent(event, context);
                                  },
                                ),
                            ],
                          ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showEditEventDialog() {
    final events = _eventService.events;

    if (events.isEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_busy,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Events',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'There are no events to edit.',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF2196F3),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Event',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Events List
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: events.length,
                      separatorBuilder:
                          (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return FutureBuilder<bool>(
                          future: _eventService.isEventCompleted(event.id),
                          builder: (context, snapshot) {
                            final isCompleted = snapshot.data ?? false;
                        return InkWell(
                              onTap: isCompleted
                                  ? null
                                  : () {
                            Navigator.pop(context);
                            _showEditEventForm(event);
                          },
                          borderRadius: BorderRadius.circular(12),
                              child: Opacity(
                                opacity: isCompleted ? 0.6 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                              style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                                color: isCompleted ? Colors.grey[600] : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            event.date.toString().split(' ')[0],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.sports,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            event.sportName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                                  ),
                                                ),
                                                if (isCompleted) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Text(
                                                      'Completed',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                        color: isCompleted ? Colors.grey[300] : Colors.grey[400],
                                ),
                              ],
                                  ),
                            ),
                          ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showEditEventForm(Event event) {
    final titleController = TextEditingController(text: event.title);
    final locationController = TextEditingController(text: event.locationName);
    final addressController = TextEditingController(
      text: event.locationAddress,
    );
    final descriptionController = TextEditingController(text: event.description ?? '');
    // Initialize amount controller with event amount (or "FREE" if null)
    final amountController = TextEditingController(
      text: event.amount == null ? 'FREE' : event.amount.toString(),
    );
    // Add FocusNodes for editable fields
    final titleFocusNode = FocusNode();
    final locationFocusNode = FocusNode();
    final addressFocusNode = FocusNode();
    final descriptionFocusNode = FocusNode();
    final amountFocusNode = FocusNode();
    
    DateTime? selectedDate = event.date;
    String? selectedSport = event.sportName;
    // Error state variables used in UI via StatefulBuilder (linter doesn't detect usage in closures)
    // ignore: unused_local_variable
    bool titleError = false;
    // ignore: unused_local_variable
    bool dateError = false;
    // ignore: unused_local_variable
    bool locationError = false;
    // ignore: unused_local_variable
    bool addressError = false;
    // ignore: unused_local_variable
    bool sportError = false;
    // ignore: unused_local_variable
    bool divisionError = false;
    // ignore: unused_local_variable
    bool amountError = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2196F3,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  color: Color(0xFF2196F3),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Edit Event',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  // Dismiss keyboard first
                                  FocusScope.of(context).unfocus();
                                  // Close dialog
                                  Navigator.pop(context);
                                  // Dispose FocusNodes after dialog closes
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    try {
                                      titleFocusNode.dispose();
                                      locationFocusNode.dispose();
                                      addressFocusNode.dispose();
                                      descriptionFocusNode.dispose();
                                      amountFocusNode.dispose();
                                    } catch (e) {
                                      // FocusNodes may already be disposed, ignore
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        // Form Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Event Name - Editable
                                _buildImageStyleField(
                                  label: 'Event name',
                                  hasError: titleError,
                                  child: TextField(
                                    controller: titleController,
                                    focusNode: titleFocusNode,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter event name',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                    ),
                                    onChanged: (v) {
                                      if (titleError && v.isNotEmpty) {
                                        setDialogState(() => titleError = false);
                                      }
                                    },
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        try {
                                          if (!titleFocusNode.hasFocus) {
                                            titleFocusNode.requestFocus();
                                          }
                                        } catch (e) {
                                          // FocusNode may have been disposed, ignore
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Description - Editable
                                _buildImageStyleField(
                                  label: 'Description',
                                  hasError: false,
                                  child: TextField(
                                    controller: descriptionController,
                                    focusNode: descriptionFocusNode,
                                    minLines: 3,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter event description',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 16,
                                      ),
                                    ),
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        try {
                                          if (!descriptionFocusNode.hasFocus) {
                                            descriptionFocusNode.requestFocus();
                                          }
                                        } catch (e) {
                                          // FocusNode may have been disposed, ignore
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Date - Editable
                                _buildImageStyleField(
                                  label: 'Date',
                                  hasError: dateError,
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate != null && selectedDate!.isAfter(DateTime.now())
                                            ? selectedDate!
                                            : DateTime.now(),
                                        firstDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                                        lastDate: DateTime(2100),
                                        selectableDayPredicate: (day) {
                                          final today = DateTime.now();
                                          final normalizedToday = DateTime(today.year, today.month, today.day);
                                          final normalizedDay = DateTime(day.year, day.month, day.day);
                                          return !normalizedDay.isBefore(normalizedToday);
                                        },
                                      );
                                      if (picked != null) {
                                        setDialogState(() {
                                          selectedDate = picked;
                                          dateError = false;
                                        });
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                                          const SizedBox(width: 12),
                                          Text(
                                            selectedDate != null
                                                ? '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}'
                                                : 'Select date',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: selectedDate != null ? Colors.black87 : Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Location - Editable
                                _buildImageStyleField(
                                  label: 'Location',
                                  hasError: locationError,
                                  child: TextField(
                                    controller: locationController,
                                    focusNode: locationFocusNode,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter location name',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                    ),
                                    onChanged: (v) {
                                      if (locationError && v.isNotEmpty) {
                                        setDialogState(() => locationError = false);
                                      }
                                    },
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        try {
                                          if (!locationFocusNode.hasFocus) {
                                            locationFocusNode.requestFocus();
                                          }
                                        } catch (e) {
                                          // FocusNode may have been disposed, ignore
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Address - Editable
                                _buildImageStyleField(
                                  label: 'Address',
                                  hasError: addressError,
                                  child: TextField(
                                    controller: addressController,
                                    focusNode: addressFocusNode,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter full address',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                    ),
                                    onChanged: (v) {
                                      if (addressError && v.isNotEmpty) {
                                        setDialogState(() => addressError = false);
                                      }
                                    },
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        try {
                                          if (!addressFocusNode.hasFocus) {
                                            addressFocusNode.requestFocus();
                                          }
                                        } catch (e) {
                                          // FocusNode may have been disposed, ignore
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Sport Name - Locked (read-only)
                                _buildImageStyleField(
                                  label: 'Sport name',
                                  hasError: false,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            selectedSport,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.lock_outline,
                                          size: 18,
                                          color: Colors.grey[600],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Amount/Price field - Editable
                                _buildImageStyleField(
                                  label: 'Amount (Required - type "FREE" for free event)',
                                  hasError: amountError,
                                  child: TextField(
                                    controller: amountController,
                                    focusNode: amountFocusNode,
                                    keyboardType: TextInputType.text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter amount (e.g., 350.00) or type "FREE"',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                      prefixText: '\$ ',
                                    ),
                                    onChanged: (value) {
                                      if (amountError && value.trim().isNotEmpty) {
                                        setDialogState(() {
                                          amountError = false;
                                        });
                                      }
                                    },
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        try {
                                          if (!amountFocusNode.hasFocus) {
                                            amountFocusNode.requestFocus();
                                          }
                                        } catch (e) {
                                          // FocusNode may have been disposed, ignore
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                        // Update Button
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                // Read values before any potential disposal
                                final titleText = titleController.text.trim();
                                final locationText = locationController.text.trim();
                                final addressText = addressController.text.trim();
                                final descriptionText = descriptionController.text.trim();
                                final amountText = amountController.text.trim();

                                // Validate all fields
                                final hasTitleError = titleText.isEmpty;
                                final hasDateError = selectedDate == null;
                                final hasLocationError = locationText.isEmpty;
                                final hasAddressError = addressText.isEmpty;
                                // Amount is required - must be "FREE" or a valid number
                                bool hasAmountError = false;
                                if (amountText.isEmpty) {
                                  hasAmountError = true;
                                } else if (amountText.toUpperCase() != 'FREE') {
                                  final parsedAmount = double.tryParse(amountText);
                                  if (parsedAmount == null || parsedAmount <= 0) {
                                    hasAmountError = true;
                                  }
                                }

                                setDialogState(() {
                                  titleError = hasTitleError;
                                  dateError = hasDateError;
                                  locationError = hasLocationError;
                                  addressError = hasAddressError;
                                  amountError = hasAmountError;
                                });

                                if (hasTitleError || hasDateError || hasLocationError || hasAddressError || hasAmountError) {
                                  return;
                                }

                                // Parse amount - "FREE" means null, otherwise parse as number
                                double? amount;
                                if (amountText.toUpperCase() == 'FREE') {
                                  amount = null; // Free event
                                } else if (amountText.isNotEmpty) {
                                  final parsedAmount = double.tryParse(amountText);
                                  if (parsedAmount != null && parsedAmount > 0) {
                                    amount = parsedAmount;
                                  }
                                }

                                // Update all editable fields
                                final updatedEvent = event.copyWith(
                                  title: titleText,
                                  date: selectedDate!,
                                  locationName: locationText,
                                  locationAddress: addressText,
                                  description: descriptionText.isEmpty ? null : descriptionText,
                                  amount: amount,
                                );

                                // Dismiss keyboard before saving
                                FocusScope.of(context).unfocus();
                                
                                final success = await _eventService.updateEvent(
                                  updatedEvent,
                                );

                                if (mounted) {
                                  Navigator.pop(context);
                                  // Dispose FocusNodes after dialog closes
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    try {
                                      titleFocusNode.dispose();
                                      locationFocusNode.dispose();
                                      addressFocusNode.dispose();
                                      descriptionFocusNode.dispose();
                                      amountFocusNode.dispose();
                                    } catch (e) {
                                      // FocusNodes may already be disposed, ignore
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Event updated successfully!'
                                            : 'Failed to update event.',
                                      ),
                                      backgroundColor:
                                          success ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Update',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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

  Widget _buildImageStyleField({
    required String label,
    required Widget child,
    bool hasError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hasError ? Colors.red : Colors.grey[700],
            ),
          ),
        ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey[200]!,
              width: hasError ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildImprovedFormSection({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
              Icon(icon, size: 18, color: const Color(0xFF2196F3)),
                        const SizedBox(width: 8),
              Text(
                label,
                            style: TextStyle(
                              fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
        Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: child,
        ),
      ],
    );
  }

  Widget _buildFormSection({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showTeamRegisteredDialog() async {
    // Load teams
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();

    final basketballTeams = _teamService.teams;
    final pickleballTeams = _pickleballTeamService.teams;

    // Group teams by sport
    final Map<String, List<dynamic>> teamsBySport = {};

    if (basketballTeams.isNotEmpty) {
      teamsBySport['Basketball'] = basketballTeams;
    }
    if (pickleballTeams.isNotEmpty) {
      teamsBySport['Pickleball'] = pickleballTeams;
    }

    if (teamsBySport.isEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('No Teams Registered'),
              content: const Text(
                'There are no teams registered for any sport.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Team Registered'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: teamsBySport.length,
                itemBuilder: (context, index) {
                  final sportName = teamsBySport.keys.elementAt(index);
                  final teams = teamsBySport[sportName]!;

                  return ExpansionTile(
                    title: Text(
                      '$sportName (${teams.length} teams)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                              fontSize: 16,
                      ),
                    ),
                    children:
                        teams.map((team) {
                          return ListTile(
                            leading: const Icon(Icons.group),
                            title: Text(team.name),
                            subtitle: Text('Division: ${team.division}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                // Confirm deletion
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Team'),
                                    content: Text('Are you sure you want to delete "${team.name}"? This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirmed == true) {
                                  // Delete the team
                                  if (sportName == 'Basketball') {
                                    await _teamService.deleteTeam(team.id);
                                  } else if (sportName == 'Pickleball') {
                                    await _pickleballTeamService.deleteTeam(team.id);
                                  }
                                  
                                  // Reload teams and refresh dialog
      await _teamService.loadTeams();
      await _pickleballTeamService.loadTeams();
                                  if (mounted) {
                                    Navigator.pop(context); // Close current dialog
                                    _showTeamRegisteredDialog(); // Reopen with updated data
                                  }
                                }
                              },
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final titleFocusNode = FocusNode();
    final locationFocusNode = FocusNode();
    final addressFocusNode = FocusNode();
    final descriptionFocusNode = FocusNode();
    final amountFocusNode = FocusNode();
    DateTime? selectedDate;
    String? selectedSport;
    String? selectedDivision;
    bool titleError = false;
    bool dateError = false;
    bool locationError = false;
    bool addressError = false;
    bool sportError = false;
    bool divisionError = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool amountError = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Create Event',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                // Dismiss keyboard first
                                FocusScope.of(context).unfocus();
                                // Close dialog first
                                Navigator.pop(context);
                                // Dispose controllers after dialog animation completes (longer delay)
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  try {
                                    titleController.dispose();
                                    locationController.dispose();
                                    addressController.dispose();
                                    descriptionController.dispose();
                                    amountController.dispose();
                                    titleFocusNode.dispose();
                                    locationFocusNode.dispose();
                                    addressFocusNode.dispose();
                                    descriptionFocusNode.dispose();
                                    amountFocusNode.dispose();
                                  } catch (e) {
                                    // Controllers may already be disposed, ignore
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),
                                _buildImageStyleField(
                                  label: 'Event name',
                                  hasError: titleError,
                                  child: TextField(
                                    controller: titleController,
                                    focusNode: titleFocusNode,
                                    decoration: InputDecoration(
                                      hintText: 'Enter event name',
                                      border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      onChanged: (v) {
                        if (titleError && v.isNotEmpty) {
                          setDialogState(() => titleError = false);
                                      }
                                    },
                                    onTap: () {
                                      // Dismiss other keyboards when tapping this field
                                      FocusScope.of(context).unfocus();
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        try {
                                          if (!titleFocusNode.hasFocus) {
                                            titleFocusNode.requestFocus();
                                          }
                                        } catch (e) {
                                          // FocusNode may have been disposed, ignore
                                        }
                                      });
                                    },
                                  ),
                                ),
                  const SizedBox(height: 16),
                                _buildImageStyleField(
                                  label: 'Date',
                                  hasError: dateError,
                                  child: InkWell(
                                    onTap: () async {
                        final picked = await showDatePicker(
                                        context: context,
                          initialDate: selectedDate != null && selectedDate!.isAfter(DateTime.now())
                              ? selectedDate!
                              : DateTime.now(),
                          firstDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                          lastDate: DateTime(2100),
                          selectableDayPredicate: (day) {
                            final today = DateTime.now();
                            final normalizedToday = DateTime(today.year, today.month, today.day);
                            final normalizedDay = DateTime(day.year, day.month, day.day);
                            return !normalizedDay.isBefore(normalizedToday);
                          },
                        );
                        if (picked != null) {
                                        setDialogState(() {
                            selectedDate = picked;
                                          dateError = false;
                                        });
                                      }
                                    },
                                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                      child: Row(
                                        children: [
                            Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Text(
                                              selectedDate != null
                                  ? '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}'
                                                  : 'Select date',
                                              style: TextStyle(
                                                fontSize: 16,
                                color: selectedDate != null ? Colors.black87 : Colors.grey[400],
                              ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                  const SizedBox(height: 16),
                                _buildImageStyleField(
                                  label: 'Location',
                                  hasError: locationError,
                                  child: TextField(
                                    controller: locationController,
                                    focusNode: locationFocusNode,
                                    decoration: InputDecoration(
                                      hintText: 'Enter location name',
                                      border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      onChanged: (v) {
                        if (locationError && v.isNotEmpty) {
                          setDialogState(() => locationError = false);
                                      }
                                    },
                                    onTap: () {
                                      // Dismiss other keyboards when tapping this field
                                      FocusScope.of(context).unfocus();
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        try {
                                          if (!locationFocusNode.hasFocus) {
                                            locationFocusNode.requestFocus();
                                          }
                                        } catch (e) {
                                          // FocusNode may have been disposed, ignore
                                        }
                                      });
                                    },
                                  ),
                                ),
                  const SizedBox(height: 16),
                                    _buildImageStyleField(
                                      label: 'Address',
                                      hasError: addressError,
                                      child: TextField(
                                        controller: addressController,
                                        focusNode: addressFocusNode,
                                        decoration: InputDecoration(
                                          hintText: 'Enter full address',
                                          border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      onChanged: (v) {
                        if (addressError && v.isNotEmpty) {
                          setDialogState(() => addressError = false);
                        }
                                        },
                                        onTap: () {
                                          // Dismiss other keyboards when tapping this field
                                          FocusScope.of(context).unfocus();
                                          Future.delayed(const Duration(milliseconds: 100), () {
                                            try {
                                              if (!addressFocusNode.hasFocus) {
                                                addressFocusNode.requestFocus();
                                              }
                                            } catch (e) {
                                              // FocusNode may have been disposed, ignore
                                            }
                                          });
                                        },
                                      ),
                                    ),
                  const SizedBox(height: 16),
                  _buildImageStyleField(
                    label: 'Description',
                    hasError: false,
                    child: TextField(
                      controller: descriptionController,
                      focusNode: descriptionFocusNode,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Enter event description',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      onTap: () {
                        // Dismiss other keyboards when tapping this field
                        FocusScope.of(context).unfocus();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          try {
                            if (!descriptionFocusNode.hasFocus) {
                              descriptionFocusNode.requestFocus();
                            }
                          } catch (e) {
                            // FocusNode may have been disposed, ignore
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                                _buildImageStyleField(
                                  label: 'Sport name',
                                  hasError: sportError,
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => Dialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                            children: [
                                  const Text('Select Sport', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 20),
                                  _buildSportPickItem(dialogContext, 'Basketball', Icons.sports_basketball, () {
                                    Navigator.pop(dialogContext);
                                                      setDialogState(() {
                                      selectedSport = 'Basketball';
                                      selectedDivision = null; // Clear division when sport changes
                                                        sportError = false;
                                      divisionError = false;
                                    });
                                  }),
                                  const SizedBox(height: 12),
                                  _buildSportPickItem(dialogContext, 'Pickleball', Icons.sports_tennis, () {
                                    Navigator.pop(dialogContext);
                                                    setDialogState(() {
                                      selectedSport = 'Pickleball';
                                      selectedDivision = null; // Clear division when sport changes
                                      sportError = false;
                                      divisionError = false;
                                    });
                                  }, color: Colors.green),
                                  const SizedBox(height: 12),
                                  _buildSportPickItem(dialogContext, 'Soccer', Icons.sports_soccer, () {
                                    Navigator.pop(dialogContext);
                                                                setDialogState(() {
                                      selectedSport = 'Soccer';
                                      selectedDivision = null; // Clear division when sport changes
                                      sportError = false;
                                      divisionError = false;
                                    });
                                  }, color: Colors.blueGrey),
                                  const SizedBox(height: 12),
                                  _buildSportPickItem(dialogContext, 'Volleyball', Icons.sports_volleyball, () {
                                    Navigator.pop(dialogContext);
                                    setDialogState(() {
                                      selectedSport = 'Volleyball';
                                      selectedDivision = null; // Clear division when sport changes
                                      sportError = false;
                                      divisionError = false;
                                    });
                                  }, color: Colors.deepPurple),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                                                child: Row(
                                                                  children: [
                            Expanded(
                                                                      child: Text(
                                selectedSport ?? 'Select sport',
                                                                        style: TextStyle(
                                  fontSize: 16,
                                  color: selectedSport != null ? Colors.black87 : Colors.grey[400],
                                                                        ),
                                                                      ),
                                                                    ),
                            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                  ),
                  // Division selection - only show for Basketball or Pickleball
                  if (selectedSport == 'Basketball' || selectedSport == 'Pickleball') ...[
                    const SizedBox(height: 16),
                    _buildImageStyleField(
                      label: 'Division',
                      hasError: divisionError,
                      child: InkWell(
                                                              onTap: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => Dialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Select Division', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 20),
                                    // Basketball divisions
                                    if (selectedSport == 'Basketball') ...[
                                      _buildDivisionPickItem(dialogContext, 'Youth (18 or under)', () {
                                        Navigator.pop(dialogContext);
                                        setDialogState(() {
                                          selectedDivision = 'Youth (18 or under)';
                                          divisionError = false;
                                        });
                                      }),
                                      const SizedBox(height: 12),
                                      _buildDivisionPickItem(dialogContext, 'Adult 18+', () {
                                        Navigator.pop(dialogContext);
                                        setDialogState(() {
                                          selectedDivision = 'Adult 18+';
                                          divisionError = false;
                                        });
                                      }),
                                    ],
                                    // Pickleball divisions - only 3.5 or under and 4.0 or above
                                    if (selectedSport == 'Pickleball') ...[
                                      _buildDivisionPickItem(dialogContext, '3.5 or under', () {
                                        Navigator.pop(dialogContext);
                                        setDialogState(() {
                                          selectedDivision = '3.5 or under';
                                          divisionError = false;
                                        });
                                      }),
                                      const SizedBox(height: 12),
                                      _buildDivisionPickItem(dialogContext, '4.0 or above', () {
                                        Navigator.pop(dialogContext);
                                        setDialogState(() {
                                          selectedDivision = '4.0 or above';
                                          divisionError = false;
                                        });
                                      }),
                                    ],
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                              );
                                            },
                                            child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                  selectedDivision ?? 'Select division',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                    color: selectedDivision != null ? Colors.black87 : Colors.grey[400],
                                                      ),
                                                    ),
                                                  ),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          ),
                                ),
                  ],
                  // Amount field - Required: user must type "FREE" or enter a value (shown for all sports)
                  const SizedBox(height: 16),
                  _buildImageStyleField(
                    label: 'Amount (Required - type "FREE" for free event)',
                    hasError: amountError,
                    child: TextField(
                      controller: amountController,
                      focusNode: amountFocusNode,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Enter amount (e.g., 350.00) or type "FREE"',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        prefixText: '\$ ',
                      ),
                      onChanged: (v) {
                        if (amountError && v.trim().isNotEmpty) {
                          setDialogState(() => amountError = false);
                        }
                      },
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          try {
                            if (!amountFocusNode.hasFocus) {
                              amountFocusNode.requestFocus();
                            }
                          } catch (e) {
                            // FocusNode may have been disposed, ignore
                          }
                        });
                      },
                    ),
                  ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                // Dismiss keyboard first
                                FocusScope.of(context).unfocus();
                                // Close dialog first
                                Navigator.pop(context);
                                // Dispose controllers after dialog animation completes (longer delay)
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  try {
                                    titleController.dispose();
                                    locationController.dispose();
                                    addressController.dispose();
                                    descriptionController.dispose();
                                    amountController.dispose();
                                    titleFocusNode.dispose();
                                    locationFocusNode.dispose();
                                    addressFocusNode.dispose();
                                    descriptionFocusNode.dispose();
                                    amountFocusNode.dispose();
                                  } catch (e) {
                                    // Controllers may already be disposed, ignore
                                  }
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                // Read values before any potential disposal
                                final titleText = titleController.text.trim();
                                final locationText = locationController.text.trim();
                                final addressText = addressController.text.trim();
                                final descriptionText = descriptionController.text.trim();
                                final amountText = amountController.text.trim();

                                // Check validation errors
                                final hasTitleError = titleText.isEmpty;
                                final hasDateError = selectedDate == null;
                                final hasLocationError = locationText.isEmpty;
                                final hasAddressError = addressText.isEmpty;
                                final hasSportError = (selectedSport == null || selectedSport!.trim().isEmpty);
                                // Division is required only for Basketball and Pickleball
                                final hasDivisionError = (selectedSport == 'Basketball' || selectedSport == 'Pickleball') && 
                                                 (selectedDivision == null || selectedDivision!.trim().isEmpty);
                                // Amount is required - must be "FREE" or a valid number
                                bool hasAmountError = false;
                                if (amountText.isEmpty) {
                                  hasAmountError = true;
                                } else if (amountText.toUpperCase() != 'FREE') {
                                  final parsedAmount = double.tryParse(amountText);
                                  if (parsedAmount == null || parsedAmount <= 0) {
                                    hasAmountError = true;
                                  }
                                }
                                
                                setDialogState(() {
                                  titleError = hasTitleError;
                                  dateError = hasDateError;
                                  locationError = hasLocationError;
                                  addressError = hasAddressError;
                                  sportError = hasSportError;
                                  divisionError = hasDivisionError;
                                  amountError = hasAmountError;
                                });
                                
                                if (hasTitleError || hasDateError || hasLocationError || hasAddressError || hasSportError || hasDivisionError || hasAmountError) return;

                                // Parse amount - "FREE" means null, otherwise parse as number
                                double? amount;
                                if (amountText.toUpperCase() == 'FREE') {
                                  amount = null; // Free event
                                } else if (amountText.isNotEmpty) {
                                  final parsedAmount = double.tryParse(amountText);
                                  if (parsedAmount != null && parsedAmount > 0) {
                                    amount = parsedAmount;
                                  }
                                }

                                final ok = await _eventService.createEvent(
                                  title: titleText,
                                  date: selectedDate!,
                                  locationName: locationText,
                                  locationAddress: addressText,
                                  sportName: selectedSport!.trim(),
                                  description: descriptionText.isEmpty ? null : descriptionText,
                                  division: selectedDivision,
                                  amount: amount,
                                );
                                if (ok) {
                                  // Dismiss keyboard first
                                  FocusScope.of(context).unfocus();
                                  // Close dialog first
                                  Navigator.pop(context);
                                  // Dispose controllers after dialog animation completes (longer delay)
                                  Future.delayed(const Duration(milliseconds: 500), () {
                                    try {
                                      titleController.dispose();
                                      locationController.dispose();
                                      addressController.dispose();
                                      descriptionController.dispose();
                                      amountController.dispose();
                                      titleFocusNode.dispose();
                                      locationFocusNode.dispose();
                                      addressFocusNode.dispose();
                                      descriptionFocusNode.dispose();
                                      amountFocusNode.dispose();
                                    } catch (e) {
                                      // Controllers may already be disposed, ignore
                                    }
                                  });
                                  await _eventService.initialize();
                                  if (mounted) {
                                    setState(() {});
                                    // Show success snackbar
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Event created successfully'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Create'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            );
          },
        );
      },
    );
  }

  Widget _buildSportPickItem(BuildContext dialogContext, String label, IconData icon, VoidCallback onTap, {Color color = const Color(0xFF2196F3)}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
          color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
          child: Row(
            children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildDivisionPickItem(BuildContext dialogContext, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
        child: Row(
        children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Separate widget for the "I CONFIRM" dialog to properly manage TextEditingController lifecycle
  Widget _ConfirmDeleteDialog({
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return _ConfirmDeleteDialogWidget(
      onConfirm: onConfirm,
      onCancel: onCancel,
    );
  }

  void _confirmDeleteEvent(Event event, BuildContext dialogContext) async {
    // Get the admin panel context before showing nested dialogs
    // This context is from the AdminPanelScreen state
    final adminContext = context;
    
    // Check if event is completed - if yes, require "I CONFIRM" text input first
    final isCompleted = await _eventService.isEventCompleted(event.id);
    
    if (isCompleted) {
      // Show "I CONFIRM" confirmation dialog first for completed events
      final confirmResult = await showDialog<bool>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (confirmContext) {
          return _ConfirmDeleteDialog(
            onConfirm: () => Navigator.pop(confirmContext, true),
            onCancel: () => Navigator.pop(confirmContext, false),
          );
        },
      );
      
      // If user cancelled or didn't confirm, don't proceed
      if (confirmResult != true) {
        return;
      }
      
      // Small delay after first confirmation
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Show final confirmation dialog
    showDialog(
      context: dialogContext,
      builder: (finalConfirmContext) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(finalConfirmContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Close the confirmation dialog first
              if (finalConfirmContext.mounted) {
                Navigator.pop(finalConfirmContext);
              }
              
              // Small delay to ensure dialog closes
              await Future.delayed(const Duration(milliseconds: 100));
              
              try {
                // Delete all teams linked to this event
                await TeamService().deleteTeamsByEventId(event.id);
                await PickleballTeamService().deleteTeamsByEventId(event.id);
                // Now delete the event
                final ok = await _eventService.deleteEvent(event.id);
                
                if (ok) {
                  // Reload events to ensure deletion is reflected
                  await _eventService.initialize();
                }
                
                // Close all dialogs in sequence: "Delete Event" dialog, then "Manage Events" dialog
                if (adminContext.mounted) {
                  // Close "Delete Event" dialog
                  if (dialogContext.mounted) {
                    final navigator = Navigator.of(dialogContext, rootNavigator: false);
                    if (navigator.canPop()) {
                      navigator.pop();
                      // Wait for dialog to close
                      await Future.delayed(const Duration(milliseconds: 100));
                    }
                  }
                  
                  // Close "Manage Events" dialog to return to admin panel
                  final adminNavigator = Navigator.of(adminContext, rootNavigator: false);
                  if (adminNavigator.canPop()) {
                    adminNavigator.pop();
                    // Wait for dialog to close
                    await Future.delayed(const Duration(milliseconds: 100));
                  }
                  
                  // Refresh the admin panel state
                  if (mounted) {
                    setState(() {});
                  }
                  
                  // Show message on the admin panel screen
                  if (adminContext.mounted) {
                    ScaffoldMessenger.of(adminContext).showSnackBar(
                      SnackBar(
                        content: Text(ok 
                          ? 'Event "${event.title}" deleted successfully'
                          : 'Error deleting event'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } catch (e) {
                // Close all dialogs and show error
                if (adminContext.mounted) {
                  // Close "Delete Event" dialog
                  if (dialogContext.mounted) {
                    final navigator = Navigator.of(dialogContext, rootNavigator: false);
                    if (navigator.canPop()) {
                      navigator.pop();
                      await Future.delayed(const Duration(milliseconds: 100));
                    }
                  }
                  
                  // Close "Manage Events" dialog
                  final adminNavigator = Navigator.of(adminContext, rootNavigator: false);
                  if (adminNavigator.canPop()) {
                    adminNavigator.pop();
                  }
                  
                  if (adminContext.mounted) {
                    ScaffoldMessenger.of(adminContext).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting event: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _UserManagementScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onUserAdded;

  const _UserManagementScreen({
    required this.authService,
    required this.onUserAdded,
  });

  @override
  State<_UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<_UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.authService.loadUsers();
      _users = widget.authService.users;
    } catch (e) {
      print('Error loading users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(
        title: 'User Management',
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildUsersSection(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final userCount = _users.where((u) => u.role == RoleUtils.userRole).length;
    final scoringCount =
        _users.where((u) => u.role == RoleUtils.scoringRole).length;
    final ownerCount =
        _users.where((u) => u.role == RoleUtils.ownerRole).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Users',
            userCount.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Scoring',
            scoringCount.toString(),
            Icons.sports_score,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Owners',
            ownerCount.toString(),
            Icons.admin_panel_settings,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'User Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._users.map((user) => _buildUserCard(user)),
      ],
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                RoleUtils.getRoleDisplayName(user.role),
                style: TextStyle(
                  color: _getRoleColor(user.role),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(value, user),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'edit_role',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit Role'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete User', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'user':
        return Colors.blue;
      case 'scoring':
        return Colors.orange;
      case 'owner':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = RoleUtils.userRole;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New User'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        RoleUtils.getAssignableRoles('owner').map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(RoleUtils.getRoleDisplayName(role)),
                          );
                        }).toList(),
                    onChanged: (value) {
                      selectedRole = value!;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _addUser(
                  nameController.text,
                  emailController.text,
                  passwordController.text,
                  phoneController.text,
                  selectedRole,
                  usernameController.text,
                ),
                child: const Text('Add User'),
              ),
            ],
          ),
    );
  }

  Future<void> _addUser(
    String name,
    String email,
    String password,
    String phone,
    String role,
    String username,
  ) async {
    try {
      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        password: password, // Temporary password, user must change on first login
        name: name,
        username: (username.isNotEmpty ? username : email.split('@')[0]),
        phone: phone,
        role: role,
        createdAt: DateTime.now(),
        needsPasswordSetup: true, // User needs to set password on first login
      );

      await widget.authService.addUser(user);
      await _loadUsers();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onUserAdded();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleUserAction(String action, User user) {
    switch (action) {
      case 'edit_role':
        _showEditRoleDialog(user);
        break;
      case 'delete':
        _showDeleteUserDialog(user);
        break;
    }
  }

  void _showEditRoleDialog(User user) {
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit User Role'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('User: ${user.name}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      RoleUtils.getAssignableRoles('owner').map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(RoleUtils.getRoleDisplayName(role)),
                        );
                      }).toList(),
                  onChanged: (value) {
                    selectedRole = value!;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _updateUserRole(user, selectedRole),
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateUserRole(User user, String newRole) async {
    try {
      final updatedUser = user.copyWith(role: newRole);
      await widget.authService.updateUser(updatedUser);
      await _loadUsers();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User role updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteUserDialog(User user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete User'),
            content: Text('Are you sure you want to delete ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _deleteUser(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteUser(User user) async {
    try {
      await widget.authService.deleteUser(user.id);
      await _loadUsers();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// StatefulWidget for the "I CONFIRM" deletion dialog
class _ConfirmDeleteDialogWidget extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmDeleteDialogWidget({
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_ConfirmDeleteDialogWidget> createState() => _ConfirmDeleteDialogWidgetState();
}

class _ConfirmDeleteDialogWidgetState extends State<_ConfirmDeleteDialogWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmationText = _controller.text.trim();
    final isConfirmValid = confirmationText == 'I CONFIRM';

    return AlertDialog(
      title: const Text(
        'Confirm Deletion',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This event is already completed. Deleting it will permanently remove all associated data.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          const Text(
            'To confirm deletion, please type "I CONFIRM" (all caps) below:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Type I CONFIRM',
              border: const OutlineInputBorder(),
              errorText: confirmationText.isNotEmpty && !isConfirmValid
                  ? 'Must be exactly "I CONFIRM"'
                  : null,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isConfirmValid ? Colors.red : Colors.grey,
            foregroundColor: Colors.white,
          ),
          onPressed: isConfirmValid ? widget.onConfirm : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
