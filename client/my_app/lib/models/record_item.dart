class RecordItem {
  final int id;
  final int userId;
  final int materialId;
  final int count;
  final String type;
  final String status;
  final DateTime? createdAt;
  final String? username;
  final String? name;
  final String? brand;
  final String? spec;

  RecordItem({
    required this.id,
    required this.userId,
    required this.materialId,
    required this.count,
    required this.type,
    required this.status,
    this.createdAt,
    this.username,
    this.name,
    this.brand,
    this.spec,
  });

  factory RecordItem.fromJson(Map<String, dynamic> json) {
    return RecordItem(
      id: json['id'],
      userId: json['user_id'],
      materialId: json['material_id'],
      count: json['count'],
      type: json['type'],
      status: json['status'],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      username: json['username'],
      name: json['name'],
      brand: json['brand'],
      spec: json['spec'],
    );
  }
}
