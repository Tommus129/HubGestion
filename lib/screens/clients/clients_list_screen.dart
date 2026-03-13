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

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore && _hasMore && _search.isEmpty) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() { _loading = true; _clients = []; _lastDoc = null; _hasMore = true; });
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
        (c.codiceFiscale?.toLowerCase().contains(_search) ?? false) ||
        (c.citta?.toLowerCase().contains(_search) ?? false))
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
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _search = ''); })
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
                ButtonSegment(value: _ClientFilter.attivi, label: Text('Attivi'), icon: Icon(Icons.person, size: 15)),
                ButtonSegment(value: _ClientFilter.tutti, label: Text('Tutti'), icon: Icon(Icons.people, size: 15)),
                ButtonSegment(value: _ClientFilter.archiviati, label: Text('Archiviati'), icon: Icon(Icons.archive, size: 15)),
              ],
              selected: {_filter},
              onSelectionChanged: (s) { setState(() => _filter = s.first); _loadFirstPage(); },
              style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
                      _search.isNotEmpty ? 'Nessun risultato per "$_search"'
                          : _filter == _ClientFilter.archiviati ? 'Nessun cliente archiviato' : 'Nessun cliente',
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

  void _showClientDetail(BuildContext context, Client client, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
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
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: client.archived ? Colors.grey : primary,
                  child: Text(client.nome.isNotEmpty ? client.nome[0].toUpperCase() : 'C',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _badgeSocio(client),
                        if ((client.sesso ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _badgeInfo(client.sesso!, Colors.blueGrey),
                        ],
                        if (client.archived) ...[ const SizedBox(width: 6), _badgeArchiviato() ],
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: primary),
                  tooltip: 'Modifica',
                  onPressed: () { Navigator.pop(context); _showClientDialog(context, primary, client: client); },
                ),
              ]),
              const Divider(height: 28),
              _sectionTitle('Contatto'),
              const SizedBox(height: 10),
              if ((client.email ?? '').isNotEmpty)
                _detailRow(icon: Icons.email_outlined, color: Colors.blue, label: 'Email', value: client.email!, copiable: true),
              if ((client.pec ?? '').isNotEmpty)
                _detailRow(icon: Icons.mark_email_read_outlined, color: Colors.indigo, label: 'PEC', value: client.pec!, copiable: true),
              if ((client.telefono ?? '').isNotEmpty)
                _detailRow(icon: Icons.phone_outlined, color: Colors.green, label: 'Telefono', value: client.telefono!, copiable: true),
              if ((client.telefonoSecondario ?? '').isNotEmpty)
                _detailRow(icon: Icons.phone_callback_outlined, color: Colors.teal, label: 'Tel. secondario', value: client.telefonoSecondario!, copiable: true),
              if ((client.email ?? '').isEmpty && (client.telefono ?? '').isEmpty)
                Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Nessun contatto inserito', style: TextStyle(color: Colors.grey, fontSize: 13))),
              if ((client.codiceFiscale ?? '').isNotEmpty || (client.dataNascita ?? '').isNotEmpty
                  || (client.luogoNascita ?? '').isNotEmpty || (client.indirizzo ?? '').isNotEmpty) ...[
                const Divider(height: 28),
                _sectionTitle('Dati Anagrafici'),
                const SizedBox(height: 10),
                if ((client.codiceFiscale ?? '').isNotEmpty)
                  _detailRow(icon: Icons.badge_outlined, color: Colors.indigo, label: 'Codice Fiscale', value: client.codiceFiscale!, copiable: true),
                if ((client.dataNascita ?? '').isNotEmpty)
                  _detailRow(icon: Icons.cake_outlined, color: Colors.pink, label: 'Data di Nascita', value: client.dataNascita!),
                if ((client.luogoNascita ?? '').isNotEmpty)
                  _detailRow(icon: Icons.location_city_outlined, color: Colors.orange, label: 'Luogo di Nascita', value: client.luogoNascita!),
                if ((client.indirizzo ?? '').isNotEmpty)
                  _detailRow(icon: Icons.home_outlined, color: Colors.teal, label: 'Indirizzo',
                      value: [
                        client.indirizzo,
                        if ((client.cap ?? '').isNotEmpty || (client.citta ?? '').isNotEmpty)
                          '${client.cap ?? ''} ${client.citta ?? ''} ${client.provincia != null ? "(${client.provincia})" : ""}'.trim(),
                        if ((client.nazione ?? '').isNotEmpty && client.nazione != 'Italia') client.nazione,
                      ].whereType<String>().join('\n')),
              ],
              if ((client.codiceSdi ?? '').isNotEmpty || (client.indirizzoFatturazione ?? '').isNotEmpty) ...[
                const Divider(height: 28),
                _sectionTitle('Dati Fatturazione'),
                const SizedBox(height: 10),
                if ((client.codiceSdi ?? '').isNotEmpty)
                  _detailRow(icon: Icons.receipt_long_outlined, color: Colors.deepPurple, label: 'Codice SDI', value: client.codiceSdi!, copiable: true),
                if ((client.indirizzoFatturazione ?? '').isNotEmpty)
                  _detailRow(icon: Icons.home_work_outlined, color: Colors.brown, label: 'Indirizzo Fatturazione',
                      value: [
                        client.indirizzoFatturazione,
                        if ((client.capFatturazione ?? '').isNotEmpty || (client.cittaFatturazione ?? '').isNotEmpty)
                          '${client.capFatturazione ?? ''} ${client.cittaFatturazione ?? ''} ${client.provinciaFatturazione != null ? "(${client.provinciaFatturazione})" : ""}'.trim(),
                        if ((client.nazioneFatturazione ?? '').isNotEmpty && client.nazioneFatturazione != 'Italia') client.nazioneFatturazione,
                      ].whereType<String>().join('\n')),
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
                      _clientService.archiveClient(client.id!, !client.archived).then((_) => _loadFirstPage());
                    },
                    icon: Icon(client.archived ? Icons.unarchive : Icons.archive, size: 16),
                    label: Text(client.archived ? 'Riattiva' : 'Archivia'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _showClientDialog(context, primary, client: client); },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Modifica'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
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

  Widget _badgeInfo(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );

  Widget _detailRow({required IconData icon, required Color color, required String label, required String value, bool copiable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
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
                  SnackBar(content: Text('$label copiato'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showClientDialog(BuildContext context, Color primary, {Client? client}) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ClientFormPage(primary: primary, client: client, onSaved: _loadFirstPage),
    ));
  }

  Widget _badgeSocio(Client c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.isSocio ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(c.isSocio ? 'Socio' : 'Non Socio',
            style: TextStyle(fontSize: 10, color: c.isSocio ? Colors.green[700] : Colors.orange[800], fontWeight: FontWeight.w600)),
      );

  Widget _badgeArchiviato() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
        child: Text('Archiviato', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// FORM PAGE
// ══════════════════════════════════════════════════════════════════════════════
class _ClientFormPage extends StatefulWidget {
  final Color primary;
  final Client? client;
  final VoidCallback onSaved;
  const _ClientFormPage({required this.primary, this.client, required this.onSaved});

  @override
  State<_ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<_ClientFormPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _saving = false;

  late final TextEditingController _nome;
  late final TextEditingController _cognome;
  late final TextEditingController _dataNascita;
  late final TextEditingController _luogoNascita;
  String? _sesso;
  bool _isSocio = true;

  late final TextEditingController _email;
  late final TextEditingController _telefono;
  late final TextEditingController _telefonoSecondario;
  late final TextEditingController _pec;

  late final TextEditingController _indirizzo;
  late final TextEditingController _cap;
  late final TextEditingController _citta;
  late final TextEditingController _provincia;
  late final TextEditingController _nazione;

  late final TextEditingController _codiceFiscale;
  late final TextEditingController _codiceSdi;

  late final TextEditingController _indirizzoFatt;
  late final TextEditingController _capFatt;
  late final TextEditingController _cittaFatt;
  late final TextEditingController _provinciaFatt;
  late final TextEditingController _nazioneFatt;

  late final TextEditingController _genitori;
  late final TextEditingController _note;

  bool _fattUgualeResidenza = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final c = widget.client;
    _nome = TextEditingController(text: c?.nome ?? '');
    _cognome = TextEditingController(text: c?.cognome ?? '');
    _dataNascita = TextEditingController(text: c?.dataNascita ?? '');
    _luogoNascita = TextEditingController(text: c?.luogoNascita ?? '');
    _sesso = c?.sesso;
    _isSocio = c?.isSocio ?? true;
    _email = TextEditingController(text: c?.email ?? '');
    _telefono = TextEditingController(text: c?.telefono ?? '');
    _telefonoSecondario = TextEditingController(text: c?.telefonoSecondario ?? '');
    _pec = TextEditingController(text: c?.pec ?? '');
    _indirizzo = TextEditingController(text: c?.indirizzo ?? '');
    _cap = TextEditingController(text: c?.cap ?? '');
    _citta = TextEditingController(text: c?.citta ?? '');
    _provincia = TextEditingController(text: c?.provincia ?? '');
    _nazione = TextEditingController(text: c?.nazione ?? 'Italia');
    _codiceFiscale = TextEditingController(text: c?.codiceFiscale ?? '');
    _codiceSdi = TextEditingController(text: c?.codiceSdi ?? '');
    _indirizzoFatt = TextEditingController(text: c?.indirizzoFatturazione ?? '');
    _capFatt = TextEditingController(text: c?.capFatturazione ?? '');
    _cittaFatt = TextEditingController(text: c?.cittaFatturazione ?? '');
    _provinciaFatt = TextEditingController(text: c?.provinciaFatturazione ?? '');
    _nazioneFatt = TextEditingController(text: c?.nazioneFatturazione ?? 'Italia');
    _genitori = TextEditingController(text: c?.genitori ?? '');
    _note = TextEditingController(text: c?.note ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _nome, _cognome, _dataNascita, _luogoNascita,
      _email, _telefono, _telefonoSecondario, _pec,
      _indirizzo, _cap, _citta, _provincia, _nazione,
      _codiceFiscale, _codiceSdi,
      _indirizzoFatt, _capFatt, _cittaFatt, _provinciaFatt, _nazioneFatt,
      _genitori, _note,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _copyResidenzaToFatturazione() {
    _indirizzoFatt.text = _indirizzo.text;
    _capFatt.text = _cap.text;
    _cittaFatt.text = _citta.text;
    _provinciaFatt.text = _provincia.text;
    _nazioneFatt.text = _nazione.text;
  }

  Future<void> _save() async {
    if (_nome.text.trim().isEmpty || _cognome.text.trim().isEmpty) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e Cognome sono obbligatori'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _saving = true);
    final newClient = Client(
      id: widget.client?.id,
      nome: _nome.text.trim(),
      cognome: _cognome.text.trim(),
      dataNascita: _dataNascita.text.trim(),
      luogoNascita: _luogoNascita.text.trim(),
      sesso: _sesso,
      email: _email.text.trim(),
      telefono: _telefono.text.trim(),
      telefonoSecondario: _telefonoSecondario.text.trim(),
      pec: _pec.text.trim(),
      indirizzo: _indirizzo.text.trim(),
      cap: _cap.text.trim(),
      citta: _citta.text.trim(),
      provincia: _provincia.text.trim().toUpperCase(),
      nazione: _nazione.text.trim().isEmpty ? 'Italia' : _nazione.text.trim(),
      codiceFiscale: _codiceFiscale.text.trim().toUpperCase(),
      codiceSdi: _codiceSdi.text.trim().toUpperCase(),
      indirizzoFatturazione: _indirizzoFatt.text.trim(),
      capFatturazione: _capFatt.text.trim(),
      cittaFatturazione: _cittaFatt.text.trim(),
      provinciaFatturazione: _provinciaFatt.text.trim().toUpperCase(),
      nazioneFatturazione: _nazioneFatt.text.trim().isEmpty ? 'Italia' : _nazioneFatt.text.trim(),
      genitori: _genitori.text.trim(),
      note: _note.text.trim(),
      isSocio: _isSocio,
    );
    try {
      if (widget.client == null) {
        await ClientService().createClient(newClient);
      } else {
        await ClientService().updateClient(widget.client!.id!, newClient.toFirestore());
      }
      if (mounted) { widget.onSaved(); Navigator.pop(context); }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  /// Riga CAP (20%) + Città (50%) + Provincia (30%) — proporzioni relative, mai troncate
  Widget _rowCapCittaProv(
    TextEditingController capCtrl,
    TextEditingController cittaCtrl,
    TextEditingController provCtrl,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 20,
          child: _field(capCtrl, 'CAP', Icons.local_post_office_outlined,
              keyboard: TextInputType.number),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 50,
          child: _field(cittaCtrl, 'Città', Icons.location_on_outlined),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 30,
          child: _field(provCtrl, 'Provincia', Icons.map_outlined,
              caps: TextCapitalization.characters),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;

    // TabBar estratta dall'AppBar → nessun conflitto con "X" e "SALVA"
    final tabBar = Material(
      color: primary,
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Anagrafica'),
          Tab(icon: Icon(Icons.phone_outlined, size: 20), text: 'Contatti'),
          Tab(icon: Icon(Icons.receipt_long_outlined, size: 20), text: 'Fatturazione'),
          Tab(icon: Icon(Icons.note_outlined, size: 20), text: 'Altro'),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'Nuovo Cliente' : 'Modifica Cliente',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('SALVA',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16,
                          letterSpacing: 1)),
                ),
        ],
      ),
      body: Column(
        children: [
          tabBar,
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── TAB 1: Anagrafica
                _TabScroll(children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _field(_nome, 'Nome *', Icons.person)),
                      const SizedBox(width: 16),
                      Expanded(child: _field(_cognome, 'Cognome *', Icons.person)),
                    ],
                  ),
                  _SocioToggle(value: _isSocio, onChanged: (v) => setState(() => _isSocio = v)),
                  const SizedBox(height: 20),
                  _SectionDivider('Dati anagrafici'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _field(_dataNascita, 'Data di nascita', Icons.cake_outlined,
                          hint: 'gg/mm/aaaa', keyboard: TextInputType.datetime)),
                      const SizedBox(width: 16),
                      Expanded(child: _field(_luogoNascita, 'Luogo di nascita', Icons.location_city_outlined)),
                    ],
                  ),
                  _SectionDivider('Sesso'),
                  Row(children: [
                    Expanded(
                      child: _RadioCard(
                        label: 'Maschio',
                        icon: Icons.male,
                        value: 'M',
                        groupValue: _sesso,
                        primary: primary,
                        onChanged: (v) => setState(() => _sesso = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RadioCard(
                        label: 'Femmina',
                        icon: Icons.female,
                        value: 'F',
                        groupValue: _sesso,
                        primary: primary,
                        onChanged: (v) => setState(() => _sesso = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _SectionDivider('Residenza'),
                  _field(_indirizzo, 'Indirizzo (via + numero civico)', Icons.home_outlined),
                  _rowCapCittaProv(_cap, _citta, _provincia),
                  _field(_nazione, 'Nazione', Icons.flag_outlined),
                ]),

                // ── TAB 2: Contatti
                _TabScroll(children: [
                  _field(_email, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                  _field(_pec, 'PEC', Icons.mark_email_read_outlined, keyboard: TextInputType.emailAddress),
                  _field(_telefono, 'Telefono', Icons.phone_outlined, keyboard: TextInputType.phone),
                  _field(_telefonoSecondario, 'Telefono secondario', Icons.phone_callback_outlined, keyboard: TextInputType.phone),
                ]),

                // ── TAB 3: Fatturazione
                _TabScroll(children: [
                  _SectionDivider('Dati fiscali'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _field(_codiceFiscale, 'Codice Fiscale', Icons.badge_outlined,
                          caps: TextCapitalization.characters)),
                      const SizedBox(width: 16),
                      Expanded(child: _field(_codiceSdi, 'Codice SDI', Icons.receipt_long_outlined,
                          caps: TextCapitalization.characters)),
                    ],
                  ),
                  _SectionDivider('Indirizzo di fatturazione'),
                  _SwitchCard(
                    label: 'Uguale alla residenza',
                    subtitle: 'Copia i dati dalla tab Anagrafica',
                    value: _fattUgualeResidenza,
                    onChanged: (v) {
                      setState(() => _fattUgualeResidenza = v);
                      if (v) _copyResidenzaToFatturazione();
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!_fattUgualeResidenza) ...[
                    _field(_indirizzoFatt, 'Indirizzo fatturazione', Icons.home_work_outlined),
                    _rowCapCittaProv(_capFatt, _cittaFatt, _provinciaFatt),
                    _field(_nazioneFatt, 'Nazione', Icons.flag_outlined),
                  ],
                ]),

                // ── TAB 4: Altro
                _TabScroll(children: [
                  _field(_genitori, 'Genitori / Tutore', Icons.people_outlined),
                  const SizedBox(height: 4),
                  _SectionDivider('Note'),
                  TextField(
                    controller: _note,
                    maxLines: 7,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Note',
                      alignLabelWithHint: true,
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 100),
                        child: Icon(Icons.note_outlined),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    TextCapitalization caps = TextCapitalization.words,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        textCapitalization: caps,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 22),
          // FIX: label non si sovrappone mai a valori precompilati
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────

/// Centra il contenuto su schermi larghi con max 680px
class _TabScroll extends StatelessWidget {
  final List<Widget> children;
  const _TabScroll({required this.children});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500],
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
          const Expanded(child: Divider()),
        ]),
      );
}

/// Card-style radio button per il sesso
class _RadioCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String? groupValue;
  final Color primary;
  final ValueChanged<String?> onChanged;
  const _RadioCard({
    required this.label, required this.icon, required this.value,
    required this.groupValue, required this.primary, required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 22, color: selected ? primary : Colors.grey),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? primary : Colors.grey[700],
              )),
          const Spacer(),
          Radio<String>(
            value: value, groupValue: groupValue,
            onChanged: onChanged,
            activeColor: primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }
}

/// Card-style switch (es. "Uguale alla residenza")
class _SwitchCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchCard({
    required this.label, required this.subtitle,
    required this.value, required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: value ? primary.withOpacity(0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? primary.withOpacity(0.4) : Colors.grey.shade300,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(label,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: value ? primary : Colors.black87)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        value: value,
        onChanged: onChanged,
        activeColor: primary,
      ),
    );
  }
}

class _SocioToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SocioToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: value ? Colors.green.withOpacity(0.05) : Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value ? Colors.green.withOpacity(0.4) : Colors.orange.withOpacity(0.5)),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            value ? 'Socio' : 'Non Socio (+15%)',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15,
                color: value ? Colors.green[700] : Colors.orange[800]),
          ),
          secondary: Icon(
              value ? Icons.card_membership : Icons.person_off,
              color: value ? Colors.green[700] : Colors.orange[800], size: 22),
          value: value,
          activeColor: Colors.green,
          onChanged: onChanged,
        ),
      );
}

// ── CLIENT TILE ──────────────────────────────────────────────────────────────
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
                      Text(client.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 6),
                      _BadgeSocio(client: client),
                      if (client.archived) ...[ const SizedBox(width: 6), const _BadgeArchiviato() ],
                    ]),
                    const SizedBox(height: 2),
                    if ((client.email ?? '').isNotEmpty)
                      _InfoRow(icon: Icons.email_outlined, text: client.email!),
                    if ((client.telefono ?? '').isNotEmpty)
                      _InfoRow(icon: Icons.phone_outlined, text: client.telefono!),
                    if ((client.citta ?? '').isNotEmpty)
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: '${client.citta}${(client.provincia ?? '').isNotEmpty ? " (${client.provincia})" : ""}',
                      ),
                    if ((client.codiceFiscale ?? '').isNotEmpty)
                      _InfoRow(icon: Icons.badge_outlined, text: client.codiceFiscale!),
                    if ((client.note ?? '').isNotEmpty)
                      Row(children: [
                        Icon(Icons.note_outlined, size: 11, color: Colors.amber[700]),
                        const SizedBox(width: 3),
                        Text('Note presenti',
                            style: TextStyle(fontSize: 11, color: Colors.amber[700],
                                fontStyle: FontStyle.italic)),
                      ]),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Modifica'),
                      ])),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(children: [
                      Icon(client.archived ? Icons.unarchive : Icons.archive, size: 16),
                      const SizedBox(width: 8),
                      Text(client.archived ? 'Riattiva' : 'Archivia'),
                    ]),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'archive') onArchive();
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
          color: client.isSocio
              ? Colors.green.withOpacity(0.12)
              : Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          client.isSocio ? 'Socio' : 'Non Socio',
          style: TextStyle(
              fontSize: 10,
              color: client.isSocio ? Colors.green[700] : Colors.orange[800],
              fontWeight: FontWeight.w600),
        ),
      );
}

class _BadgeArchiviato extends StatelessWidget {
  const _BadgeArchiviato();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
        child: Text('Archiviato',
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
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
          Flexible(
              child: Text(text,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis)),
        ],
      );
}
