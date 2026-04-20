class User {
  final int id;
  final String username;
  final String role;
  final String token;

  User({
    required this.id,
    required this.username,
    required this.role,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user']['id'],
      username: json['user']['username'],
      role: json['user']['role'],
      token: json['token'],
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
