import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String? id;
  final String name;
  final String color;
  final int? capacity;
  final String? note;
  final bool archived;

  Room({
    this.id,
    required this.name,
    required this.color,
    this.capacity,
    this.note,
    this.archived = false,
  });

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Room(
      id: doc.id,
      name: data['name'] ?? '',
      color: data['color'] ?? '#4ECDC4',
      capacity: data['capacity'],
      note: data['note'],
      archived: data['archived'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'color': color,
      'capacity': capacity,
      'note': note ?? '',
      'archived': archived,
    };
  }
}
