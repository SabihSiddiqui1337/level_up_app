import 'package:flutter/material.dart';
import '../models/event.dart';
import '../widgets/custom_app_bar.dart';

class EventDetailScreen extends StatelessWidget {
  final Event event;
  final VoidCallback? onHomePressed;
  final VoidCallback onSignUp;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.onSignUp,
    this.onHomePressed,
  });

  String? _imageForSport(String sportName) {
    final s = sportName.toLowerCase();
    if (s.contains('basketball')) return 'assets/basketball.png';
    if (s.contains('pickleball') || s.contains('pickelball')) return 'assets/pickelball.png';
    if (s.contains('soccer')) return 'assets/soccer.png';
    if (s.contains('volleyball')) return 'assets/volleyball.png';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _imageForSport(event.sportName);

    return Scaffold(
      appBar: CustomAppBar(onHomePressed: onHomePressed),
      body: Column(
        children: [
          // 1) Top sport image with back button overlay
          if (imagePath != null)
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // 2) Title, 3) Date, 4) Location, 5) Description
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date
                  Row(
                    children: [
                      const Icon(Icons.event, size: 18, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(event.date),
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.locationName,
                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              event.locationAddress,
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (event.description == null || event.description!.trim().isEmpty)
                        ? _defaultDescriptionForSport(event.sportName)
                        : event.description!,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Fixed bottom Sign up button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onSignUp,
              child: const Text('Sign up  >', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _defaultDescriptionForSport(String sportName) {
    final s = sportName.toLowerCase();
    if (s.contains('pickleball') || s.contains('pickelball')) {
      return 'Join us for an exciting pickleball session. Meet new players and enjoy friendly competition on the court!';
    }
    if (s.contains('basketball')) {
      return 'Get ready for tip-off! Register your team and compete in our basketball event.';
    }
    if (s.contains('soccer')) {
      return 'Lace up for soccer action. Register your team and join the match!';
    }
    if (s.contains('volleyball')) {
      return 'Bump, set, spike! Register your volleyball team and join the fun.';
    }
    return 'Register your team and join the competition!';
  }
}


