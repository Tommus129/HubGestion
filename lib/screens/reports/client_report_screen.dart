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

      debugPrint('>>> Trovati ${snap.docs.length} doc per ${_selectedClient!.fullName}');

      final all = snap.docs.map((d) {
        try { return Appointment.fromFirestore(d); }
        catch (e) { debugPrint('>>> Parse error ${d.id}: $e'); return null; }
      }).whereType<Appointment>()
          .toList()..sort((a, b) => a.data.compareTo(b.data));

      setState(() { _allFetched = all; });
      _applyLocalFilters();

    } catch (e) {
      debugPrint('>>> ERRORE: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red,
              duration: const Duration(seconds: 5)),
        );
      }
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
        start = DateTime(2000);
        end   = DateTime(2099);
    }

    List<Appointment> filtered = _allFetched.where((a) {
      // ✅ Escludi soft-deleted
      if (a.deleted == true) return false;
      // Filtro periodo
      if (a.data.isBefore(start) || a.data.isAfter(end)) return false;
      return true;
    }).toList();

    if (_filtroFatturato == 'si') filtered = filtered.where((a) => a.fatturato).toList();
    if (_filtroFatturato == 'no') filtered = filtered.where((a) => !a.fatturato).toList();
    if (_filtroPageto    == 'si') filtered = filtered.where((a) => a.pagato).toList();
    if (_filtroPageto    == 'no') filtered = filtered.where((a) => !a.pagato).toList();

    debugPrint('>>> Filtrati: ${filtered.length}');
    setState(() { _appointments = filtered; _loading = false; });
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            DropdownButtonFormField<Client>(
              value: _selectedClient,
              decoration: InputDecoration(
                labelText: 'Cliente *',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _clients.map((c) => DropdownMenuItem(
                value: c, child: Text(c.fullName),
              )).toList(),
              onChanged: (v) {
                setState(() { _selectedClient = v; _appointments = []; _allFetched = []; });
                _autoSearch();
              },
              hint: const Text('Seleziona cliente per vedere il report'),
            ),
            const SizedBox(height: 16),

            _sectionLabel('Periodo', primary),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _periodoChip('mese',   'Mese',           primary),
                _periodoChip('anno',   'Anno',            primary),
                _periodoChip('sempre', 'Sempre',          primary),
                _periodoChip('custom', 'Personalizzato',  primary),
              ],
            ),
            const SizedBox(height: 12),

            if (_periodoType == 'mese' || _periodoType == 'anno') ...[
              Row(children: [
                if (_periodoType == 'mese') ...[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      decoration: InputDecoration(
                        labelText: 'Mese',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1, child: Text(_monthName(i + 1)),
                      )),
                      onChanged: (v) { setState(() => _selectedMonth = v!); _applyLocalFilters(); },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: InputDecoration(
                      labelText: 'Anno',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: List.generate(8, (i) => DropdownMenuItem(
                      value: 2024 + i, child: Text('${2024 + i}'),
                    )),
                    onChanged: (v) { setState(() => _selectedYear = v!); _applyLocalFilters(); },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ],

            if (_periodoType == 'custom') ...[
              Row(children: [
                Expanded(child: _datePicker('Dal', _customFrom, (d) {
                  setState(() => _customFrom = d); _applyLocalFilters();
                }, primary)),
                const SizedBox(width: 12),
                Expanded(child: _datePicker('Al', _customTo, (d) {
                  setState(() => _customTo = d); _applyLocalFilters();
                }, primary)),
              ]),
              const SizedBox(height: 12),
            ],

            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Fatturato', primary),
                  const SizedBox(height: 6),
                  _statoSegmented(
                    value: _filtroFatturato,
                    onChange: (v) { setState(() => _filtroFatturato = v); _applyLocalFilters(); },
                    primary: primary,
                  ),
                ],
              )),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Pagato', primary),
                  const SizedBox(height: 6),
                  _statoSegmented(
                    value: _filtroPageto,
                    onChange: (v) { setState(() => _filtroPageto = v); _applyLocalFilters(); },
                    primary: primary,
                  ),
                ],
              )),
            ]),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (!_loading && _selectedClient == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Column(children: [
                  Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Seleziona un cliente per vedere il report',
                      style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                ])),
              ),

            if (!_loading && _selectedClient != null && _appointments.isEmpty && _allFetched.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Column(children: [
                  Icon(Icons.filter_alt_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  const Text('Nessun appuntamento con questi filtri',
                      style: TextStyle(color: Colors.grey)),
                ])),
              ),

            if (!_loading && _selectedClient != null && _allFetched.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Column(children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('Nessun appuntamento per ${_selectedClient!.fullName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                ])),
              ),

            if (!_loading && _appointments.isNotEmpty) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  _metricCard('Ore totali',    '${_totOre.toStringAsFixed(1)}h',        Icons.access_time,  primary),
                  _metricCard('Totale',        DateHelpers.formatCurrency(_totGuadagno), Icons.euro,         Colors.blueGrey),
                  _metricCard('Incassato',     DateHelpers.formatCurrency(_totPagato),   Icons.check_circle, Colors.green),
                  _metricCard('Non fatturato', DateHelpers.formatCurrency(_totNonFatt),  Icons.receipt_long, Colors.red),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel('Appuntamenti (${_appointments.length})', primary),
                  // ✅ Legenda toggle
                  Row(children: [
                    Icon(Icons.touch_app, size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text('Tocca Fatt./Pag. per aggiornare',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ]),
                ],
              ),
              const SizedBox(height: 10),
              _buildTable(primary, isAdmin),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTable(Color primary, bool isAdmin) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(primary.withOpacity(0.07)),
        dataRowMinHeight: 40,
        dataRowMaxHeight: 52,
        columnSpacing: 16,
        columns: const [
          DataColumn(label: Text('Data',    style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Titolo',  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Persona', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Ore',     style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Tariffa', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Totale',  style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Fatt.',   style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pag.',    style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _appointments.map((apt) {
          final uid  = apt.userId;
          final nome = _userNames[uid] ?? (uid.length > 8 ? uid.substring(0, 8) : uid);
          return DataRow(cells: [
            DataCell(Text(DateHelpers.formatDateShort(apt.data),
                style: const TextStyle(fontSize: 12))),
            DataCell(ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(apt.titolo, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            )),
            DataCell(Text(nome, style: const TextStyle(fontSize: 12))),
            DataCell(Text(apt.oreTotali.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12))),
            DataCell(Text('${apt.tariffa.toStringAsFixed(0)} EUR',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(DateHelpers.formatCurrency(apt.totale),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),

            // ✅ Toggle FATTURATO (solo admin)
            DataCell(
              Tooltip(
                message: isAdmin
                    ? (apt.fatturato ? 'Segna come non fatturato' : 'Segna come fatturato')
                    : '',
                child: GestureDetector(
                  onTap: isAdmin ? () async {
                    await _db.collection('appointments')
                        .doc(apt.id)
                        .update({'fatturato': !apt.fatturato});
                    await _autoSearch();
                  } : null,
                  child: Icon(
                    apt.fatturato ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: apt.fatturato ? Colors.orange : Colors.grey[300],
                    size: 22,
                  ),
                ),
              ),
            ),

            // ✅ Toggle PAGATO (tutti)
            DataCell(
              Tooltip(
                message: apt.pagato ? 'Segna come non pagato' : 'Segna come pagato',
                child: GestureDetector(
                  onTap: () async {
                    await _db.collection('appointments')
                        .doc(apt.id)
                        .update({'pagato': !apt.pagato});
                    await _autoSearch();
                  },
                  child: Icon(
                    apt.pagato ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: apt.pagato ? Colors.green : Colors.grey[300],
                    size: 22,
                  ),
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _statoSegmented({required String value, required Function(String) onChange, required Color primary}) {
    return Row(children: [
      _segBtn('tutti', 'Tutti', value, onChange, primary),
      const SizedBox(width: 6),
      _segBtn('si', 'Si', value, onChange, primary),
      const SizedBox(width: 6),
      _segBtn('no', 'No', value, onChange, primary),
    ]);
  }

  Widget _segBtn(String val, String label, String current, Function(String) onChange, Color primary) {
    final active = current == val;
    return GestureDetector(
      onTap: () => onChange(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _periodoChip(String value, String label, Color primary) {
    final active = _periodoType == value;
    return GestureDetector(
      onTap: () { setState(() => _periodoType = value); _applyLocalFilters(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : Colors.grey[700],
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
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
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: value != null ? primary.withOpacity(0.05) : Colors.grey[50],
          border: Border.all(color: value != null ? primary.withOpacity(0.4) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 15, color: value != null ? primary : Colors.grey),
          const SizedBox(width: 8),
          Text(
            value != null
                ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                : label,
            style: TextStyle(
              fontSize: 13,
              color: value != null ? Colors.black87 : Colors.grey,
              fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        )),
      ]),
    );
  }

  Widget _sectionLabel(String text, Color color) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5));

  String _monthName(int m) {
    const months = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
                    'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
    return months[m - 1];
  }
}
