import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import 'community_screen.dart';
import 'discover_events_screen.dart';
import 'edit_profile_screen.dart';
import 'my_events_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();

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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _relativeDate(DateTime? date) {
    if (date == null) return 'Unknown time';
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    if (diff.inDays > 0) {
      return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
    }
    if (diff.inHours > 0) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inMinutes > 0) {
      return diff.inMinutes == 1
          ? '1 minute ago'
          : '${diff.inMinutes} minutes ago';
    }
    return 'Just now';
  }

  String _formatJoinedDate(DateTime? date) {
    if (date == null) return 'Joined recently';
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
    return 'Joined ${months[date.month - 1]} ${date.year}';
  }

  IconData _activityIcon(Map<String, dynamic> event) {
    final title = _asString(
      event['title'] ??
          event['eventName'] ??
          event['name'] ??
          event['category'],
    ).toLowerCase();

    if (title.contains('tree') ||
        title.contains('park') ||
        title.contains('plant')) {
      return Icons.park;
    }
    if (title.contains('clean') || title.contains('beach')) {
      return Icons.delete_sweep;
    }
    if (title.contains('workshop') || title.contains('school')) {
      return Icons.school;
    }
    return Icons.volunteer_activism;
  }

  Color _activityTint(IconData icon, bool isDark) {
    if (icon == Icons.park) {
      return isDark ? const Color(0xFF50B27C) : const Color(0xFF1C8D55);
    }
    if (icon == Icons.delete_sweep) return _kPrimaryColor;
    if (icon == Icons.school) {
      return isDark ? const Color(0xFF6FA8FF) : const Color(0xFF2B73D6);
    }
    return _kPrimaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.86)
            : _kBackgroundLight.withValues(alpha: 0.9),
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              if (updated == true && mounted) {
                setState(() {});
              }
            },
            icon: Container(
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.edit, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _firebaseService.currentUser == null
            ? Future.value(null)
            : _firebaseService.getUserData(_firebaseService.currentUser!.uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentUser = _firebaseService.currentUser;
          final userData = userSnapshot.data ?? <String, dynamic>{};

          final name = _asString(
            userData['name'] ?? currentUser?.displayName,
            fallback: 'Community Volunteer',
          );
          final bio = _asString(
            userData['bio'] ?? userData['about'] ?? userData['description'],
            fallback:
                'Environmental enthusiast and community volunteer dedicated to urban greening.',
          );
          final photoUrl = _asString(
            userData['photoUrl'] ?? userData['avatarUrl'],
          );
          final joinedDate = _asDate(userData['createdAt']);
          final basePoints = _asInt(
            userData['impactPoints'] ??
                userData['points'] ??
                userData['rewardPoints'],
            fallback: 0,
          );

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firebaseService.streamMyJoinedEvents(),
            builder: (context, eventsSnapshot) {
              final events =
                  eventsSnapshot.data ?? const <Map<String, dynamic>>[];

              final sortedEvents = [...events]
                ..sort((a, b) {
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

              final eventsAttended = sortedEvents.length;
              final pointsFromEvents = sortedEvents.fold<int>(0, (
                total,
                event,
              ) {
                return total +
                    _asInt(
                      event['impactPoints'] ??
                          event['points'] ??
                          event['rewardPoints'],
                    );
              });
              final impactPoints = basePoints > 0
                  ? basePoints
                  : pointsFromEvents;

              return SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Center(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        width: 128,
                                        height: 128,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _kPrimaryColor.withValues(
                                              alpha: 0.25,
                                            ),
                                            width: 4,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: photoUrl.isNotEmpty
                                              ? Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, error, stackTrace) {
                                                        return _ProfileFallbackAvatar(
                                                          initials: _initials(
                                                            name,
                                                          ),
                                                        );
                                                      },
                                                )
                                              : _ProfileFallbackAvatar(
                                                  initials: _initials(name),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: _kPrimaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark
                                                  ? _kBackgroundDark
                                                  : _kBackgroundLight,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.photo_camera,
                                            size: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      bio,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        size: 16,
                                        color: _kPrimaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatJoinedDate(joinedDate),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _kPrimaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Text(
                              'IMPACT OVERVIEW',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ProfileStatCard(
                                    title: 'Impact Points',
                                    value: impactPoints.toString(),
                                    subtitle: '15% this month',
                                    subtitleColor: isDark
                                        ? const Color(0xFF59D99D)
                                        : const Color(0xFF1C8D55),
                                    icon: Icons.trending_up,
                                    valueColor: _kPrimaryColor,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ProfileStatCard(
                                    title: 'Events Attended',
                                    value: eventsAttended.toString(),
                                    subtitle:
                                        '${(eventsAttended / 6).ceil()} new planned',
                                    subtitleColor: _kPrimaryColor,
                                    icon: Icons.event_available,
                                    valueColor: isDark
                                        ? Colors.white
                                        : Colors.black,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Row(
                              children: [
                                Text(
                                  'ACTIVITY HISTORY',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    foregroundColor: _kPrimaryColor,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'View All',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: sortedEvents.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade900
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      'No activity yet. Join events to build your impact history.',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (final event in sortedEvents.take(6))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _ProfileActivityCard(
                                            icon: _activityIcon(event),
                                            iconColor: _activityTint(
                                              _activityIcon(event),
                                              isDark,
                                            ),
                                            title: _asString(
                                              event['title'] ??
                                                  event['eventName'] ??
                                                  event['name'],
                                              fallback: 'Community Activity',
                                            ),
                                            subtitle:
                                                '${_relativeDate(_asDate(event['eventDate'] ?? event['date'] ?? event['startDate']))} • ${_asString(event['location'] ?? event['venue'], fallback: 'Community')}',
                                            points: _asInt(
                                              event['impactPoints'] ??
                                                  event['points'] ??
                                                  event['rewardPoints'],
                                              fallback: 0,
                                            ),
                                            isDark: isDark,
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
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DiscoverEventsScreen()),
            );
            return;
          }
          if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MyEventsScreen()),
            );
            return;
          }
          if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CommunityScreen()),
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

class _ProfileFallbackAvatar extends StatelessWidget {
  const _ProfileFallbackAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2B2B), Color(0xFF4C4C4C)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    required this.icon,
    required this.valueColor,
    required this.isDark,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final IconData icon;
  final Color valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 14, color: subtitleColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileActivityCard extends StatelessWidget {
  const _ProfileActivityCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int points;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$points pts',
            style: TextStyle(
              color: isDark ? const Color(0xFF59D99D) : const Color(0xFF1C8D55),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
