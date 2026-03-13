import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';

class RoomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream real-time (usato nel calendario)
  Stream<List<Room>> getRooms() {
    return _db
        .collection('rooms')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => Room.fromFirestore(d)).toList());
  }

  // One-shot per form (non serve real-time)
  Future<List<Room>> getRoomsOnce() async {
    final snap = await _db.collection('rooms').orderBy('name').get();
    return snap.docs.map((d) => Room.fromFirestore(d)).toList();
  }

  /// Alias di addRoom — usato da rooms_screen
  Future<void> createRoom(Room room) async {
    await _db.collection('rooms').add(room.toFirestore());
  }

  Future<void> addRoom(Room room) async {
    await _db.collection('rooms').add(room.toFirestore());
  }

  Future<void> updateRoom(String id, Map<String, dynamic> data) async {
    await _db.collection('rooms').doc(id).update(data);
  }

  Future<void> deleteRoom(String id) async {
    await _db.collection('rooms').doc(id).delete();
  }
}
