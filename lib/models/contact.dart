import 'dart:convert';

class Contact {
  final String id;
  final String name;
  final String? publicKeyPem;
  final String? privateKeyId;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.name,
    this.publicKeyPem,
    this.privateKeyId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'publicKeyPem': publicKeyPem,
      'privateKeyId': privateKeyId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      name: json['name'],
      publicKeyPem: json['publicKeyPem'],
      privateKeyId: json['privateKeyId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Contact copyWith({
    String? id,
    String? name,
    String? publicKeyPem,
    String? privateKeyId,
    DateTime? createdAt,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      publicKeyPem: publicKeyPem ?? this.publicKeyPem,
      privateKeyId: privateKeyId ?? this.privateKeyId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
