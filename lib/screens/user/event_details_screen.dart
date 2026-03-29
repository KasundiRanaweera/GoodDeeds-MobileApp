import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import 'discover_events_screen.dart';
import 'community_screen.dart';
import 'my_events_screen.dart';
import 'user_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key, required this.eventData});

  final Map<String, dynamic> eventData;
  FirebaseService get _firebaseService => FirebaseService();

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic date = value?.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date to be announced';
    const months = [
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

    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');

    return '$month $day, ${date.year}';
  }

  String _formatTimeRange(DateTime? date) {
    if (date == null) return 'Time to be announced';
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $suffix';
  }

  String _eventId() {
    return _asString(eventData['id'] ?? eventData['eventId']);
  }

  Future<void> _onJoinEvent(BuildContext context) async {
    final eventId = _eventId();
    if (eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to join this event right now.')),
      );
      return;
    }

    try {
      await _firebaseService.joinEvent(eventId: eventId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Joined successfully!')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join event: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? _kBackgroundDark : _kBackgroundLight;

    final title = _asString(
      eventData['title'] ?? eventData['eventName'] ?? eventData['name'],
      fallback: 'Event Details',
    );
    final description = _asString(
      eventData['description'] ?? eventData['details'] ?? eventData['about'],
      fallback: 'No event description available yet.',
    );
    final location = _asString(
      eventData['location'] ?? eventData['venue'] ?? eventData['address'],
      fallback: 'Location to be announced',
    );
    final organizerName = _asString(
      eventData['organizerName'] ?? eventData['createdByName'],
      fallback: 'Organizer',
    );
    final imageUrl = _asString(
      eventData['imageUrl'] ?? eventData['bannerUrl'] ?? eventData['photoUrl'],
    );
    final points = _asInt(
      eventData['impactPoints'] ??
          eventData['points'] ??
          eventData['rewardPoints'],
      fallback: 10,
    );
    final joined = _asInt(
      eventData['participantsCount'] ??
          eventData['volunteerCount'] ??
          eventData['joinedCount'],
      fallback: 0,
    );
    final eventDate = _asDate(
      eventData['eventDate'] ?? eventData['date'] ?? eventData['startDate'],
    );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        title: const Text(
          'Event Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              );
            },
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 170),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl.isNotEmpty)
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, error, stackTrace) => Container(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                            ),
                          )
                        else
                          Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.image,
                                size: 52,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _kPrimaryColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+$points Points',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kPrimaryColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _kPrimaryColor.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.business,
                                  color: _kPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      organizerName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Verified Organizer',
                                      style: TextStyle(
                                        color: _kPrimaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _kPrimaryColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: _kPrimaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(eventDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTimeRange(eventDate),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _kPrimaryColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: _kPrimaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Location details available in app maps.',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'About the Event',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: TextStyle(
                            height: 1.45,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _kPrimaryColor.withValues(alpha: 0.35),
                              style: BorderStyle.solid,
                            ),
                            color: _kPrimaryColor.withValues(alpha: 0.08),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.redeem, color: _kPrimaryColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Participation Reward',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              Text(
                                '+$points Points',
                                style: const TextStyle(
                                  color: _kPrimaryColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: isDark
                ? _kBackgroundDark.withValues(alpha: 0.96)
                : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _onJoinEvent(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Join Event',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: _kPrimaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${joined > 0 ? joined : 1200} people are joining',
                        style: const TextStyle(
                          color: _kPrimaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          BottomNavigationBar(
            currentIndex: 0,
            onTap: (index) {
              if (index == 0) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const DiscoverEventsScreen(),
                  ),
                );
              } else if (index == 1) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MyEventsScreen()),
                );
              } else if (index == 2) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CommunityScreen()),
                );
              } else if (index == 3) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                );
              }
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: _kPrimaryColor,
            unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[700],
            backgroundColor: isDark ? _kBackgroundDark : Colors.white,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Events'),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'My Events',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: 'Community',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
