import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Client>> getClients({bool includeArchived = false}) {
    Query query = _firestore.collection('clients');
    if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    return query.snapshots()
        .map((snap) => snap.docs.map((d) => Client.fromFirestore(d)).toList());
  }

  Future<void> createClient(Client client) async {
    await _firestore.collection('clients').add(client.toFirestore());
  }

  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    await _firestore.collection('clients').doc(id).update(data);
  }

  Future<void> archiveClient(String id, bool archived) async {
    await _firestore.collection('clients').doc(id).update({'archived': archived});
  }
}
