import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';

class ClientService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream real-time — usato solo dove serve aggiornamento live
  Stream<List<Client>> getClients({
    bool includeArchived = false,
    bool onlyArchived = false,
  }) {
    Query query = _db.collection('clients').orderBy('cognome');
    if (onlyArchived) {
      query = query.where('archived', isEqualTo: true);
    } else if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    return query
        .snapshots()
        .map((s) => s.docs.map((d) => Client.fromFirestore(d)).toList());
  }

  // One-shot per form e filtri calendario
  Future<List<Client>> getClientsOnce({
    bool includeArchived = false,
    bool onlyArchived = false,
  }) async {
    Query query = _db.collection('clients').orderBy('cognome');
    if (onlyArchived) {
      query = query.where('archived', isEqualTo: true);
    } else if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    final snap = await query.get();
    return snap.docs.map((d) => Client.fromFirestore(d)).toList();
  }

  // Paginazione: prima pagina
  Future<({List<Client> clients, DocumentSnapshot? lastDoc})> getClientsPaged({
    bool includeArchived = false,
    bool onlyArchived = false,
    int pageSize = 50,
  }) async {
    Query query = _db
        .collection('clients')
        .orderBy('cognome')
        .limit(pageSize);
    if (onlyArchived) {
      query = query.where('archived', isEqualTo: true);
    } else if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    final snap = await query.get();
    final clients = snap.docs.map((d) => Client.fromFirestore(d)).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    return (clients: clients, lastDoc: lastDoc);
  }

  // Paginazione: pagina successiva
  Future<({List<Client> clients, DocumentSnapshot? lastDoc})> getClientsNextPage({
    required DocumentSnapshot lastDoc,
    bool includeArchived = false,
    bool onlyArchived = false,
    int pageSize = 50,
  }) async {
    Query query = _db
        .collection('clients')
        .orderBy('cognome')
        .startAfterDocument(lastDoc)
        .limit(pageSize);
    if (onlyArchived) {
      query = query.where('archived', isEqualTo: true);
    } else if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    final snap = await query.get();
    final clients = snap.docs.map((d) => Client.fromFirestore(d)).toList();
    final newLastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    return (clients: clients, lastDoc: newLastDoc);
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
