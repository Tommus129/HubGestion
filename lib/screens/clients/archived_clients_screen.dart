import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import 'client_form_screen.dart';

class ArchivedClientsScreen extends StatefulWidget {
  @override
  _ArchivedClientsScreenState createState() => _ArchivedClientsScreenState();
}

class _ArchivedClientsScreenState extends State<ArchivedClientsScreen> {
  final ClientService _clientService = ClientService();
  final _searchController = TextEditingController();
  List<Client> _allClients = [];
  List<Client> _filtered = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _clientService
        .getClients(includeArchived: true)
        .listen((all) => setState(() {
              // ✅ Solo i clienti archiviati
              _allClients = all.where((c) => c.archiviato).toList();
              _applySearch(_searchController.text);
            }));
  }

  void _applySearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? [..._allClients]
          : _allClients
              .where((c) =>
                  c.fullName.toLowerCase().contains(q.toLowerCase()) ||
                  (c.email ?? '').toLowerCase().contains(q.toLowerCase()))
              .toList();
    });
  }

  Future<void> _riattiva(Client client) async {
    final primary = Theme.of(context).colorScheme.primary;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.unarchive, color: primary),
          SizedBox(width: 8),
          Text('Riattiva Cliente'),
        ]),
        content: Text(
            'Vuoi riattivare "${client.fullName}"?\n'
            'Tornerà disponibile per nuovi appuntamenti.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Annulla')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Riattiva')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _loading = true);
      await _clientService.updateClient(client.id!, {'archiviato': false});
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${client.fullName} riattivato'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth = Provider.of<AuthService>(context);
    final isAdmin = auth.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Archivio Clienti'),
      ),
      drawer: AppDrawer(),
      body: Column(children: [

        // BANNER INFORMATIVO
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.amber.withOpacity(0.12),
          child: Row(children: [
            Icon(Icons.info_outline, size: 16, color: Colors.amber[800]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'I clienti archiviati non appaiono nei nuovi appuntamenti ma mantengono lo storico.',
                style: TextStyle(fontSize: 12, color: Colors.amber[900]),
              ),
            ),
          ]),
        ),

        // BARRA RICERCA
        Padding(
          padding: EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: _applySearch,
            decoration: InputDecoration(
              hintText: 'Cerca cliente archiviato…',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applySearch('');
                      })
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // CONTATORE
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filtered.length} cliente${_filtered.length != 1 ? 'i' : ''} archiviato${_filtered.length != 1 ? 'i' : ''}',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              if (_loading)
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),

        // LISTA
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.archive,
                          size: 64, color: Colors.grey[300]),
                      SizedBox(height: 16),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'Nessun risultato per\n"${_searchController.text}"'
                            : 'Nessun cliente archiviato',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final client = _filtered[i];
                    final initials =
                        '${client.nome[0]}${client.cognome.isNotEmpty ? client.cognome[0] : ''}'
                            .toUpperCase();

                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[400],
                          child: Text(initials,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                        title: Row(children: [
                          Text(client.fullName,
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('ARCHIVIATO',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                          ),
                        ]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (client.email?.isNotEmpty == true)
                              Text(client.email!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            if (client.telefono?.isNotEmpty == true)
                              Row(children: [
                                Icon(Icons.phone,
                                    size: 11, color: Colors.grey),
                                SizedBox(width: 3),
                                Text(client.telefono!,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ]),
                          ],
                        ),
                        trailing: isAdmin
                            ? Tooltip(
                                message: 'Riattiva cliente',
                                child: IconButton(
                                  icon: Icon(Icons.unarchive,
                                      color: primary),
                                  onPressed: () => _riattiva(client),
                                ),
                              )
                            : Icon(Icons.lock_outline,
                                size: 16, color: Colors.grey[300]),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientFormScreen(client: client),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
