/// Tanaman yang dipilih user (tabel user_plants).
class UserPlant {
  /// Id di database; null untuk tanaman yang belum disimpan.
  final int? id;
  final String name;
  final DateTime plantedAt;
  final int wateringEveryDays;
  final int harvestDays;

  const UserPlant({
    this.id,
    required this.name,
    required this.plantedAt,
    required this.wateringEveryDays,
    required this.harvestDays,
  });

  DateTime get nextWatering => plantedAt.add(Duration(days: wateringEveryDays));
  DateTime get estimatedHarvest => plantedAt.add(Duration(days: harvestDays));

  /// Untuk disimpan ke SQLite (kolom user_plants).
  Map<String, Object?> toMap(int userId) => {
        'user_id': userId,
        'plant_name': name,
        'planted_at': plantedAt.toIso8601String(),
        'watering_every_days': wateringEveryDays,
        'harvest_days': harvestDays,
      };

  factory UserPlant.fromMap(Map<String, Object?> map) => UserPlant(
        id: map['id'] as int?,
        name: map['plant_name'] as String,
        plantedAt: DateTime.parse(map['planted_at'] as String),
        wateringEveryDays: map['watering_every_days'] as int,
        harvestDays: map['harvest_days'] as int,
      );
}