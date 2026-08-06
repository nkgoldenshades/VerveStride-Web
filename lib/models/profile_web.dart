class Profile {
  int id;
  String? name;
  double? heightCm;
  double? weightKg;
  int? age;
  String? gender;
  String? profilePhotoPath;
  DateTime? createdAt;
  DateTime? updatedAt;

  Profile({
    this.id = 0,
    this.name,
    this.heightCm,
    this.weightKg,
    this.age,
    this.gender,
    this.profilePhotoPath,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'age': age,
      'gender': gender,
      'profilePhotoPath': profilePhotoPath,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static Profile fromJson(Map<String, dynamic> json) {
    return Profile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      profilePhotoPath: json['profilePhotoPath'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}
