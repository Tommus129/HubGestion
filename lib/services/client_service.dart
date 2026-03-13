import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';

/// Dimensione di pagina condivisa tra ClientService e ClientProvider.
const int kClientPageSize = 50;

class ClientService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Stream real-time (alias usato dal ClientProvider) ──────────────
  Stream<List<Client>> getClientsStream({
    bool includeArchived = false,
    bool onlyArchived = false,
  }) =>
      getClients(
          includeArchived: includeArchived, onlyArchived: onlyArchived);

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
    int pageSize = kClientPageSize,
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
    int pageSize = kClientPageSize,
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

  /// Ritorna i DocumentSnapshot grezzi per la paginazione del ClientProvider.
  Future<List<DocumentSnapshot>> getClientsPageRaw({
    DocumentSnapshot? lastDocument,
    bool includeArchived = false,
    bool onlyArchived = false,
    int pageSize = kClientPageSize,
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
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    final snap = await query.get();
    return snap.docs;
  }

  /// Ricerca prefix per cognome (usata dal ClientProvider).
  Future<List<Client>> searchClients(
    String query, {
    bool includeArchived = false,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return getClientsOnce(includeArchived: includeArchived);
    // Firestore prefix search: cognome >= q && cognome < q+"\uf8ff"
    final end = '$q\uf8ff';
    Query fsQuery = _db
        .collection('clients')
        .orderBy('cognome')
        .where('cognome', isGreaterThanOrEqualTo: q)
        .where('cognome', isLessThan: end);
    if (!includeArchived) {
      fsQuery = fsQuery.where('archived', isEqualTo: false);
    }
    final snap = await fsQuery.get();
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
