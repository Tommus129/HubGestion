import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../widgets/app_drawer.dart';

enum _ClientFilter { attivi, tutti, archiviati }

class ClientsListScreen extends StatefulWidget {
  @override
  _ClientsListScreenState createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  final ClientService _clientService = ClientService();
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  _ClientFilter _filter = _ClientFilter.attivi;
  String _search = '';
  Timer? _debounce;

  List<Client> _clients = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Scroll infinito: carica più clienti quando arrivi in fondo
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        _search.isEmpty) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _clients = [];
      _lastDoc = null;
      _hasMore = true;
    });
    try {
      final result = await _clientService.getClientsPaged(
        includeArchived: _filter == _ClientFilter.tutti,
        onlyArchived: _filter == _ClientFilter.archiviati,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _clients = result.clients;
        _lastDoc = result.lastDoc;
        _hasMore = result.clients.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_lastDoc == null || !_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _clientService.getClientsNextPage(
        lastDoc: _lastDoc!,
        includeArchived: _filter == _ClientFilter.tutti,
        onlyArchived: _filter == _ClientFilter.archiviati,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _clients.addAll(result.clients);
        _lastDoc = result.lastDoc ?? _lastDoc;
        _hasMore = result.clients.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  // Quando si cerca del testo usa lo stream (risultati live filtrati in memoria)
  // Quando il campo è vuoto usa la lista paginata già caricata
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _search = value.toLowerCase());
    });
  }

  List<Client> get _filteredClients {
    if (_search.isEmpty) return _clients;
    return _clients.where((c) =>
        c.fullName.toLowerCase().contains(_search) ||
        (c.email?.toLowerCase().contains(_search) ?? false) ||
        (c.telefono?.toLowerCase().contains(_search) ?? false) ||
        (c.codiceFiscale?.toLowerCase().contains(_search) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final displayed = _filteredClients;

    return Scaffold(
      appBar: AppBar(title: const Text('Clienti')),
      drawer: AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca cliente...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SegmentedButton<_ClientFilter>(
              segments: const [
                ButtonSegment(
                  value: _ClientFilter.attivi,
                  label: Text('Attivi'),
                  icon: Icon(Icons.person, size: 15),
                ),
                ButtonSegment(
                  value: _ClientFilter.tutti,
                  label: Text('Tutti'),
                  icon: Icon(Icons.people, size: 15),
                ),
                ButtonSegment(
                  value: _ClientFilter.archiviati,
                  label: Text('Archiviati'),
                  icon: Icon(Icons.archive, size: 15),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (s) {
                setState(() => _filter = s.first);
                _loadFirstPage();
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (displayed.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      _search.isNotEmpty
                          ? 'Nessun risultato per "$_search"'
                          : _filter == _ClientFilter.archiviati
                              ? 'Nessun cliente archiviato'
                              : 'Nessun cliente',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFirstPage,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: displayed.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == displayed.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final client = displayed[i];
                    return _ClientTile(
                      key: ValueKey(client.id),
                      client: client,
                      primary: primary,
                      onTap: () => _showClientDetail(context, client, primary),
                      onEdit: () => _showClientDialog(context, primary, client: client),
                      onArchive: () => _clientService.archiveClient(client.id!, !client.archived).then((_) => _loadFirstPage()),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClientDialog(context, primary),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nuovo Cliente', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ── Detail bottom sheet ──────────────────────────────────────────────────────
  void _showClientDetail(BuildContext context, Client client, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
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
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: client.archived ? Colors.grey : primary,
                  child: Text(
                    client.nome.isNotEmpty ? client.nome[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.fullName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      _badgeSocio(client),
                      if (client.archived) ...[
                        const SizedBox(height: 4),
                        _badgeArchiviato(),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: primary),
                  tooltip: 'Modifica',
                  onPressed: () {
                    Navigator.pop(context);
                    _showClientDialog(context, primary, client: client);
                  },
                ),
              ]),
              const Divider(height: 28),
              _sectionTitle('Contatto'),
              const SizedBox(height: 10),
              if ((client.email ?? '').isNotEmpty)
                _detailRow(icon: Icons.email_outlined, color: Colors.blue, label: 'Email', value: client.email!, copiable: true),
              if ((client.telefono ?? '').isNotEmpty)
                _detailRow(icon: Icons.phone_outlined, color: Colors.green, label: 'Telefono', value: client.telefono!, copiable: true),
              if ((client.email ?? '').isEmpty && (client.telefono ?? '').isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Nessun contatto inserito', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              if ((client.codiceFiscale ?? '').isNotEmpty || (client.indirizzo ?? '').isNotEmpty) ...[
                const Divider(height: 28),
                _sectionTitle('Dati Anagrafici'),
                const SizedBox(height: 10),
                if ((client.codiceFiscale ?? '').isNotEmpty)
                  _detailRow(icon: Icons.badge_outlined, color: Colors.indigo, label: 'Codice Fiscale', value: client.codiceFiscale!, copiable: true),
                if ((client.indirizzo ?? '').isNotEmpty)
                  _detailRow(icon: Icons.home_outlined, color: Colors.teal, label: 'Indirizzo', value: client.indirizzo!),
              ],
              if ((client.genitori ?? '').isNotEmpty) ...[
                const Divider(height: 28),
                _sectionTitle('Genitori / Tutore'),
                const SizedBox(height: 10),
                _detailRow(icon: Icons.people_outlined, color: Colors.purple, label: 'Genitori / Tutore', value: client.genitori!),
              ],
              if ((client.note ?? '').isNotEmpty) ...[
                const Divider(height: 28),
                _sectionTitle('Note'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(client.note!, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _clientService.archiveClient(client.id!, !client.archived)
                          .then((_) => _loadFirstPage());
                    },
                    icon: Icon(client.archived ? Icons.unarchive : Icons.archive, size: 16),
                    label: Text(client.archived ? 'Riattiva' : 'Archivia'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showClientDialog(context, primary, client: client);
                    },
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

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.8));

  Widget _detailRow({required IconData icon, required Color color, required String label, required String value, bool copiable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (copiable)
            IconButton(
              icon: Icon(Icons.copy, size: 16, color: Colors.grey[400]),
              tooltip: 'Copia',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('$label copiato'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Dialog crea/modifica cliente ───────────────────────────────────────────────
  void _showClientDialog(BuildContext context, Color primary, {Client? client}) {
    final nomeController = TextEditingController(text: client?.nome ?? '');
    final cognomeController = TextEditingController(text: client?.cognome ?? '');
    final emailController = TextEditingController(text: client?.email ?? '');
    final telefonoController = TextEditingController(text: client?.telefono ?? '');
    final noteController = TextEditingController(text: client?.note ?? '');
    final genitoriController = TextEditingController(text: client?.genitori ?? '');
    final cfController = TextEditingController(text: client?.codiceFiscale ?? '');
    final indirizzoController = TextEditingController(text: client?.indirizzo ?? '');
    bool isSocio = client?.isSocio ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(client == null ? 'Nuovo Cliente' : 'Modifica Cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: TextField(
                      controller: nomeController,
                      decoration: InputDecoration(labelText: 'Nome *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                      controller: cognomeController,
                      decoration: InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                ]),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isSocio ? Colors.green.withOpacity(0.05) : Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSocio ? Colors.green.withOpacity(0.35) : Colors.orange.withOpacity(0.45)),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(
                      isSocio ? 'Socio' : 'Non Socio (+15%)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                          color: isSocio ? Colors.green[700] : Colors.orange[800]),
                    ),
                    secondary: Icon(
                      isSocio ? Icons.card_membership : Icons.person_off,
                      color: isSocio ? Colors.green[700] : Colors.orange[800], size: 20,
                    ),
                    value: isSocio,
                    activeColor: Colors.green,
                    onChanged: (v) => setDialogState(() => isSocio = v),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 12),
                TextField(
                    controller: telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: 'Telefono', prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Dati Anagrafici (facoltativi)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: cfController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: 'Codice Fiscale', prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: indirizzoController,
                  decoration: InputDecoration(labelText: 'Indirizzo', prefixIcon: const Icon(Icons.home_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: genitoriController,
                  decoration: InputDecoration(labelText: 'Genitori / Tutore', prefixIcon: const Icon(Icons.people_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Note', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: 'Note', prefixIcon: const Icon(Icons.note_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                if (nomeController.text.isEmpty || cognomeController.text.isEmpty) return;
                final newClient = Client(
                  id: client?.id,
                  nome: nomeController.text.trim(),
                  cognome: cognomeController.text.trim(),
                  email: emailController.text.trim(),
                  telefono: telefonoController.text.trim(),
                  note: noteController.text.trim(),
                  genitori: genitoriController.text.trim(),
                  codiceFiscale: cfController.text.trim().toUpperCase(),
                  indirizzo: indirizzoController.text.trim(),
                  isSocio: isSocio,
                );
                if (client == null) {
                  await ClientService().createClient(newClient);
                } else {
                  await ClientService().updateClient(client.id!, newClient.toFirestore());
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadFirstPage(); // Ricarica lista dopo modifica
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
              child: Text(client == null ? 'Crea' : 'Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeSocio(Client c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.isSocio ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          c.isSocio ? 'Socio' : 'Non Socio',
          style: TextStyle(fontSize: 10, color: c.isSocio ? Colors.green[700] : Colors.orange[800], fontWeight: FontWeight.w600),
        ),
      );

  Widget _badgeArchiviato() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
        child: Text('Archiviato', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      );
}

// ── CLIENT TILE (widget separato con key per evitare rebuild inutili) ────────────────────
class _ClientTile extends StatelessWidget {
  final Client client;
  final Color primary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _ClientTile({
    super.key,
    required this.client,
    required this.primary,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: client.archived ? Colors.grey : primary,
                child: Text(
                  client.nome.isNotEmpty ? client.nome[0].toUpperCase() : 'C',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 6),
                      _BadgeSocio(client: client),
                      if (client.archived) ...[
                        const SizedBox(width: 6),
                        _BadgeArchiviato(),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    if ((client.email ?? '').isNotEmpty)
                      _InfoRow(icon: Icons.email_outlined, text: client.email!),
                    if ((client.telefono ?? '').isNotEmpty)
                      _InfoRow(icon: Icons.phone_outlined, text: client.telefono!),
                    if ((client.codiceFiscale ?? '').isNotEmpty)
                      _InfoRow(icon: Icons.badge_outlined, text: client.codiceFiscale!),
                    if ((client.note ?? '').isNotEmpty)
                      Row(children: [
                        Icon(Icons.note_outlined, size: 11, color: Colors.amber[700]),
                        const SizedBox(width: 3),
                        Text('Note presenti', style: TextStyle(fontSize: 11, color: Colors.amber[700], fontStyle: FontStyle.italic)),
                      ]),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Modifica')])),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(children: [
                      Icon(client.archived ? Icons.unarchive : Icons.archive, size: 16),
                      const SizedBox(width: 8),
                      Text(client.archived ? 'Riattiva' : 'Archivia'),
                    ]),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'archive') onArchive();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeSocio extends StatelessWidget {
  final Client client;
  const _BadgeSocio({required this.client});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: client.isSocio ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          client.isSocio ? 'Socio' : 'Non Socio',
          style: TextStyle(fontSize: 10, color: client.isSocio ? Colors.green[700] : Colors.orange[800], fontWeight: FontWeight.w600),
        ),
      );
}

class _BadgeArchiviato extends StatelessWidget {
  const _BadgeArchiviato();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
        child: Text('Archiviato', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 11, color: Colors.grey[500]),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      );
}
