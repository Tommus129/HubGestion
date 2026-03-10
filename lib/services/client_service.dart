import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';

/// Dimensione della pagina per la paginazione clienti.
const int kClientPageSize = 50;

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── COMPATIBILITA' LEGACY: alias di getClientsStream ─────────────────
  // Mantenuto per non rompere le screen esistenti che chiamano getClients().
  // Usa getClientsStream() nei nuovi widget.
  Stream<List<Client>> getClients({bool includeArchived = false}) =>
      getClientsStream(includeArchived: includeArchived);

  // ── Stream prima pagina (real-time, usato per la lista principale) ────────
  // Limitato a [kClientPageSize] documenti per evitare letture massicce.
  Stream<List<Client>> getClientsStream({bool includeArchived = false}) {
    Query query = _firestore
        .collection('clients')
        .orderBy('cognome')
        .limit(kClientPageSize);
    if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    return query
        .snapshots()
        .map((snap) => snap.docs.map((d) => Client.fromFirestore(d)).toList());
  }

  // ── Fetch pagina successiva (cursor-based pagination) ─────────────────────
  Future<List<Client>> getClientsPage({
    DocumentSnapshot? lastDocument,
    bool includeArchived = false,
    int pageSize = kClientPageSize,
  }) async {
    Query query = _firestore
        .collection('clients')
        .orderBy('cognome')
        .limit(pageSize);
    if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    final snap = await query.get();
    return snap.docs.map((d) => Client.fromFirestore(d)).toList();
  }

  // ── Fetch DocumentSnapshot grezzo (serve come cursor per la pagina successiva)
  Future<List<DocumentSnapshot>> getClientsPageRaw({
    DocumentSnapshot? lastDocument,
    bool includeArchived = false,
    int pageSize = kClientPageSize,
  }) async {
    Query query = _firestore
        .collection('clients')
        .orderBy('cognome')
        .limit(pageSize);
    if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    final snap = await query.get();
    return snap.docs;
  }

  // ── Ricerca clienti per cognome (prefix search) ────────────────────────────
  // Usa una query range su 'cognome' che è efficiente con l'indice esistente.
  Future<List<Client>> searchClients(String query,
      {bool includeArchived = false}) async {
    if (query.isEmpty) return [];
    final normalized = query[0].toUpperCase() + query.substring(1);
    final endQuery = normalized.substring(0, normalized.length - 1) +
        String.fromCharCode(
            normalized.codeUnitAt(normalized.length - 1) + 1);

    Query q = _firestore
        .collection('clients')
        .where('cognome', isGreaterThanOrEqualTo: normalized)
        .where('cognome', isLessThan: endQuery)
        .limit(30);
    if (!includeArchived) {
      q = q.where('archived', isEqualTo: false);
    }
    final snap = await q.get();
    return snap.docs.map((d) => Client.fromFirestore(d)).toList();
  }

  // ── Single client by ID (con cache locale Firestore SDK) ──────────────────
  Future<Client?> getClientById(String id) async {
    final doc = await _firestore
        .collection('clients')
        .doc(id)
        .get(GetOptions(source: Source.serverAndCache));
    if (!doc.exists) return null;
    return Client.fromFirestore(doc);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<String> createClient(Client client) async {
    final doc = await _firestore.collection('clients').add(client.toFirestore());
    return doc.id;
  }

  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    await _firestore.collection('clients').doc(id).update(data);
  }

  // ── archiveClient: supporta sia la firma legacy (2 argomenti positional)
  //    sia la nuova firma con named parameter {required bool archived}.
  //    Le screen esistenti chiamano: archiveClient(id, bool)
  Future<void> archiveClient(String id, bool archived) async {
    await _firestore
        .collection('clients')
        .doc(id)
        .update({'archived': archived});
  }
}
