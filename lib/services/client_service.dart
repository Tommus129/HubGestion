import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';

class ClientService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream real-time con supporto archiviati (usato in ClientsListScreen)
  Stream<List<Client>> getClients({bool includeArchived = false}) {
    Query query = _db.collection('clients').orderBy('cognome');
    if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    return query
        .snapshots()
        .map((s) => s.docs.map((d) => Client.fromFirestore(d)).toList());
  }

  // One-shot per form (non serve real-time)
  Future<List<Client>> getClientsOnce({bool includeArchived = false}) async {
    Query query = _db.collection('clients').orderBy('cognome');
    if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    final snap = await query.get();
    return snap.docs.map((d) => Client.fromFirestore(d)).toList();
  }

  Future<String> createClient(Client client) async {
    final doc = await _db.collection('clients').add(client.toFirestore());
    return doc.id;
  }

  Future<void> addClient(Client client) async {
    await _db.collection('clients').add(client.toFirestore());
  }

  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    await _db.collection('clients').doc(id).update(data);
  }

  // Archivia o riattiva un cliente (toggle)
  Future<void> archiveClient(String id, [bool archive = true]) async {
    await _db.collection('clients').doc(id).update({'archived': archive});
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
