class Goal {
  int id;
  String type;
  DateTime fromDate;
  DateTime toDate;
  int dailyTarget;
  DateTime? createdAt;

  Goal({
    this.id = 0,
    this.type = 'balanced',
    DateTime? fromDate,
    DateTime? toDate,
    this.dailyTarget = 2000,
    this.createdAt,
  }) : fromDate = fromDate ?? DateTime.now(),
       toDate = toDate ?? DateTime.now().add(const Duration(days: 30));

  bool isActiveForDate(DateTime date) {
    return (date.isAfter(fromDate.subtract(const Duration(days: 1))) ||
            date.isAtSameMomentAs(fromDate)) &&
        (date.isBefore(toDate.add(const Duration(days: 1))) ||
            date.isAtSameMomentAs(toDate));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'dailyTarget': dailyTarget,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static Goal fromJson(Map<String, dynamic> json) {
    return Goal(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: (json['type'] as String?) ?? 'balanced',
      fromDate:
          DateTime.tryParse((json['fromDate'] as String?) ?? '') ??
          DateTime.now(),
      toDate:
          DateTime.tryParse((json['toDate'] as String?) ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      dailyTarget: (json['dailyTarget'] as num?)?.toInt() ?? 2000,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}
