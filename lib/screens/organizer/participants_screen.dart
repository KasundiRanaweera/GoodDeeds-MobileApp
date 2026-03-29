import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  final List<String> _avatarSeeds = const [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCuY11Qqi-nho47LfIHzeXROxFZQClUiV-ae35OcU5QLSyMGVBr_vgupL8g7pbJAGaLgewfK9_n5AgZhswEZL0jY40YvkhFqZkhWmWwai3dfR29ln7QGeVJuZqpdbjRbZ-A8PGJ9FsM0HseqtSmkeYngXvPDzE0z64DDnPh2z8HtI4UmkSF6-3vdh5kwusG90DouX941TkECo2XeIItpd5IPg1oA38mfhY2DRqG-1NkHWpnxOeQwfGmlgCJDj_bZxAlnxpYzah1u18',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuB-ZyVzSfRAWpmJ6ZlpVh2k2RsgJLtNLXjozJen46r2ED2_6Xg-hFela6A1_ltYwlU5cJlWY68pM4Lid3PwkqhsDau-aYbGz9umQVHoXQ7Yt9UhITYk1WS8CrmgZp17ZH57XaIUZwxIXX03IkuPNzmVXtJzgdxloZiOgvA5aWjLHJOpgVoBErQUVCaBXiXsm0wRAPCHWYEoDAeHPDF23fJF583_Sl8un11bC0EoHRNFZHIkfl5BV7fTuUD9cO7rdruVaUmBvbwMeaA',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDQEMHx9S2hX-TpQDA0e6n4hBsJ9xqPJURHBQypS3YyRt-ldaTWKLVlxSQBQx6RkaQh6bYBDOSz-mws1suaBGoySlcXiataZwVUH3S8ShxMuHKR1gcCQgRN5l9KfHKtV60p8AmkM7y15-iiAh0cWqM1Im9qCn7fDBrr09bADHvUcBNXsM139iuhn4ONRwlAEx6tugN_A2c5kg9KpOS59zHaF99skt2f1tqYNbsv8Z0zeV-lBaZYns47pFj0I-2Si9gw-u-0Rlgd9cg',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDWQWW1NBcYTENinzfzL1dfbPupNucFF_kX3Xa4hXVqfiKO6MEY1GSAyFunI3_TutZBsWDpWy7C6j8YWUUCles0HYkDqtlx2_oAwhSDv70rCHyH7xO6xq4H_H7UKNcsq_3r9gIuk7aiacRDWfKnJhozidZI7gZX95PaImlCflQDpLQCbubkN5cHOB0VbEXHbnvGng1iVdVUX_NZ8NZ3z42ZTWujEjCarmkl9UytjdNcsJyUaexHbIxJQZ5HQYU6Y3QRZggL3I1Vl6s',
  ];

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
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Selected Event' : text;
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((x) => x.isNotEmpty)
          .toList();
    }
    return const [];
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isEventCompleted(Map<String, dynamic> eventData) {
    final eventDate = _asDate(
      eventData['eventDate'] ?? eventData['date'] ?? eventData['startDate'],
    );
    if (eventDate == null) return false;
    return DateTime.now().isAfter(eventDate);
  }

  Future<List<_ParticipantVm>> _loadParticipants(
    List<String> participantIds,
  ) async {
    if (participantIds.isEmpty) return const [];

    final List<_ParticipantVm> result = [];
    for (final uid in participantIds) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      final name = (data['name']?.toString().trim().isNotEmpty ?? false)
          ? data['name'].toString().trim()
          : 'Participant';
      final email = data['email']?.toString().trim() ?? '';
      final photoUrl =
          data['photoUrl']?.toString().trim() ??
          data['avatarUrl']?.toString().trim() ??
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
      final checkedInIds = _asStringList(data['checkedInIds']).toSet();
      final awardedParticipantIds = _asStringList(
        data['awardedParticipantIds'],
      ).toSet();
      final eventCompleted = _isEventCompleted(data);
      final impactPoints = _asInt(
        data['impactPoints'] ?? data['points'] ?? data['rewardPoints'],
      );

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(participantUid);
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? <String, dynamic>{};
      final currentPoints = _asInt(
        userData['impactPoints'] ??
            userData['totalPoints'] ??
            userData['rewardPoints'] ??
            userData['points'],
      );

      if (checkedIn) {
        if (!eventCompleted) {
          return;
        }
        checkedInIds.add(participantUid);
        if (!awardedParticipantIds.contains(participantUid) &&
            impactPoints > 0) {
          final updatedPoints = currentPoints + impactPoints;
          tx.set(userRef, {
            'impactPoints': updatedPoints,
            'totalPoints': updatedPoints,
            'rewardPoints': updatedPoints,
            'points': updatedPoints,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
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
          tx.set(userRef, {
            'impactPoints': updatedPoints,
            'totalPoints': updatedPoints,
            'rewardPoints': updatedPoints,
            'points': updatedPoints,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          awardedParticipantIds.remove(participantUid);
        }
      }
      tx.update(eventRef, {
        'checkedInIds': checkedInIds.toList(),
        'awardedParticipantIds': awardedParticipantIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _removeParticipant({
    required String eventId,
    required String participantUid,
  }) async {
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(eventRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final participantIds = _asStringList(data['participantIds']).toSet();
      final checkedInIds = _asStringList(data['checkedInIds']).toSet();
      final awardedParticipantIds = _asStringList(
        data['awardedParticipantIds'],
      ).toSet();
      final impactPoints = _asInt(
        data['impactPoints'] ?? data['points'] ?? data['rewardPoints'],
      );

      participantIds.remove(participantUid);
      checkedInIds.remove(participantUid);

      if (awardedParticipantIds.contains(participantUid) && impactPoints > 0) {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(participantUid);
        final userSnap = await tx.get(userRef);
        final userData = userSnap.data() ?? <String, dynamic>{};
        final currentPoints = _asInt(
          userData['impactPoints'] ??
              userData['totalPoints'] ??
              userData['rewardPoints'] ??
              userData['points'],
        );
        final updatedPoints = (currentPoints - impactPoints).clamp(
          0,
          1000000000,
        );

        tx.set(userRef, {
          'impactPoints': updatedPoints,
          'totalPoints': updatedPoints,
          'rewardPoints': updatedPoints,
          'points': updatedPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        awardedParticipantIds.remove(participantUid);
      }

      tx.update(eventRef, {
        'participantIds': participantIds.toList(),
        'participantsCount': participantIds.length,
        'checkedInIds': checkedInIds.toList(),
        'awardedParticipantIds': awardedParticipantIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventId = _eventId();

    if (eventId.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const OrganizerDashboardScreen(),
                ),
              );
            },
          ),
          title: const Text('Participants'),
          centerTitle: true,
          backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Participants',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.85)
            : _kBackgroundLight.withValues(alpha: 0.9),
        foregroundColor: isDark ? Colors.white : Colors.black,
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
          final eventCompleted = _isEventCompleted(eventData);
          final participantIds = _asStringList(eventData['participantIds']);
          final checkedInIds = _asStringList(eventData['checkedInIds']).toSet();

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

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 104),
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
                      if (!eventCompleted)
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
                            'Attendance can be marked only after the event date.',
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
                                border: Border.all(
                                  color: _kPrimaryColor,
                                  width: 3,
                                ),
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
                      if (filteredParticipants.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade900.withValues(alpha: 0.45)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Text(
                            participantIds.isEmpty
                                ? 'No one has joined this event yet.'
                                : 'No participants found for your search.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        ...filteredParticipants.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final participant = entry.value;
                          final isCheckedIn = checkedInIds.contains(
                            participant.uid,
                          );
                          final avatarUrl = participant.photoUrl.isNotEmpty
                              ? participant.photoUrl
                              : _avatarSeeds[idx % _avatarSeeds.length];

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
                                    ? Colors.grey.shade900.withValues(
                                        alpha: 0.45,
                                      )
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
                                            ? _kPrimaryColor.withValues(
                                                alpha: 0.55,
                                              )
                                            : _kPrimaryColor.withValues(
                                                alpha: 0.25,
                                              ),
                                        width: 2,
                                      ),
                                    ),
                                    child: Image.network(
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
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          participant.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (isCheckedIn)
                                          const Text(
                                            'ATTENDED',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _kPrimaryColor,
                                            ),
                                          )
                                        else
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Joined',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isCheckedIn)
                                    TextButton(
                                      onPressed: () async {
                                        if (!eventCompleted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Attendance can be updated after the event is completed.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        await _setCheckedIn(
                                          eventId: eventId,
                                          participantUid: participant.uid,
                                          checkedIn: false,
                                        );
                                      },
                                      child: const Text(
                                        'Undo',
                                        style: TextStyle(
                                          color: _kPrimaryColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () async {
                                            if (!eventCompleted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Attendance can be updated after the event is completed.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            await _setCheckedIn(
                                              eventId: eventId,
                                              participantUid: participant.uid,
                                              checkedIn: true,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _kPrimaryColor.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: _kPrimaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () async {
                                            await _removeParticipant(
                                              eventId: eventId,
                                              participantUid: participant.uid,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.grey.shade800
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                  Positioned(
                    bottom: 18,
                    right: 18,
                    child: FloatingActionButton(
                      backgroundColor: _kPrimaryColor,
                      foregroundColor: Colors.white,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'QR scanner integration coming soon.',
                            ),
                          ),
                        );
                      },
                      child: const Icon(Icons.qr_code_scanner),
                    ),
                  ),
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
