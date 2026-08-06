import 'package:cloud_firestore/cloud_firestore.dart';

enum CreditTransactionType {
  purchase,
  usage,
  refund,
  bonus,
}

class CreditTransaction {
  final String id;
  final String userId;
  final int amount; // positive for purchase/bonus, negative for usage
  final CreditTransactionType type;
  final DateTime timestamp;
  final String? description;
  final String? relatedId; // payment ID or AI request ID

  CreditTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.timestamp,
    this.description,
    this.relatedId,
  });

  factory CreditTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: data['amount'] ?? 0,
      type: CreditTransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => CreditTransactionType.usage,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      description: data['description'],
      relatedId: data['relatedId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
      'relatedId': relatedId,
    };
  }
}

class CreditPackage {
  final String key;
  final String name;
  final int credits;
  final double priceUsd;
  final double priceInr;
  final String? badge;
  final int? bonusCredits;

  const CreditPackage({
    required this.key,
    required this.name,
    required this.credits,
    required this.priceUsd,
    required this.priceInr,
    this.badge,
    this.bonusCredits,
  });

  int get totalCredits => credits + (bonusCredits ?? 0);

  String displayUsd() => '\$${priceUsd.toStringAsFixed(2)}';
  String displayInr() => '₹${_inrFormatted()}';

  String _inrFormatted() {
    final s = priceInr.toStringAsFixed(0);
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final withCommas = rest.replaceAllMapped(
      RegExp(r'(\d{1,2})(?=(\d{2})+$)'),
      (m) => '${m[1]},',
    );
    return '$withCommas,$last3';
  }
}
