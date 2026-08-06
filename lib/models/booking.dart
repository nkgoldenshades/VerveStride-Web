import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  confirmed,
  rejected,
  completed,
  cancelled,
}

class Booking {
  final String id;
  final String userId;
  final String categoryId;
  final String categoryName;
  final DateTime scheduledTime;
  final int durationMinutes;
  final double price;
  final BookingStatus status;
  final bool requiresVerification;
  final String? expertId;
  final String? expertName;
  final String? notes;
  final DateTime createdAt;
  final DateTime? verifiedAt;

  Booking({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.scheduledTime,
    required this.durationMinutes,
    required this.price,
    required this.status,
    required this.requiresVerification,
    this.expertId,
    this.expertName,
    this.notes,
    required this.createdAt,
    this.verifiedAt,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      userId: data['userId'] ?? '',
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      scheduledTime: (data['scheduledTime'] as Timestamp).toDate(),
      durationMinutes: data['durationMinutes'] ?? 60,
      price: (data['price'] ?? 0).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => BookingStatus.pending,
      ),
      requiresVerification: data['requiresVerification'] ?? false,
      expertId: data['expertId'],
      expertName: data['expertName'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      verifiedAt: data['verifiedAt'] != null
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'durationMinutes': durationMinutes,
      'price': price,
      'status': status.name,
      'requiresVerification': requiresVerification,
      'expertId': expertId,
      'expertName': expertName,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
    };
  }
}
