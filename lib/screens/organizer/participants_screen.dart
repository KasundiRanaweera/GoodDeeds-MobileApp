import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../utils/type_converters.dart';
import 'organizer_dashboard_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class ParticipantsScreen extends StatefulWidget {
  const ParticipantsScreen({super.key, this.eventData});

  final Map<String, dynamic>? eventData;

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _eventId() {
    return widget.eventData?['id']?.toString() ?? '';
  }

  String _eventTitleFromData(Map<String, dynamic> eventData) {
    final value =
        eventData['title'] ?? eventData['eventName'] ?? eventData['name'];
    final text = TypeConverters.asString(value);
    return text.isEmpty ? 'Selected Event' : text;
  }

  bool _isAttendanceOpen(Map<String, dynamic> eventData) {
    final eventDateTime = TypeConverters.asDate(
      eventData['eventDate'] ?? eventData['date'] ?? eventData['startDate'],
    );
    if (eventDateTime == null) return false;

    // Attendance is allowed starting from the event time onwards.
    final now = DateTime.now();
    return !now.isBefore(eventDateTime);
  }

  Future<List<_ParticipantVm>> _loadParticipants(
    List<String> participantIds,
  ) async {
    if (participantIds.isEmpty) return const [];

    final List<_ParticipantVm> result = [];
    for (final uid in participantIds) {
      final userDocFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final profileDocFuture = FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(uid)
          .get();

      final snapshots = await Future.wait([userDocFuture, profileDocFuture]);
      final userData = snapshots[0].data() ?? <String, dynamic>{};
      final profileData = snapshots[1].data() ?? <String, dynamic>{};

      final name = (profileData['name']?.toString().trim().isNotEmpty ?? false)
          ? profileData['name'].toString().trim()
          : (userData['name']?.toString().trim().isNotEmpty ?? false)
          ? userData['name'].toString().trim()
          : 'Participant';
      final email =
          userData['email']?.toString().trim() ??
          profileData['email']?.toString().trim() ??
          '';
      final photoUrl =
          profileData['photoUrl']?.toString().trim() ??
          profileData['avatarUrl']?.toString().trim() ??
          userData['photoUrl']?.toString().trim() ??
          userData['avatarUrl']?.toString().trim() ??
          '';

      result.add(
        _ParticipantVm(uid: uid, name: name, email: email, photoUrl: photoUrl),
      );
    }
    return result;
  }

  Future<void> _setCheckedIn({
    required String eventId,
    required String participantUid,
    required bool checkedIn,
  }) async {
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(eventRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final checkedInIds = TypeConverters.asStringList(
        data['checkedInIds'],
      ).toSet();
      final awardedParticipantIds = TypeConverters.asStringList(
        data['awardedParticipantIds'],
      ).toSet();
      final attendanceOpen = _isAttendanceOpen(data);
      final impactPoints = TypeConverters.asInt(
        data['impactPoints'] ?? data['points'] ?? data['rewardPoints'],
      );

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(participantUid);
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? <String, dynamic>{};
      final currentPoints = TypeConverters.asInt(
        userData['impactPoints'] ??
            userData['totalPoints'] ??
            userData['rewardPoints'] ??
            userData['points'],
      );

      // Prepare all user updates
      final userUpdates = <String, dynamic>{};

      if (checkedIn) {
        if (!attendanceOpen) {
          return;
        }
        checkedInIds.add(participantUid);
        if (!awardedParticipantIds.contains(participantUid) &&
            impactPoints > 0) {
          final updatedPoints = currentPoints + impactPoints;
          userUpdates['impactPoints'] = updatedPoints;
          userUpdates['totalPoints'] = updatedPoints;
          userUpdates['rewardPoints'] = updatedPoints;
          userUpdates['points'] = updatedPoints;
          awardedParticipantIds.add(participantUid);
        }
      } else {
        checkedInIds.remove(participantUid);
        if (awardedParticipantIds.contains(participantUid) &&
            impactPoints > 0) {
          final updatedPoints = (currentPoints - impactPoints).clamp(
            0,
            1000000000,
          );
          userUpdates['impactPoints'] = updatedPoints;
          userUpdates['totalPoints'] = updatedPoints;
          userUpdates['rewardPoints'] = updatedPoints;
          userUpdates['points'] = updatedPoints;
          awardedParticipantIds.remove(participantUid);
        }
      }

      // Add participation status and timestamp
      userUpdates['participationStatusByEvent.$eventId'] = checkedIn
          ? 'attended'
          : 'joined';
      if (checkedIn) {
        userUpdates['attendanceVerifiedAtByEvent.$eventId'] =
            FieldValue.serverTimestamp();
      } else {
        userUpdates['attendanceVerifiedAtByEvent.$eventId'] =
            FieldValue.delete();
      }
      userUpdates['updatedAt'] = FieldValue.serverTimestamp();

      // Single atomic update to user document
      tx.set(userRef, userUpdates, SetOptions(merge: true));

      tx.update(eventRef, {
        'checkedInIds': checkedInIds.toList(),
        'awardedParticipantIds': awardedParticipantIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  PreferredSizeWidget _buildParticipantsAppBar({
    required bool isDark,
    required VoidCallback onBack,
  }) {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.people, color: _kPrimaryColor),
          SizedBox(width: 8),
          Text('Participants', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      backgroundColor: isDark
          ? _kBackgroundDark.withValues(alpha: 0.84)
          : Colors.white.withValues(alpha: 0.86),
      foregroundColor: isDark ? Colors.white : Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventId = _eventId();

    if (eventId.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
        appBar: _buildParticipantsAppBar(
          isDark: isDark,
          onBack: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const OrganizerDashboardScreen(),
              ),
            );
          },
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No event selected. Open Participants from a specific event card in Dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      appBar: _buildParticipantsAppBar(
        isDark: isDark,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .snapshots(),
        builder: (context, eventSnapshot) {
          if (eventSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (eventSnapshot.hasError ||
              !eventSnapshot.hasData ||
              !eventSnapshot.data!.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load participants for this event.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }

          final eventData = eventSnapshot.data!.data() ?? <String, dynamic>{};
          final liveEventTitle = _eventTitleFromData(eventData);
          final attendanceOpen = _isAttendanceOpen(eventData);
          final participantIds = TypeConverters.asStringList(
            eventData['participantIds'],
          );
          final checkedInIds = TypeConverters.asStringList(
            eventData['checkedInIds'],
          ).toSet();

          return FutureBuilder<List<_ParticipantVm>>(
            future: _loadParticipants(participantIds),
            builder: (context, participantsSnapshot) {
              if (participantsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allParticipants =
                  participantsSnapshot.data ?? const <_ParticipantVm>[];
              final filteredParticipants = allParticipants.where((participant) {
                if (_searchText.isEmpty) return true;
                final needle = _searchText.toLowerCase();
                return participant.name.toLowerCase().contains(needle) ||
                    participant.email.toLowerCase().contains(needle);
              }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      liveEventTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!attendanceOpen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.withValues(alpha: 0.18)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Attendance can be marked on the event date or after.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.orange.shade200
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? _kPrimaryColor.withValues(alpha: 0.12)
                          : _kPrimaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _kPrimaryColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.search,
                          color: _kPrimaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _searchText = value.trim()),
                            decoration: InputDecoration(
                              hintText: 'Search participants...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? _kPrimaryColor.withValues(alpha: 0.18)
                          : _kPrimaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Checked In',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${checkedInIds.length} / ${participantIds.length}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: _kPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _kPrimaryColor, width: 3),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!attendanceOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'You can mark attendance after the event starts.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ...filteredParticipants.asMap().entries.map((entry) {
                    final participant = entry.value;
                    final isCheckedIn = checkedInIds.contains(participant.uid);
                    final avatarUrl = participant.photoUrl;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 80),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade900.withValues(alpha: 0.45)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCheckedIn
                                ? _kPrimaryColor.withValues(alpha: 0.22)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCheckedIn
                                      ? _kPrimaryColor.withValues(alpha: 0.55)
                                      : _kPrimaryColor.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                              ),
                              child: avatarUrl.isNotEmpty
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, error, stackTrace) {
                                        return Container(
                                          color: isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade200,
                                          alignment: Alignment.center,
                                          child: Text(
                                            participant.name.isEmpty
                                                ? '?'
                                                : participant
                                                      .name
                                                      .characters
                                                      .first
                                                      .toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.grey.shade200
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: Text(
                                        participant.name.isEmpty
                                            ? '?'
                                            : participant.name.characters.first
                                                  .toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.grey.shade200
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                participant.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: isCheckedIn,
                                  activeColor: _kPrimaryColor,
                                  onChanged: attendanceOpen
                                      ? (value) async {
                                          await _setCheckedIn(
                                            eventId: eventId,
                                            participantUid: participant.uid,
                                            checkedIn: value ?? false,
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ParticipantVm {
  const _ParticipantVm({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
  });

  final String uid;
  final String name;
  final String email;
  final String photoUrl;
}
