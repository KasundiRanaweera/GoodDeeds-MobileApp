import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import 'discover_events_screen.dart';
import 'community_screen.dart';
import 'event_details_screen.dart';
import 'user_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<String> _tabs = const ['All', 'Upcoming', 'Past'];
  int _selectedTab = 0;

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

  String _formatDateTime(DateTime? date) {
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
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, ${date.year} • $hour12:$minute $suffix';
  }

  List<Map<String, dynamic>> _filteredEvents(
    List<Map<String, dynamic>> events,
  ) {
    if (_selectedTab == 0) return events;

    final now = DateTime.now();
    final isUpcomingTab = _selectedTab == 1;

    return events.where((event) {
      final date = _asDate(
        event['eventDate'] ?? event['date'] ?? event['startDate'],
      );
      if (date == null) return isUpcomingTab;
      final isPast = date.isBefore(now);
      return isUpcomingTab ? !isPast : isPast;
    }).toList();
  }

  bool _isAttended(Map<String, dynamic> event, String uid) {
    final attendedIds = (event['attendedUserIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toSet();

    if (attendedIds.contains(uid)) return true;

    final attendanceMap = event['attendanceByUser'];
    if (attendanceMap is Map && attendanceMap[uid] == true) return true;

    final status = _asString(event['attendanceStatus']).toLowerCase();
    return status == 'attended';
  }

  String _statusForEvent(Map<String, dynamic> event, String uid) {
    final date = _asDate(
      event['eventDate'] ?? event['date'] ?? event['startDate'],
    );
    if (date == null || date.isAfter(DateTime.now())) return 'Joined';
    return _isAttended(event, uid) ? 'Attended' : 'Absent';
  }

  Color _statusBackground(String status, bool isDark) {
    switch (status) {
      case 'Joined':
        return _kPrimaryColor.withValues(alpha: 0.15);
      case 'Attended':
        return _kPrimaryColor.withValues(alpha: isDark ? 0.12 : 0.2);
      default:
        return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status, bool isDark) {
    switch (status) {
      case 'Joined':
        return _kPrimaryColor;
      case 'Attended':
        return isDark ? _kPrimaryColor : Colors.black87;
      default:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? _kBackgroundDark : _kBackgroundLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'My Events',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: isDark ? _kBackgroundDark : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 1,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? _kBackgroundDark : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = i),
                      child: Container(
                        padding: const EdgeInsets.only(top: 14, bottom: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedTab == i
                                  ? _kPrimaryColor
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == i
                                ? _kPrimaryColor
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firebaseService.streamMyJoinedEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load your events right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                }

                final allEvents = snapshot.data ?? const [];
                final events = _filteredEvents(allEvents);
                final currentUid = _firebaseService.currentUser?.uid ?? '';

                if (events.isEmpty) {
                  final emptyText = _selectedTab == 0
                      ? 'You have not joined any events yet.'
                      : _selectedTab == 1
                      ? 'No upcoming joined events.'
                      : 'No past joined events.';

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        emptyText,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  itemCount: events.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final title = _asString(
                      event['title'] ?? event['eventName'] ?? event['name'],
                      fallback: 'Untitled Event',
                    );
                    final date = _asDate(
                      event['eventDate'] ?? event['date'] ?? event['startDate'],
                    );
                    final location = _asString(
                      event['location'] ?? event['venue'] ?? event['address'],
                      fallback: 'Location to be announced',
                    );
                    final imageUrl = _asString(
                      event['imageUrl'] ??
                          event['bannerUrl'] ??
                          event['photoUrl'],
                    );
                    final status = _statusForEvent(event, currentUid);
                    final points = _asInt(
                      event['impactPoints'] ??
                          event['points'] ??
                          event['rewardPoints'],
                      fallback: 0,
                    );

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EventDetailsScreen(eventData: event),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.12 : 0.05,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, error, stackTrace) =>
                                                  Container(
                                                    color: isDark
                                                        ? Colors.grey.shade800
                                                        : Colors.grey.shade200,
                                                    child: const Icon(
                                                      Icons.image,
                                                    ),
                                                  ),
                                        )
                                      : Container(
                                          color: isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade200,
                                          child: const Icon(Icons.image),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusBackground(
                                              status,
                                              isDark,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: _statusTextColor(
                                                status,
                                                isDark,
                                              ),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatDateTime(date),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: isDark
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            location,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (status == 'Attended') ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.stars,
                                            size: 14,
                                            color: _kPrimaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '+$points Points Earned',
                                            style: const TextStyle(
                                              color: _kPrimaryColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (status == 'Absent') ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'No points earned',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade500,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DiscoverEventsScreen()),
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
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
