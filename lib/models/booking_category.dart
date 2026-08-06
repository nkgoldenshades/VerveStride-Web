import 'package:cloud_firestore/cloud_firestore.dart';

class BookingCategory {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool requiresVerification;
  final double pricePerSession;
  final int durationMinutes;

  BookingCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.requiresVerification,
    required this.pricePerSession,
    required this.durationMinutes,
  });

  factory BookingCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingCategory(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '📋',
      description: data['description'] ?? '',
      requiresVerification: data['requiresVerification'] ?? false,
      pricePerSession: (data['pricePerSession'] ?? 0).toDouble(),
      durationMinutes: data['durationMinutes'] ?? 60,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'description': description,
      'requiresVerification': requiresVerification,
      'pricePerSession': pricePerSession,
      'durationMinutes': durationMinutes,
    };
  }

  static List<BookingCategory> getDefaultCategories() {
    return [
      BookingCategory(
        id: 'general_training',
        name: 'General Training',
        icon: '💪',
        description: 'Basic fitness training sessions',
        requiresVerification: false,
        pricePerSession: 500,
        durationMinutes: 60,
      ),
      BookingCategory(
        id: 'yoga',
        name: 'Yoga',
        icon: '🧘',
        description: 'Yoga and meditation sessions',
        requiresVerification: false,
        pricePerSession: 400,
        durationMinutes: 60,
      ),
      BookingCategory(
        id: 'nutrition_expert',
        name: 'Nutrition Expert',
        icon: '🥗',
        description: 'Expert nutrition consultation',
        requiresVerification: true,
        pricePerSession: 1500,
        durationMinutes: 45,
      ),
      BookingCategory(
        id: 'physiotherapy',
        name: 'Physiotherapy',
        icon: '🏥',
        description: 'Professional physiotherapy sessions',
        requiresVerification: true,
        pricePerSession: 2000,
        durationMinutes: 60,
      ),
      BookingCategory(
        id: 'sports_coach',
        name: 'Sports Coach',
        icon: '⚽',
        description: 'Specialized sports coaching',
        requiresVerification: true,
        pricePerSession: 1800,
        durationMinutes: 90,
      ),
    ];
  }
}
