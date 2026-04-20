class MaterialItem {
  final int id;
  final String name;
  final String brand;
  final String model;
  final String spec;
  int quantity;
  final String remark;
  int borrowedCount;

  MaterialItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.spec,
    required this.quantity,
    this.remark = '',
    this.borrowedCount = 0,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'],
      name: json['name'],
      brand: json['brand'],
      model: json['model'] ?? '',
      spec: json['spec'],
      quantity: json['quantity'],
      remark: json['remark'] ?? '',
      borrowedCount: json['borrowed_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'model': model,
      'spec': spec,
      'quantity': quantity,
      'remark': remark,
    };
  }
}