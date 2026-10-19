class UserModel {
  final int? id;
  final String name;
  final String username;
  final String email;
  final String passwordHash;
  final String salt;
  final String createdAt;
  final bool synced;

  const UserModel({
    this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'username': username,
        'email': email,
        'password_hash': passwordHash,
        'salt': salt,
        'created_at': createdAt,
        'synced': synced ? 1 : 0,
      };

  factory UserModel.fromMap(Map<String, Object?> m) => UserModel(
        id: m['id'] as int?,
        name: m['name'] as String,
        username: m['username'] as String,
        email: m['email'] as String,
        passwordHash: m['password_hash'] as String,
        salt: m['salt'] as String,
        createdAt: m['created_at'] as String,
        synced: (m['synced'] as int? ?? 0) == 1,
      );
}
