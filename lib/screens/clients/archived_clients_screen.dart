import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import 'clients_list_screen.dart';

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
    _clientService.getClients(includeArchived: true).listen((all) {
      setState(() {
        _allClients = all.where((c) => c.archived == true).toList();
        _applySearch(_searchController.text);
      });
    });
  }

  void _applySearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? [..._allClients]
          : _allClients.where((c) {
              return c.fullName.toLowerCase().contains(query) ||
                  (c.email ?? '').toLowerCase().contains(query);
            }).toList();
    });
  }

  Future<void> _riattiva(Client client) async {
    final primary = Theme.of(context).colorScheme.primary;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.unarchive, color: primary),
          const SizedBox(width: 8),
          const Text('Riattiva Cliente'),
        ]),
        content: Text('Vuoi riattivare "${client.fullName}"?\nTornera disponibile per nuovi appuntamenti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Riattiva')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await _clientService.updateClient(client.id!, {'archived': false});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${client.fullName} riattivato'),
          backgroundColor: Colors.green,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth = Provider.of<AuthService>(context);
    final isAdmin = auth.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Archivio Clienti')),
      drawer: AppDrawer(),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.amber.withOpacity(0.12),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber[800]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'I clienti archiviati non appaiono nei nuovi appuntamenti ma mantengono lo storico.',
                  style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                ),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _applySearch,
              decoration: InputDecoration(
                hintText: 'Cerca cliente archiviato...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _searchController.clear(); _applySearch(''); },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filtered.length} clienti archiviati',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (_loading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),

          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.archive, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Nessun risultato'
                              : 'Nessun cliente archiviato',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final client = _filtered[i];
                      final initials =
                          '${client.nome.isNotEmpty ? client.nome[0] : 'C'}'
                          '${client.cognome.isNotEmpty ? client.cognome[0] : ''}'
                          .toUpperCase();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[400],
                            child: Text(initials,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(client.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('ARCHIVIATO',
                                    style: TextStyle(fontSize: 9, color: Colors.grey[600],
                                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (client.email?.isNotEmpty == true)
                                Text(client.email!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (client.telefono?.isNotEmpty == true)
                                Row(children: [
                                  const Icon(Icons.phone, size: 11, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Text(client.telefono!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ]),
                            ],
                          ),
                          trailing: isAdmin
                              ? Tooltip(
                                  message: 'Riattiva cliente',
                                  child: IconButton(
                                    icon: Icon(Icons.unarchive, color: primary),
                                    onPressed: () => _riattiva(client),
                                  ),
                                )
                              : Icon(Icons.lock_outline, size: 16, color: Colors.grey[300]),
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => ClientsListScreen()),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


