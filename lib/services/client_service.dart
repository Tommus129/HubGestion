import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';

class ClientService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream real-time (usato nel calendario filtri)
  Stream<List<Client>> getClients() {
    return _db
        .collection('clients')
        .where('archiviato', isEqualTo: false)
        .orderBy('cognome')
        .snapshots()
        .map((s) => s.docs.map((d) => Client.fromFirestore(d)).toList());
  }

  // One-shot per form (non serve real-time)
  Future<List<Client>> getClientsOnce() async {
    final snap = await _db
        .collection('clients')
        .where('archiviato', isEqualTo: false)
        .orderBy('cognome')
        .get();
    return snap.docs.map((d) => Client.fromFirestore(d)).toList();
  }

  Future<void> addClient(Client client) async {
    await _db.collection('clients').add(client.toFirestore());
  }

  Future<void> updateClient(
      String id, Map<String, dynamic> data) async {
    await _db.collection('clients').doc(id).update(data);
  }

  Future<void> archiveClient(String id) async {
    await _db.collection('clients')
        .doc(id)
        .update({'archiviato': true});
  }

  Future<Client?> getClientById(String id) async {
    final doc = await _db.collection('clients').doc(id).get();
    if (!doc.exists) return null;
    return Client.fromFirestore(doc);
  }

  Stream<Client> watchClient(String id) {
    return _db
        .collection('clients')
        .doc(id)
        .snapshots()
        .map((d) => Client.fromFirestore(d));
  }
}
