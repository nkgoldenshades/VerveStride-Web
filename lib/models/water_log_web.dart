class WaterLogIsar {
  int id;
  String dayKey;
  int amountMl;
  DateTime updatedAt;

  WaterLogIsar({
    this.id = 0,
    required this.dayKey,
    this.amountMl = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dayKey': dayKey,
      'amountMl': amountMl,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WaterLogIsar.fromJson(Map<String, dynamic> json) {
    return WaterLogIsar(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dayKey: json['dayKey']?.toString() ?? '',
      amountMl: (json['amountMl'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}
