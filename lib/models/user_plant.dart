class UserPlant {
  final String id;
  final String name;
  final DateTime plantedAt;
  final int wateringEveryDays;
  final int harvestDays;

  const UserPlant({
    required this.id,
    required this.name,
    required this.plantedAt,
    required this.wateringEveryDays,
    required this.harvestDays,
  });

  DateTime get nextWatering => plantedAt.add(Duration(days: wateringEveryDays));
  DateTime get estimatedHarvest => plantedAt.add(Duration(days: harvestDays));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'plantedAt': plantedAt.toIso8601String(),
        'wateringEveryDays': wateringEveryDays,
        'harvestDays': harvestDays,
      };

  factory UserPlant.fromJson(Map<String, dynamic> json) => UserPlant(
        id: json['id'] as String,
        name: json['name'] as String,
        plantedAt: DateTime.parse(json['plantedAt'] as String),
        wateringEveryDays: json['wateringEveryDays'] as int,
        harvestDays: json['harvestDays'] as int,
      );
}
