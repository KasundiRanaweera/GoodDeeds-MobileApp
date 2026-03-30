import 'package:flutter/material.dart';

import '../../constants/event_categories.dart';
import '../../services/firebase_service.dart';
import 'community_screen.dart';
import 'event_details_screen.dart';
import 'my_events_screen.dart';
import 'user_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class DiscoverEventsScreen extends StatefulWidget {
  const DiscoverEventsScreen({super.key});

  @override
  State<DiscoverEventsScreen> createState() => _DiscoverEventsScreenState();
}

class _DiscoverEventsScreenState extends State<DiscoverEventsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late final List<String> _categories = kDiscoverEventCategories;
  int _selectedCategory = 0;

  List<Map<String, dynamic>> _filterByCategory(
    List<Map<String, dynamic>> events,
  ) {
    final selected = _categories[_selectedCategory].trim();
    if (selected == 'All') return events;

    return events.where((event) {
      final raw = event['category'] ?? event['type'] ?? event['eventCategory'];
      final value = (raw?.toString() ?? '').trim().toLowerCase();
      return value == selected.toLowerCase();
    }).toList();
  }

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
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, ${date.year} • $hour12:$minute $suffix';
  }

  List<String> _avatarUrls(Map<String, dynamic> event) {
    final raw = event['participantAvatars'] ?? event['avatars'];
    if (raw is List) {
      return raw
          .map((item) => item?.toString() ?? '')
          .where((url) => url.isNotEmpty)
          .take(3)
          .toList();
    }
    return const [];
  }

  Widget _categoryChip({
    required int index,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        if (isSelected) return;
        setState(() => _selectedCategory = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _kPrimaryColor
              : (isDark ? Colors.grey[850] : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.16)),
        ),
        child: Text(
          _categories[index],
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.grey[200] : Colors.grey[800]),
          ),
        ),
      ),
    );
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
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.explore, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text(
              'Discover Events',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final isSelected = _selectedCategory == index;
                  return _categoryChip(
                    index: index,
                    isSelected: isSelected,
                    isDark: isDark,
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemCount: _categories.length,
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
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
                          'Could not load events right now. Please try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  }

                  final events = _filterByCategory(snapshot.data ?? const []);
                  if (events.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_busy,
                              size: 64,
                              color: _kPrimaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedCategory == 0
                                  ? 'No events published yet.'
                                  : 'No ${_categories[_selectedCategory]} events yet.',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Events will appear here after organizers create and publish them.',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: events.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final title = _asString(
                            event['title'] ??
                                event['eventName'] ??
                                event['name'],
                            fallback: 'Untitled Event',
                          );
                          final description = _asString(
                            event['description'] ??
                                event['details'] ??
                                event['about'],
                            fallback:
                                'Join this community event and make an impact.',
                          );
                          final location = _asString(
                            event['location'] ??
                                event['venue'] ??
                                event['address'],
                            fallback: 'Location to be announced',
                          );
                          final category = _asString(
                            event['category'] ??
                                event['type'] ??
                                event['eventCategory'],
                            fallback: 'Volunteering',
                          );
                          final impactPoints = _asInt(
                            event['impactPoints'] ??
                                event['points'] ??
                                event['rewardPoints'],
                            fallback: 10,
                          );
                          final imageUrl = _asString(
                            event['imageUrl'] ??
                                event['bannerUrl'] ??
                                event['photoUrl'],
                          );
                          final date = _asDate(
                            event['eventDate'] ??
                                event['date'] ??
                                event['startDate'],
                          );
                          final avatars = _avatarUrls(event);
                          final participants = _asInt(
                            event['participantsCount'] ??
                                event['volunteerCount'] ??
                                event['joinedCount'],
                            fallback: 0,
                          );
                          final organizerPhone = _asString(
                            event['contactNumber'] ??
                                event['organizerPhone'] ??
                                event['createdByPhone'],
                          );

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[800]!.withValues(alpha: 0.6)
                                    : Colors.grey[200]!.withValues(alpha: 0.7),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.08,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withValues(
                                                  alpha: 0.1,
                                                ),
                                                Colors.black.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (imageUrl.isNotEmpty)
                                          Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder:
                                                (_, error, stackTrace) {
                                                  return Container(
                                                    color: isDark
                                                        ? Colors.grey[800]
                                                        : Colors.grey[200],
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.image,
                                                        size: 48,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          )
                                        else
                                          Container(
                                            color: isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[200],
                                            child: const Center(
                                              child: Icon(
                                                Icons.image,
                                                size: 48,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          top: 12,
                                          left: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _kPrimaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              category,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (isDark
                                                          ? Colors.black
                                                          : Colors.white)
                                                      .withValues(alpha: 0.9),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '+$impactPoints Impact Points',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: _kPrimaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        description,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.grey[350]
                                              : Colors.grey[700],
                                          height: 1.45,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _kPrimaryColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: _kPrimaryColor,
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                location,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: _kPrimaryColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _formatDate(date),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[700],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (organizerPhone.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 14,
                                              color: isDark
                                                  ? Colors.grey[500]
                                                  : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                organizerPhone,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.grey[300]
                                                      : Colors.grey[800],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          SizedBox(
                                            height: 34,
                                            child: avatars.isEmpty
                                                ? Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _kPrimaryColor
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '+$participants',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  )
                                                : Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      for (
                                                        var i = 0;
                                                        i < avatars.length;
                                                        i++
                                                      )
                                                        Positioned(
                                                          left: i * 20,
                                                          child: CircleAvatar(
                                                            radius: 16,
                                                            backgroundColor:
                                                                isDark
                                                                ? Colors
                                                                      .grey[800]
                                                                : Colors.white,
                                                            backgroundImage:
                                                                NetworkImage(
                                                                  avatars[i],
                                                                ),
                                                          ),
                                                        ),
                                                      Positioned(
                                                        left:
                                                            avatars.length *
                                                            20.0,
                                                        child: Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                _kPrimaryColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    ),
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color: isDark
                                                                  ? Colors
                                                                        .grey[850]!
                                                                  : Colors
                                                                        .white,
                                                              width: 2,
                                                            ),
                                                          ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: Text(
                                                            '+$participants',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                          const Spacer(),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      EventDetailsScreen(
                                                        eventData: event,
                                                      ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _kPrimaryColor,
                                              foregroundColor: Colors.black,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            child: const Text(
                                              'View Details',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            BottomNavigationBar(
              currentIndex: 0,
              onTap: (index) {
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
                  return;
                }
                if (index == 3) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const UserProfileScreen(),
                    ),
                  );
                }
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: _kPrimaryColor,
              unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[700],
              backgroundColor: isDark ? _kBackgroundDark : Colors.white,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Events',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event),
                  label: 'My Events',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.groups),
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
      ),
    );
  }
}
