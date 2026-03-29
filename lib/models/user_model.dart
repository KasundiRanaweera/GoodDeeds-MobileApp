import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.roles,
    required this.impactPoints,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final List<String> roles;
  final int impactPoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isVolunteer => hasRole('Volunteer');
  bool get isOrganizer => hasRole('Organizer');

  bool hasRole(String role) {
    final target = role.trim().toLowerCase();
    return roles.any((item) => item.trim().toLowerCase() == target);
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    List<String>? roles,
    int? impactPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      impactPoints: impactPoints ?? this.impactPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'roles': roles,
      'role': roles.isNotEmpty ? roles.first : 'Volunteer',
      'impactPoints': impactPoints,
      'totalPoints': impactPoints,
      'rewardPoints': impactPoints,
      'points': impactPoints,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {required String id}) {
    final parsedRoles = _parseRoles(map);

    return UserModel(
      id: id,
      name: (map['name'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      roles: parsedRoles,
      impactPoints: _parseInt(
        map['impactPoints'] ??
            map['totalPoints'] ??
            map['rewardPoints'] ??
            map['points'],
      ),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserModel.fromMap(data, id: doc.id);
  }

  static List<String> _parseRoles(Map<String, dynamic> map) {
    final rawRoles = map['roles'];
    if (rawRoles is List) {
      final roles = rawRoles
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (roles.isNotEmpty) {
        return roles;
      }
    }

    final fallbackRole = (map['role'] ?? 'Volunteer').toString().trim();
    return fallbackRole.isEmpty ? const ['Volunteer'] : [fallbackRole];
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
}
