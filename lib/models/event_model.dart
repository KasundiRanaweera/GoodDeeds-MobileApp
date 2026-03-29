import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    required this.impactPoints,
    this.eventDate,
    this.imageUrl = '',
    this.organizerName = '',
    this.organizerContactNumber = '',
    this.createdByUid = '',
    this.createdByName = '',
    this.participantsCount = 0,
    this.participantIds = const [],
    this.checkedInIds = const [],
    this.awardedParticipantIds = const [],
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final String category;
  final int impactPoints;
  final DateTime? eventDate;
  final String imageUrl;
  final String organizerName;
  final String organizerContactNumber;
  final String createdByUid;
  final String createdByName;
  final int participantsCount;
  final List<String> participantIds;
  final List<String> checkedInIds;
  final List<String> awardedParticipantIds;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted {
    if (status.toLowerCase() == 'completed') return true;
    if (eventDate == null) return false;
    return DateTime.now().isAfter(eventDate!);
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    String? category,
    int? impactPoints,
    DateTime? eventDate,
    String? imageUrl,
    String? organizerName,
    String? organizerContactNumber,
    String? createdByUid,
    String? createdByName,
    int? participantsCount,
    List<String>? participantIds,
    List<String>? checkedInIds,
    List<String>? awardedParticipantIds,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      category: category ?? this.category,
      impactPoints: impactPoints ?? this.impactPoints,
      eventDate: eventDate ?? this.eventDate,
      imageUrl: imageUrl ?? this.imageUrl,
      organizerName: organizerName ?? this.organizerName,
      organizerContactNumber:
          organizerContactNumber ?? this.organizerContactNumber,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      participantsCount: participantsCount ?? this.participantsCount,
      participantIds: participantIds ?? this.participantIds,
      checkedInIds: checkedInIds ?? this.checkedInIds,
      awardedParticipantIds:
          awardedParticipantIds ?? this.awardedParticipantIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'category': category,
      'impactPoints': impactPoints,
      'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate!),
      'imageUrl': imageUrl,
      'organizerName': organizerName,
      'organizerContactNumber': organizerContactNumber,
      'contactNumber': organizerContactNumber,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'participantsCount': participantsCount,
      'participantIds': participantIds,
      'checkedInIds': checkedInIds,
      'awardedParticipantIds': awardedParticipantIds,
      'status': status,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map, {required String id}) {
    return EventModel(
      id: id,
      title: _parseString(
        map['title'] ?? map['eventName'] ?? map['name'],
        fallback: 'Untitled Event',
      ),
      description: _parseString(
        map['description'] ?? map['details'] ?? map['about'],
      ),
      location: _parseString(map['location'] ?? map['venue'] ?? map['address']),
      category: _parseString(
        map['category'] ?? map['type'] ?? map['eventCategory'],
      ),
      impactPoints: _parseInt(
        map['impactPoints'] ?? map['points'] ?? map['rewardPoints'],
      ),
      eventDate: _parseDate(
        map['eventDate'] ?? map['date'] ?? map['startDate'],
      ),
      imageUrl: _parseString(
        map['imageUrl'] ?? map['bannerUrl'] ?? map['photoUrl'],
      ),
      organizerName: _parseString(map['organizerName'] ?? map['createdByName']),
      organizerContactNumber: _parseString(
        map['organizerContactNumber'] ?? map['contactNumber'] ?? map['phone'],
      ),
      createdByUid: _parseString(
        map['createdByUid'] ??
            map['organizerId'] ??
            map['userId'] ??
            map['ownerId'],
      ),
      createdByName: _parseString(map['createdByName'] ?? map['organizerName']),
      participantsCount: _parseInt(
        map['participantsCount'] ??
            map['participantCount'] ??
            map['joinedCount'],
      ),
      participantIds: _parseStringList(map['participantIds']),
      checkedInIds: _parseStringList(map['checkedInIds']),
      awardedParticipantIds: _parseStringList(map['awardedParticipantIds']),
      status: _parseString(map['status'], fallback: 'active'),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  factory EventModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return EventModel.fromMap(data, id: doc.id);
  }

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
