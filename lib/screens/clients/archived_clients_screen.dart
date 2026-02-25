import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';

class ArchivedClientsScreen extends StatefulWidget {
  @override
  _ArchivedClientsScreenState createState() => _ArchivedClientsScreenState();
}

class _ArchivedClientsScreenState extends State<ArchivedClientsScreen> {
  final ClientService _clientService = ClientService();
  final _searchController = TextEditingController();

  List<Client> _allClients = [];
  List<Client> _filtered   = [];
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
          : _allClients.where((c) =>
              c.fullName.toLowerCase().contains(query) ||
              (c.email ?? '').toLowerCase().contains(query) ||
              (c.telefono ?? '').toLowerCase().contains(query),
            ).toList();
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
        content: Text('Vuoi riattivare "${client.fullName}"?\nTornerà disponibile per nuovi appuntamenti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
            child: const Text('Riattiva'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await _clientService.updateClient(client.id!, {'archived': false});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${client.fullName} riattivato'),
        backgroundColor: Colors.green,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Stesso dialog di ClientsListScreen ────────────────────────────────────
  void _showClientDialog(BuildContext context, Color primary, Client client) {
    final nomeController     = TextEditingController(text: client.nome);
    final cognomeController  = TextEditingController(text: client.cognome);
    final emailController    = TextEditingController(text: client.email ?? '');
    final telefonoController = TextEditingController(text: client.telefono ?? '');
    final noteController     = TextEditingController(text: client.note ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifica Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: TextField(
                  controller: nomeController,
                  decoration: InputDecoration(
                    labelText: 'Nome *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: cognomeController,
                  decoration: InputDecoration(
                    labelText: 'Cognome *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefono',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Note',
                  prefixIcon: const Icon(Icons.note_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              if (nomeController.text.trim().isEmpty || cognomeController.text.trim().isEmpty) return;
              await _clientService.updateClient(client.id!, {
                'nome':     nomeController.text.trim(),
                'cognome':  cognomeController.text.trim(),
                'email':    emailController.text.trim(),
                'telefono': telefonoController.text.trim(),
                'note':     noteController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet dettaglio (come clients_list_screen) ─────────────────────
  void _showClientDetail(BuildContext context, Client client, Color primary, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey,
                  child: Text(
                    client.nome.isNotEmpty ? client.nome[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      child: const Text('Archiviato', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                )),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: primary),
                  tooltip: 'Modifica',
                  onPressed: () {
                    Navigator.pop(context);
                    _showClientDialog(context, primary, client);
                  },
                ),
              ]),
              const Divider(height: 28),

              if ((client.email ?? '').isNotEmpty)
                _detailRow(icon: Icons.email_outlined, color: Colors.blue,
                    label: 'Email', value: client.email!),
              if ((client.telefono ?? '').isNotEmpty)
                _detailRow(icon: Icons.phone_outlined, color: Colors.green,
                    label: 'Telefono', value: client.telefono!),
              if ((client.note ?? '').isNotEmpty) ...[
                const Divider(height: 28),
                Text('Note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey[500], letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(client.note!,
                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                if (isAdmin)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { Navigator.pop(context); _riattiva(client); },
                      icon: const Icon(Icons.unarchive, size: 16),
                      label: const Text('Riattiva'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green.shade300)),
                    ),
                  ),
                if (isAdmin) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _showClientDialog(context, primary, client); },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Modifica'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primary, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow({required IconData icon, required Color color,
      required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        )),
        IconButton(
          icon: Icon(Icons.copy, size: 16, color: Colors.grey[400]),
          tooltip: 'Copia',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$label copiato'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ));
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth    = Provider.of<AuthService>(context);
    final isAdmin = auth.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Archivio Clienti')),
      drawer: AppDrawer(),
      body: Column(
        children: [
          // Banner info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.amber.withOpacity(0.10),
            child: Row(children: [
              Icon(Icons.info_outline, size: 15, color: Colors.amber[800]),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'I clienti archiviati non appaiono nei nuovi appuntamenti ma mantengono lo storico.',
                style: TextStyle(fontSize: 12, color: Colors.amber[900]),
              )),
            ]),
          ),

          // Ricerca
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

          // Contatore
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_filtered.length} clienti archiviati',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13,
                        fontWeight: FontWeight.w500)),
                if (_loading)
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Column(
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
                  ))
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          // ✅ Apre il bottom sheet con dettaglio + modifica
                          onTap: () => _showClientDetail(context, client, primary, isAdmin),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey[400],
                                child: Text(initials,
                                    style: const TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(client.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                                  ]),
                                  const SizedBox(height: 2),
                                  if ((client.email ?? '').isNotEmpty)
                                    Row(children: [
                                      Icon(Icons.email_outlined, size: 11, color: Colors.grey[500]),
                                      const SizedBox(width: 3),
                                      Text(client.email!,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    ]),
                                  if ((client.telefono ?? '').isNotEmpty)
                                    Row(children: [
                                      Icon(Icons.phone_outlined, size: 11, color: Colors.grey[500]),
                                      const SizedBox(width: 3),
                                      Text(client.telefono!,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    ]),
                                ],
                              )),
                              // Azioni rapide
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAdmin)
                                    Tooltip(
                                      message: 'Riattiva cliente',
                                      child: IconButton(
                                        icon: Icon(Icons.unarchive, color: Colors.green[600], size: 20),
                                        onPressed: () => _riattiva(client),
                                      ),
                                    ),
                                  Tooltip(
                                    message: 'Modifica',
                                    child: IconButton(
                                      icon: Icon(Icons.edit_outlined, color: primary, size: 20),
                                      onPressed: () => _showClientDialog(context, primary, client),
                                    ),
                                  ),
                                ],
                              ),
                            ]),
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
