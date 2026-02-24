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
        children: [

          // ── PANNELLO FILTRI ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Riga 1: cliente
                DropdownButtonFormField<Client>(
                  value: _selectedClient,
                  decoration: InputDecoration(
                    labelText: 'Cliente',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
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

                // Riga 2: periodo chips + selettori (wrappati)
// Riga 2a: chips periodo
Row(
  children: [
    _periodoChip('mese',   'Mese',   primary),
    const SizedBox(width: 6),
    _periodoChip('anno',   'Anno',   primary),
    const SizedBox(width: 6),
    _periodoChip('sempre', 'Sempre', primary),
    const SizedBox(width: 6),
    _periodoChip('custom', 'Custom', primary),
  ],
),
const SizedBox(height: 8),

// Riga 2b: selettori data — SEPARATI dai chip, nessun overflow
if (_periodoType == 'mese')
  Row(children: [
    Expanded(
      flex: 3,
      child: DropdownButtonFormField<int>(
        value: _selectedMonth,
        isDense: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        ),
        items: List.generate(12, (i) => DropdownMenuItem(
            value: i + 1, child: Text(_monthName(i + 1), overflow: TextOverflow.ellipsis))),
        onChanged: (v) { setState(() => _selectedMonth = v!); _applyLocalFilters(); },
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      flex: 2,
      child: DropdownButtonFormField<int>(
        value: _selectedYear,
        isDense: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        ),
        items: List.generate(8, (i) => DropdownMenuItem(
            value: 2024 + i, child: Text('${2024 + i}'))),
        onChanged: (v) { setState(() => _selectedYear = v!); _applyLocalFilters(); },
      ),
    ),
  ]),

if (_periodoType == 'anno')
  Row(children: [
    SizedBox(
      width: 120,
      child: DropdownButtonFormField<int>(
        value: _selectedYear,
        isDense: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        ),
        items: List.generate(8, (i) => DropdownMenuItem(
            value: 2024 + i, child: Text('${2024 + i}'))),
        onChanged: (v) { setState(() => _selectedYear = v!); _applyLocalFilters(); },
      ),
    ),
  ]),

if (_periodoType == 'custom')
  Row(children: [
    Expanded(child: _datePicker('Dal', _customFrom, (d) {
      setState(() => _customFrom = d); _applyLocalFilters();
    }, primary)),
    const SizedBox(width: 8),
    Expanded(child: _datePicker('Al', _customTo, (d) {
      setState(() => _customTo = d); _applyLocalFilters();
    }, primary)),
  ]),

const SizedBox(height: 8),


                // Riga 3: filtri stato
                Wrap(
                  spacing: 6, runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Fatturato:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    _segBtn('tutti', 'Tutti', _filtroFatturato, (v) { setState(() => _filtroFatturato = v); _applyLocalFilters(); }, primary),
                    _segBtn('si', 'Sì', _filtroFatturato, (v) { setState(() => _filtroFatturato = v); _applyLocalFilters(); }, primary),
                    _segBtn('no', 'No', _filtroFatturato, (v) { setState(() => _filtroFatturato = v); _applyLocalFilters(); }, primary),
                    const SizedBox(width: 8),
                    Text('Pagato:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    _segBtn('tutti', 'Tutti', _filtroPageto, (v) { setState(() => _filtroPageto = v); _applyLocalFilters(); }, primary),
                    _segBtn('si', 'Sì', _filtroPageto, (v) { setState(() => _filtroPageto = v); _applyLocalFilters(); }, primary),
                    _segBtn('no', 'No', _filtroPageto, (v) { setState(() => _filtroPageto = v); _applyLocalFilters(); }, primary),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // ── METRIC CARDS 4 box colorati ──────────────────────────
          if (!_loading && _appointments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _metricBox('Ore totali', '${_totOre.toStringAsFixed(1)}h',
                      Icons.schedule, primary, _totPagato, _totGuadagno),
                  const SizedBox(width: 8),
                  _metricBox('Totale', DateHelpers.formatCurrency(_totGuadagno),
                      Icons.euro_rounded, Colors.blueGrey, _totGuadagno, _totGuadagno),
                  const SizedBox(width: 8),
                  _metricBox('Incassato', DateHelpers.formatCurrency(_totPagato),
                      Icons.check_circle_outline, Colors.green, _totPagato, _totGuadagno),
                  const SizedBox(width: 8),
                  _metricBox('Non fatt.', DateHelpers.formatCurrency(_totNonFatt),
                      Icons.receipt_long_outlined, Colors.deepOrange, _totNonFatt, _totGuadagno),
                ],
              ),
            ),

          // ── HEADER TABELLA ─────────────────────────────────────────
          if (!_loading && _appointments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(text: '${_appointments.length}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
                      TextSpan(text: '  appuntamenti',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                    ],
                  )),
                  Row(children: [
                    Icon(Icons.touch_app, size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('Tocca Fatt./Pag. per aggiornare',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ]),
                ],
              ),
            ),

          // ── STATI VUOTI ────────────────────────────────────────────
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          if (!_loading && _selectedClient == null)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 64, color: Colors.grey[200]),
                const SizedBox(height: 12),
                Text('Seleziona un cliente', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                const SizedBox(height: 4),
                Text('per visualizzare il report', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
              ],
            ))),

          if (!_loading && _selectedClient != null && _allFetched.isEmpty)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 56, color: Colors.grey[200]),
                const SizedBox(height: 10),
                Text('Nessun appuntamento trovato', style: TextStyle(color: Colors.grey[400])),
              ],
            ))),

          if (!_loading && _selectedClient != null && _appointments.isEmpty && _allFetched.isNotEmpty)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_off, size: 56, color: Colors.grey[200]),
                const SizedBox(height: 10),
                Text('Nessun risultato con questi filtri', style: TextStyle(color: Colors.grey[400])),
              ],
            ))),

          // ── TABELLA FULL ───────────────────────────────────────────
          if (!_loading && _appointments.isNotEmpty)
            Expanded(child: _buildTable(primary, isAdmin)),
        ],
      ),
    );
  }

  // ── METRIC BOX con progress bar ────────────────────────────────────────────
  Widget _metricBox(String label, String value, IconData icon, Color color, double amount, double total) {
    final pct = (total > 0 && amount >= 0) ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500))),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TABELLA ────────────────────────────────────────────────────────────────
  Widget _buildTable(Color primary, bool isAdmin) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(primary.withOpacity(0.06)),
              headingRowHeight: 38,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 54,
              columnSpacing: 24,
              horizontalMargin: 16,
              dividerThickness: 0.5,
              columns: const [
                DataColumn(label: Text('Data',    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Titolo',  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Persona', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Ore',     style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                DataColumn(label: Text('Tariffa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                DataColumn(label: Text('Totale',  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                DataColumn(label: Text('Fatt.',   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Pag.',    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ],
              rows: _appointments.asMap().entries.map((entry) {
                final idx = entry.key;
                final apt = entry.value;
                final uid  = apt.userId;
                final nome = _userNames[uid] ?? (uid.length > 8 ? uid.substring(0, 8) : uid);
                final rowBg = idx.isOdd ? const Color(0xFFF9FAFB) : Colors.white;

                return DataRow(
                  color: MaterialStateProperty.all(rowBg),
                  cells: [

                    // Data
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateHelpers.formatDateShort(apt.data),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${apt.oraInizio}–${apt.oraFine}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                      ],
                    )),

                    // Titolo
                    DataCell(SizedBox(
                      width: 160,
                      child: Text(apt.titolo, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    )),

                    // Persona
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: primary.withOpacity(0.12),
                          child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                              style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(nome, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    )),

                    // Ore
                    DataCell(Text(apt.oreTotali.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13))),

                    // Tariffa
                    DataCell(Text('${apt.tariffa.toStringAsFixed(0)}€/h',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]))),

                    // Totale
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(DateHelpers.formatCurrency(apt.totale),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    )),

                    // Fatturato
                    DataCell(Tooltip(
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: apt.fatturato ? Colors.orange.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: apt.fatturato ? Colors.orange : Colors.grey.shade300,
                              width: apt.fatturato ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              apt.fatturato ? Icons.check : Icons.circle_outlined,
                              size: 12,
                              color: apt.fatturato ? Colors.orange[700] : Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(apt.fatturato ? 'Sì' : 'No',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: apt.fatturato ? Colors.orange[700] : Colors.grey[400],
                                )),
                          ]),
                        ),
                      ),
                    )),

                    // Pagato
                    DataCell(Tooltip(
                      message: apt.pagato ? 'Annulla pagamento' : 'Segna pagato',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          await _db.collection('appointments').doc(apt.id)
                              .update({'pagato': !apt.pagato});
                          _autoSearch();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: apt.pagato ? Colors.green.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: apt.pagato ? Colors.green : Colors.grey.shade300,
                              width: apt.pagato ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              apt.pagato ? Icons.check : Icons.circle_outlined,
                              size: 12,
                              color: apt.pagato ? Colors.green[700] : Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(apt.pagato ? 'Sì' : 'No',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: apt.pagato ? Colors.green[700] : Colors.grey[400],
                                )),
                          ]),
                        ),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );
    });
  }

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
          fontSize: 12, color: active ? primary : Colors.grey[600],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: value != null ? primary.withOpacity(0.05) : Colors.grey[50],
          border: Border.all(color: value != null ? primary.withOpacity(0.4) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today, size: 13, color: value != null ? primary : Colors.grey),
          const SizedBox(width: 5),
          Text(
            value != null
                ? '${value.day.toString().padLeft(2,'0')}/${value.month.toString().padLeft(2,'0')}/${value.year}'
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
