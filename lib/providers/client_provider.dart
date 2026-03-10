import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/client_service.dart';

/// Provider per i clienti con:
/// - Real-time listener per la prima pagina
/// - Paginazione cursor-based per "carica altri"
/// - Ricerca per cognome (prefix)
/// - Cache locale per accesso istantaneo
class ClientProvider extends ChangeNotifier {
  final ClientService _service = ClientService();

  List<Client> _clients = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  DocumentSnapshot? _lastDoc;
  StreamSubscription<List<Client>>? _streamSub;

  List<Client> get clients => _clients;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  bool _includeArchived = false;

  /// Inizializza il listener real-time per la prima pagina.
  void init({bool includeArchived = false}) {
    if (_streamSub != null && _includeArchived == includeArchived) return;
    _includeArchived = includeArchived;
    _reset();
    _loading = true;
    notifyListeners();

    _streamSub =
        _service.getClientsStream(includeArchived: includeArchived).listen(
      (list) {
        _clients = list;
        _loading = false;
        _hasMore = list.length >= kClientPageSize;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  /// Carica la pagina successiva (chiamato dallo ScrollController).
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    _loadingMore = true;
    notifyListeners();

    try {
      final rawDocs = await _service.getClientsPageRaw(
        lastDocument: _lastDoc,
        includeArchived: _includeArchived,
      );
      if (rawDocs.isEmpty) {
        _hasMore = false;
      } else {
        _lastDoc = rawDocs.last;
        final newClients = rawDocs.map((d) => Client.fromFirestore(d)).toList();
        _clients = [..._clients, ...newClients];
        _hasMore = rawDocs.length >= kClientPageSize;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Cerca clienti per cognome (prefix). Sostituisce temporaneamente la lista.
  Future<void> search(String query) async {
    if (query.isEmpty) {
      init(includeArchived: _includeArchived);
      return;
    }
    _streamSub?.cancel();
    _streamSub = null;
    _loading = true;
    notifyListeners();
    try {
      _clients =
          await _service.searchClients(query, includeArchived: _includeArchived);
      _hasMore = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _reset() {
    _streamSub?.cancel();
    _streamSub = null;
    _clients = [];
    _lastDoc = null;
    _hasMore = true;
    _error = null;
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}
