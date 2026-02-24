import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/appointment.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../utils/date_helpers.dart';

class ClientReportScreen extends StatefulWidget {
  @override
  _ClientReportScreenState createState() => _ClientReportScreenState();
}

class _ClientReportScreenState extends State<ClientReportScreen> {
  final ClientService _clientService = ClientService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Client? _selectedClient;
  String _periodoType = 'mese';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear  = DateTime.now().year;
  DateTime? _customFrom;
  DateTime? _customTo;
  String _filtroFatturato = 'tutti';
  String _filtroPageto    = 'tutti';

  List<Client> _clients = [];
  List<Appointment> _allFetched = [];
  List<Appointment> _appointments = [];
  Map<String, String> _userNames = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _clientService.getClients().listen((c) => setState(() => _clients = c));
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    final snap = await _db.collection('users').get();
    setState(() {
      _userNames = {
        for (final d in snap.docs)
          d.id: (d.data()['displayName']?.toString().isNotEmpty == true
              ? d.data()['displayName']
              : d.data()['email']) ?? d.id
      };
    });
  }

  Future<void> _autoSearch() async {
    if (_selectedClient == null) return;
    if (_periodoType == 'custom' && (_customFrom == null || _customTo == null)) return;
    setState(() { _loading = true; _appointments = []; _allFetched = []; });
    try {
      final snap = await _db
          .collection('appointments')
          .where('clientId', isEqualTo: _selectedClient!.id)
          .get();
      final all = snap.docs.map((d) {
        try { return Appointment.fromFirestore(d); } catch (_) { return null; }
      }).whereType<Appointment>().toList()
        ..sort((a, b) => a.data.compareTo(b.data));
      setState(() { _allFetched = all; });
      _applyLocalFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    }
  }

  void _applyLocalFilters() {
    DateTime start;
    DateTime end;
    switch (_periodoType) {
      case 'mese':
        start = DateTime(_selectedYear, _selectedMonth, 1);
        end   = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
        break;
      case 'anno':
        start = DateTime(_selectedYear, 1, 1);
        end   = DateTime(_selectedYear, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        if (_customFrom == null || _customTo == null) return;
        start = _customFrom!;
        end   = DateTime(_customTo!.year, _customTo!.month, _customTo!.day, 23, 59, 59);
        break;
      default:
        start = DateTime(2000); end = DateTime(2099);
    }
    List<Appointment> f = _allFetched.where((a) {
      if (a.deleted == true) return false;
      if (a.data.isBefore(start) || a.data.isAfter(end)) return false;
      return true;
    }).toList();
    if (_filtroFatturato == 'si') f = f.where((a) => a.fatturato).toList();
    if (_filtroFatturato == 'no') f = f.where((a) => !a.fatturato).toList();
    if (_filtroPageto    == 'si') f = f.where((a) => a.pagato).toList();
    if (_filtroPageto    == 'no') f = f.where((a) => !a.pagato).toList();
    setState(() { _appointments = f; _loading = false; });
  }

  double get _totGuadagno => _appointments.fold(0, (s, a) => s + a.totale);
  double get _totPagato   => _appointments.where((a) => a.pagato).fold(0, (s, a) => s + a.totale);
  double get _totNonFatt  => _appointments.where((a) => !a.fatturato).fold(0, (s, a) => s + a.totale);
  double get _totOre      => _appointments.fold(0, (s, a) => s + a.oreTotali);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth    = Provider.of<AuthService>(context);
    final isAdmin = auth.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Cliente')),
      drawer: AppDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── FILTRI (scrollabile verticalmente, fisso in cima) ──
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // CLIENTE
                DropdownButtonFormField<Client>(
                  value: _selectedClient,
                  decoration: InputDecoration(
                    labelText: 'Cliente',
                    prefixIcon: const Icon(Icons.person, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: _clients.map((c) => DropdownMenuItem(value: c, child: Text(c.fullName))).toList(),
                  onChanged: (v) {
                    setState(() { _selectedClient = v; _appointments = []; _allFetched = []; });
                    _autoSearch();
                  },
                  hint: const Text('Seleziona cliente'),
                ),
                const SizedBox(height: 10),

                // PERIODO + MESE/ANNO
                Row(children: [
                  ...[
                    _periodoChip('mese',   'Mese',   primary),
                    const SizedBox(width: 6),
                    _periodoChip('anno',   'Anno',   primary),
                    const SizedBox(width: 6),
                    _periodoChip('sempre', 'Sempre', primary),
                    const SizedBox(width: 6),
                    _periodoChip('custom', 'Custom', primary),
                  ],
                  if (_periodoType == 'mese') ...[
                    const SizedBox(width: 12),
                    Expanded(child: DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      isDense: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthName(i + 1)))),
                      onChanged: (v) { setState(() => _selectedMonth = v!); _applyLocalFilters(); },
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, child: DropdownButtonFormField<int>(
                      value: _selectedYear,
                      isDense: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: List.generate(8, (i) => DropdownMenuItem(value: 2024 + i, child: Text('${2024 + i}'))),
                      onChanged: (v) { setState(() => _selectedYear = v!); _applyLocalFilters(); },
                    )),
                  ],
                  if (_periodoType == 'anno') ...[
                    const SizedBox(width: 12),
                    SizedBox(width: 100, child: DropdownButtonFormField<int>(
                      value: _selectedYear,
                      isDense: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: List.generate(8, (i) => DropdownMenuItem(value: 2024 + i, child: Text('${2024 + i}'))),
                      onChanged: (v) { setState(() => _selectedYear = v!); _applyLocalFilters(); },
                    )),
                  ],
                  if (_periodoType == 'custom') ...[
                    const SizedBox(width: 8),
                    Expanded(child: _datePicker('Dal', _customFrom, (d) { setState(() => _customFrom = d); _applyLocalFilters(); }, primary)),
                    const SizedBox(width: 8),
                    Expanded(child: _datePicker('Al',  _customTo,   (d) { setState(() => _customTo   = d); _applyLocalFilters(); }, primary)),
                  ],
                ]),
                const SizedBox(height: 8),

                // FATTURATO + PAGATO
                Row(children: [
                  Text('Fatt.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 6),
                  _statoSegmented(value: _filtroFatturato, onChange: (v) { setState(() => _filtroFatturato = v); _applyLocalFilters(); }, primary: primary),
                  const SizedBox(width: 16),
                  Text('Pag.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 6),
                  _statoSegmented(value: _filtroPageto, onChange: (v) { setState(() => _filtroPageto = v); _applyLocalFilters(); }, primary: primary),
                ]),
              ],
            ),
          ),

          // ── METRIC BAR COMPATTA ────────────────────────────────
          if (!_loading && _appointments.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniMetric('Ore', '${_totOre.toStringAsFixed(1)}h', primary),
                  _divider(),
                  _miniMetric('Totale', DateHelpers.formatCurrency(_totGuadagno), Colors.blueGrey),
                  _divider(),
                  _miniMetric('Incassato', DateHelpers.formatCurrency(_totPagato), Colors.green),
                  _divider(),
                  _miniMetric('Non fatt.', DateHelpers.formatCurrency(_totNonFatt), Colors.red),
                ],
              ),
            ),

          // ── HEADER TABELLA ─────────────────────────────────────
          if (!_loading && _appointments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_appointments.length} appuntamenti',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                          color: primary, letterSpacing: 0.4)),
                  Row(children: [
                    Icon(Icons.touch_app, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('Tocca Fatt./Pag. per aggiornare',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ]),
                ],
              ),
            ),

          // ── TABELLA ESPANSA ────────────────────────────────────
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          if (!_loading && _selectedClient == null)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text('Seleziona un cliente', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
              ],
            ))),

          if (!_loading && _selectedClient != null && _appointments.isEmpty && _allFetched.isNotEmpty)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_off, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 8),
                const Text('Nessun risultato con questi filtri',
                    style: TextStyle(color: Colors.grey)),
              ],
            ))),

          if (!_loading && _selectedClient != null && _allFetched.isEmpty)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('Nessun appuntamento per ${_selectedClient!.fullName}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ))),

          if (!_loading && _appointments.isNotEmpty)
            Expanded(
              child: _buildTable(primary, isAdmin),
            ),
        ],
      ),
    );
  }

  // ── TABELLA FULL WIDTH ─────────────────────────────────────────────────────
  Widget _buildTable(Color primary, bool isAdmin) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(primary.withOpacity(0.08)),
              dataRowColor: MaterialStateProperty.resolveWith((states) {
                // Righe zebrate
                return null;
              }),
              headingRowHeight: 40,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              columnSpacing: 20,
              horizontalMargin: 16,
              dividerThickness: 0.5,
              columns: const [
                DataColumn(label: Text('Data',    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                DataColumn(label: Text('Titolo',  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                DataColumn(label: Text('Persona', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                DataColumn(label: Text('Ore',     style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), numeric: true),
                DataColumn(label: Text('Tariffa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), numeric: true),
                DataColumn(label: Text('Totale',  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), numeric: true),
                DataColumn(label: Text('Fatt.',   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                DataColumn(label: Text('Pag.',    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              ],
              rows: _appointments.asMap().entries.map((entry) {
                final idx = entry.key;
                final apt = entry.value;
                final uid  = apt.userId;
                final nome = _userNames[uid] ?? (uid.length > 8 ? uid.substring(0, 8) : uid);
                final rowBg = idx.isOdd ? Colors.grey[50]! : Colors.white;

                return DataRow(
                  color: MaterialStateProperty.all(rowBg),
                  cells: [
                    DataCell(Text(DateHelpers.formatDateShort(apt.data),
                        style: const TextStyle(fontSize: 13))),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(apt.titolo, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    DataCell(
                      Row(children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: primary.withOpacity(0.15),
                          child: Text(
                            nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                            style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(nome, style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                    DataCell(Text(apt.oreTotali.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${apt.tariffa.toStringAsFixed(0)}€/h',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                    DataCell(Text(DateHelpers.formatCurrency(apt.totale),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),

                    // FATTURATO toggle
                    DataCell(
                      Tooltip(
                        message: isAdmin
                            ? (apt.fatturato ? 'Annulla fatturazione' : 'Segna fatturato')
                            : 'Solo admin',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: isAdmin ? () async {
                            await _db.collection('appointments').doc(apt.id)
                                .update({'fatturato': !apt.fatturato});
                            _autoSearch();
                          } : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: apt.fatturato ? Colors.orange.withOpacity(0.12) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: apt.fatturato ? Colors.orange : Colors.grey.shade300,
                                width: apt.fatturato ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              apt.fatturato ? '✓ Fatt.' : '○ Fatt.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: apt.fatturato ? Colors.orange[800] : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // PAGATO toggle
                    DataCell(
                      Tooltip(
                        message: apt.pagato ? 'Annulla pagamento' : 'Segna pagato',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            await _db.collection('appointments').doc(apt.id)
                                .update({'pagato': !apt.pagato});
                            _autoSearch();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: apt.pagato ? Colors.green.withOpacity(0.12) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: apt.pagato ? Colors.green : Colors.grey.shade300,
                                width: apt.pagato ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              apt.pagato ? '✓ Pag.' : '○ Pag.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: apt.pagato ? Colors.green[800] : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );
    });
  }

  // ── MINI METRIC ────────────────────────────────────────────────────────────
  Widget _miniMetric(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: Colors.grey[200]);

  // ── HELPERS ────────────────────────────────────────────────────────────────
  Widget _periodoChip(String value, String label, Color primary) {
    final active = _periodoType == value;
    return GestureDetector(
      onTap: () { setState(() => _periodoType = value); _applyLocalFilters(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : Colors.grey[700],
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        )),
      ),
    );
  }

  Widget _statoSegmented({required String value, required Function(String) onChange, required Color primary}) {
    return Row(children: [
      _segBtn('tutti', 'Tutti', value, onChange, primary),
      const SizedBox(width: 4),
      _segBtn('si', 'Si', value, onChange, primary),
      const SizedBox(width: 4),
      _segBtn('no', 'No', value, onChange, primary),
    ]);
  }

  Widget _segBtn(String val, String label, String current, Function(String) onChange, Color primary) {
    final active = current == val;
    return GestureDetector(
      onTap: () => onChange(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? primary : Colors.grey.shade300, width: active ? 1.5 : 1.0),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          color: active ? primary : Colors.grey[700],
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, Function(DateTime) onPick, Color primary) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2030),
        );
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value != null ? primary.withOpacity(0.05) : Colors.grey[50],
          border: Border.all(color: value != null ? primary.withOpacity(0.4) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 13, color: value != null ? primary : Colors.grey),
          const SizedBox(width: 6),
          Text(
            value != null
                ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                : label,
            style: TextStyle(fontSize: 12,
                color: value != null ? Colors.black87 : Colors.grey,
                fontWeight: value != null ? FontWeight.w600 : FontWeight.normal),
          ),
        ]),
      ),
    );
  }

  String _monthName(int m) {
    const months = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
                    'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
    return months[m - 1];
  }
}
