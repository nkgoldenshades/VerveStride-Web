import 'package:flutter/material.dart';

enum ActivityType {
  running('Running', Icons.directions_run, Color(0xFF7C5CFF)),
  walking('Walking', Icons.directions_walk, Color(0xFF19E3D6)),
  cycling('Cycling', Icons.directions_bike, Color(0xFFFFC857)),
  swimming('Swimming', Icons.pool, Colors.blue),
  driving('Driving', Icons.directions_car, Colors.purple),
  motorcycle('Motorcycle', Icons.motorcycle, Colors.orange),
  publicTransport('Public Transport', Icons.directions_bus, Colors.teal),
  truck('Truck', Icons.local_shipping, Colors.brown),
  horseRide('Horse Ride', Icons.pets, Color(0xFF8D6E63)),
  workout('Workout', Icons.fitness_center, Color(0xFFFF6B6B));

  const ActivityType(this.displayName, this.icon, this.color);
  final String displayName;
  final IconData icon;
  final Color color;
}

class ActivityData {
  const ActivityData({
    required this.id,
    required this.type,
    required this.startTime,
    this.endTime,
    this.distance = 0.0,
    this.calories = 0.0,
    this.notes = '',
    this.route = const [],
    this.isPaused = false,
    this.pausedSeconds = 0,
  });

  final String id;
  final ActivityType type;
  final DateTime startTime;
  final DateTime? endTime;
  final double distance;
  final double calories;
  final String notes;
  final List<Map<String, double>> route;
  final bool isPaused;
  final int pausedSeconds;

  ActivityData copyWith({
    DateTime? endTime,
    double? distance,
    double? calories,
    String? notes,
    List<Map<String, double>>? route,
    bool? isPaused,
    int? pausedSeconds,
  }) {
    return ActivityData(
      id: id,
      type: type,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
      notes: notes ?? this.notes,
      route: route ?? List<Map<String, double>>.from(this.route),
      isPaused: isPaused ?? this.isPaused,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    );
  }

  bool get isActive => endTime == null;

  int get durationSeconds {
    final totalElapsed =
        (endTime ?? DateTime.now()).difference(startTime).inSeconds;
    return (totalElapsed - pausedSeconds)
        .clamp(0, 86400 * 365); // Clamp to a reasonable max
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDistance => '${distance.toStringAsFixed(2)} km';

  String get formattedCalories => '${calories.toStringAsFixed(0)} kcal';
}
