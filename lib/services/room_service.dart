import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Room>> getRooms() {
    return _firestore
        .collection('rooms')
        .where('archived', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Room.fromFirestore(d)).toList());
  }

  Future<void> createRoom(Room room) async {
    await _firestore.collection('rooms').add(room.toFirestore());
  }

  Future<void> updateRoom(String id, Map<String, dynamic> data) async {
    await _firestore.collection('rooms').doc(id).update(data);
  }

  Future<void> deleteRoom(String id) async {
    await _firestore.collection('rooms').doc(id).update({'archived': true});
  }
}
