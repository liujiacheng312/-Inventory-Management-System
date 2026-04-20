class ManagedUser {
  final int id;
  final String username;
  final String role;
  final DateTime? createdAt;

  const ManagedUser({
    required this.id,
    required this.username,
    required this.role,
    this.createdAt,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  bool get isSuperAdmin => role == 'super_admin';

  bool get isAdmin => role == 'admin' || isSuperAdmin;

  String get roleLabel {
    switch (role) {
      case 'super_admin':
        return '超级管理员';
      case 'admin':
        return '管理员';
      default:
        return '普通用户';
    }
  }
}
