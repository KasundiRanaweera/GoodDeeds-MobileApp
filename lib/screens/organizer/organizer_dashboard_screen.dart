import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import 'create_event_screen.dart';
import 'manage_event_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  State<OrganizerDashboardScreen> createState() =>
      _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedBottomTab = 0;

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

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
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
    if (date == null) return 'Date TBD';
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool _isOwnedByCurrentUser(Map<String, dynamic> event, String currentUid) {
    if (currentUid.isEmpty) return true;
    final ownerCandidates = [
      event['createdByUid'],
      event['organizerId'],
      event['userId'],
      event['ownerId'],
    ];

    for (final candidate in ownerCandidates) {
      if ((candidate?.toString() ?? '') == currentUid) {
        return true;
      }
    }

    // If no ownership field exists, keep events visible so dashboard is useful.
    final hasOwnerMetadata = ownerCandidates.any((value) => value != null);
    return !hasOwnerMetadata;
  }

  String _statusForEvent(Map<String, dynamic> event) {
    final status = _asString(event['status']).toLowerCase();
    if (status == 'draft' || status == 'completed' || status == 'active') {
      return status;
    }

    final date = _asDate(
      event['eventDate'] ?? event['date'] ?? event['startDate'],
    );
    if (date == null) return 'draft';
    if (date.isBefore(DateTime.now())) return 'completed';
    return 'active';
  }

  Color _statusBackground(String status, bool isDark) {
    switch (status) {
      case 'active':
        return _kPrimaryColor.withValues(alpha: 0.14);
      case 'completed':
        return isDark ? Colors.grey.shade700 : Colors.grey.shade300;
      default:
        return isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    }
  }

  Color _statusText(String status, bool isDark) {
    switch (status) {
      case 'active':
        return _kPrimaryColor;
      case 'completed':
        return isDark ? Colors.grey.shade300 : Colors.grey.shade700;
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
        centerTitle: true,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.dashboard, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firebaseService.streamOrganizerEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load organizer dashboard right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
            );
          }

          final currentUid = _firebaseService.currentUser?.uid ?? '';
          final allEvents = snapshot.data ?? const <Map<String, dynamic>>[];
          final myEvents = allEvents
              .where((event) => _isOwnedByCurrentUser(event, currentUid))
              .toList();

          myEvents.sort((a, b) {
            final aDate = _asDate(
              a['eventDate'] ?? a['date'] ?? a['startDate'],
            );
            final bDate = _asDate(
              b['eventDate'] ?? b['date'] ?? b['startDate'],
            );
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          final totalEvents = myEvents.length;
          final totalAttendees = myEvents.fold<int>(0, (acc, event) {
            return acc +
                _asInt(
                  event['participantsCount'] ??
                      event['participantCount'] ??
                      event['joinedCount'],
                );
          });
          final totalRevenue = myEvents.fold<double>(0, (acc, event) {
            return acc + _asDouble(event['revenue'] ?? event['amount']);
          });
          final avgRating = myEvents.isEmpty
              ? 0.0
              : myEvents.fold<double>(0, (acc, event) {
                      return acc +
                          _asDouble(
                            event['rating'] ?? event['avgRating'],
                            fallback: 4.8,
                          );
                    }) /
                    myEvents.length;

          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  children: [
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width >= 720
                          ? 4
                          : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _StatCard(
                          label: 'Total Events',
                          value: '$totalEvents',
                          isDark: isDark,
                        ),
                        _StatCard(
                          label: 'Total Attendees',
                          value: '$totalAttendees',
                          isDark: isDark,
                        ),
                        _StatCard(
                          label: 'Revenue',
                          value: totalRevenue > 0
                              ? '\$${(totalRevenue / 1000).toStringAsFixed(1)}k'
                              : '\$0.0k',
                          valueColor: _kPrimaryColor,
                          isDark: isDark,
                        ),
                        _StatCard(
                          label: 'Avg. Rating',
                          value: avgRating == 0
                              ? '0.0'
                              : avgRating.toStringAsFixed(1),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'My Events',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Filter coming soon.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.filter_list),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (myEvents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          'No events yet. Tap Create Event to start your first event.',
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ...myEvents.map((event) {
                        final title = _asString(
                          event['title'] ?? event['eventName'] ?? event['name'],
                          fallback: 'Untitled Event',
                        );
                        final imageUrl = _asString(
                          event['imageUrl'] ??
                              event['bannerUrl'] ??
                              event['photoUrl'],
                        );
                        final location = _asString(
                          event['location'] ??
                              event['venue'] ??
                              event['address'],
                          fallback: 'Location TBD',
                        );
                        final participants = _asInt(
                          event['participantsCount'] ??
                              event['participantCount'] ??
                              event['joinedCount'],
                        );
                        final date = _asDate(
                          event['eventDate'] ??
                              event['date'] ??
                              event['startDate'],
                        );
                        final status = _statusForEvent(event);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade900.withValues(alpha: 0.5)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.15 : 0.04,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                if (imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14),
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey.shade400,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusBackground(
                                                status,
                                                isDark,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: _statusText(
                                                  status,
                                                  isDark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.more_vert,
                                            color: isDark
                                                ? Colors.grey.shade500
                                                : Colors.grey.shade500,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 14,
                                        runSpacing: 6,
                                        children: [
                                          _EventMeta(
                                            icon: Icons.calendar_today,
                                            text: _formatDate(date),
                                            isDark: isDark,
                                          ),
                                          _EventMeta(
                                            icon: Icons.group,
                                            text: '$participants Participants',
                                            isDark: isDark,
                                          ),
                                          _EventMeta(
                                            icon: Icons.location_on,
                                            text: location,
                                            isDark: isDark,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Participants view coming soon.',
                                                  ),
                                                ),
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _kPrimaryColor,
                                              side: const BorderSide(
                                                color: _kPrimaryColor,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.people,
                                              size: 18,
                                            ),
                                            label: const Text('Participants'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ManageEventScreen(
                                                        eventData: event,
                                                      ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _kPrimaryColor,
                                              foregroundColor: Colors.black,
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('Manage Event'),
                                                SizedBox(width: 6),
                                                Icon(
                                                  Icons.arrow_forward,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomTab,
        onTap: (index) {
          if (index == 0) {
            setState(() => _selectedBottomTab = index);
            return;
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kPrimaryColor,
        unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[700],
        backgroundColor: isDark ? _kBackgroundDark : Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create Event',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.55)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: valueColor ?? (isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventMeta extends StatelessWidget {
  const _EventMeta({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  final IconData icon;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
