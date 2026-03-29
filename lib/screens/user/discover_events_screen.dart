import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';

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
  final List<String> _categories = const [
    'All',
    'Environment',
    'Education',
    'Community',
    'Charity',
  ];
  int _selectedCategory = 0;
  int _selectedBottomNav = 0;

  List<Map<String, dynamic>> _filterByCategory(
    List<Map<String, dynamic>> events,
  ) {
    final selected = _categories[_selectedCategory];
    if (selected == 'All') return events;

    final acceptedValues = <String>{selected.toLowerCase()};
    if (selected == 'Environment') {
      acceptedValues.add('environmental');
    }
    if (selected == 'Community') {
      acceptedValues.add('volunteering');
      acceptedValues.add('volunteer');
    }

    return events.where((event) {
      final raw = event['category'] ?? event['type'] ?? event['eventCategory'];
      final value = (raw?.toString() ?? '').toLowerCase();
      return acceptedValues.contains(value);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? _kBackgroundDark : _kBackgroundLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Discover Events'),
        centerTitle: true,
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.95)
            : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final isSelected = _selectedCategory == index;
                  return ChoiceChip(
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = index);
                    },
                    label: Text(
                      _categories[index],
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.black
                            : (isDark ? Colors.grey[200] : Colors.grey[800]),
                      ),
                    ),
                    backgroundColor: isDark ? Colors.grey[850] : Colors.white,
                    selectedColor: _kPrimaryColor,
                    side: BorderSide(
                      color: _kPrimaryColor.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
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
                            const SizedBox(height: 14),
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
                          final organizerName = _asString(
                            event['organizerName'] ?? event['createdByName'],
                            fallback: 'Organizer',
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

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _kPrimaryColor.withValues(alpha: 0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.2 : 0.05,
                                  ),
                                  blurRadius: 14,
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
                                  child: SizedBox(
                                    height: 190,
                                    width: double.infinity,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (imageUrl.isNotEmpty)
                                          Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      color: isDark
                                                          ? Colors.grey[800]
                                                          : Colors.grey[200],
                                                    ),
                                          )
                                        else
                                          Container(
                                            color: isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[200],
                                            child: const Center(
                                              child: Icon(
                                                Icons.image,
                                                size: 42,
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
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
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
                                                      .withValues(alpha: 0.86),
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        description,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 18,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              location,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.grey[300]
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatDate(date),
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[300]
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Created by: $organizerName',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
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
                                                      '$participants joined',
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
                                                          left: i * 22,
                                                          child: CircleAvatar(
                                                            radius: 16,
                                                            backgroundColor:
                                                                isDark
                                                                ? Colors
                                                                      .grey[700]
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
                                                            22.0,
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
                                            onPressed: () {},
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _kPrimaryColor,
                                              foregroundColor: Colors.black,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text(
                                              'View Details',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
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
              currentIndex: _selectedBottomNav,
              onTap: (index) {
                setState(() => _selectedBottomNav = index);
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
