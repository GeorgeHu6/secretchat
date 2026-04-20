enum KeyAlgorithm { rsa, ecc }

enum KeyType { publicKey, privateKey }

class KeyPair {
  final String id;
  final KeyAlgorithm algorithm;
  final int keySize;
  final String publicKeyPem;
  final String? privateKeyPem;
  final DateTime createdAt;
  final String? name;

  KeyPair({
    required this.id,
    required this.algorithm,
    required this.keySize,
    required this.publicKeyPem,
    this.privateKeyPem,
    required this.createdAt,
    this.name,
  });

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return algorithmName;
  }

  String get algorithmName {
    switch (algorithm) {
      case KeyAlgorithm.rsa:
        return 'RSA-$keySize';
      case KeyAlgorithm.ecc:
        return 'ECC-P256';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'algorithm': algorithm.name,
      'keySize': keySize,
      'publicKeyPem': publicKeyPem,
      'privateKeyPem': privateKeyPem,
      'createdAt': createdAt.toIso8601String(),
      'name': name,
    };
  }

  factory KeyPair.fromJson(Map<String, dynamic> json) {
    return KeyPair(
      id: json['id'],
      algorithm: KeyAlgorithm.values.firstWhere(
        (e) => e.name == json['algorithm'],
        orElse: () => KeyAlgorithm.rsa,
      ),
      keySize: json['keySize'],
      publicKeyPem: json['publicKeyPem'],
      privateKeyPem: json['privateKeyPem'],
      createdAt: DateTime.parse(json['createdAt']),
      name: json['name'],
    );
  }

  KeyPair copyWith({
    String? id,
    KeyAlgorithm? algorithm,
    int? keySize,
    String? publicKeyPem,
    String? privateKeyPem,
    DateTime? createdAt,
    String? name,
  }) {
    return KeyPair(
      id: id ?? this.id,
      algorithm: algorithm ?? this.algorithm,
      keySize: keySize ?? this.keySize,
      publicKeyPem: publicKeyPem ?? this.publicKeyPem,
      privateKeyPem: privateKeyPem ?? this.privateKeyPem,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
    );
  }
}
