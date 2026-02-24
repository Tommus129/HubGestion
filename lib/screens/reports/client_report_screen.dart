import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/appointment.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../utils/date_helpers.dart';

class ClientReportScreen extends StatefulWidget {
  @override
  _ClientReportScreenState createState() => _ClientReportScreenState();
}

class _ClientReportScreenState extends State<ClientReportScreen> {
  final ClientService _clientService = ClientService();
  final AppointmentService _aptService = AppointmentService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── FILTRI ─────────────────────────────────────────────────────────────────
  Client? _selectedClient;
  String _periodoType = 'mese'; // mese | anno | sempre | custom
  int _selectedMonth = DateTime.now().month;
  int _selectedYear  = DateTime.now().year;
  DateTime? _customFrom;
  DateTime? _customTo;
  String _filtroFatturato = 'tutti';  // tutti | si | no
  String _filtroPageto    = 'tutti';  // tutti | si | no

  // ── DATI ───────────────────────────────────────────────────────────────────
  List<Client> _clients = [];
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

  Future<void> _search() async {
    if (_selectedClient == null) return;
    setState(() => _loading = true);

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
        if (_customFrom == null || _customTo == null) {
          setState(() => _loading = false);
          return;
        }
        start = _customFrom!;
        end   = DateTime(_customTo!.year, _customTo!.month, _customTo!.day, 23, 59, 59);
        break;
      default: // sempre
        start = DateTime(2020);
        end   = DateTime(2099);
    }

    final snap = await _db
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('clientId', isEqualTo: _selectedClient!.id)
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('data', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('data')
        .get();

    List<Appointment> apts =
        snap.docs.map((d) => Appointment.fromFirestore(d)).toList();

    // Filtri fatturato / pagato
    if (_filtroFatturato == 'si')  apts = apts.where((a) => a.fatturato).toList();
    if (_filtroFatturato == 'no')  apts = apts.where((a) => !a.fatturato).toList();
    if (_filtroPageto    == 'si')  apts = apts.where((a) => a.pagato).toList();
    if (_filtroPageto    == 'no')  apts = apts.where((a) => !a.pagato).toList();

    setState(() { _appointments = apts; _loading = false; });
  }

  // ── AGGREGATI ──────────────────────────────────────────────────────────────
  double get _totGuadagno  => _appointments.fold(0, (s, a) => s + a.totale);
  double get _totPagato    => _appointments.where((a) => a.pagato).fold(0, (s, a) => s + a.totale);
  double get _totFatturato => _appointments.where((a) => a.fatturato && !a.pagato).fold(0, (s, a) => s + a.totale);
  double get _totNonFatt   => _appointments.where((a) => !a.fatturato).fold(0, (s, a) => s + a.totale);
  double get _totOre       => _appointments.fold(0, (s, a) => s + a.oreTotali);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth    = Provider.of<AuthService>(context);
    final isAdmin = auth.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('Report Cliente')),
      drawer: AppDrawer(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── SELEZIONE CLIENTE ─────────────────────────────────
            DropdownButtonFormField<Client>(
              value: _selectedClient,
              decoration: InputDecoration(
                labelText: 'Cliente *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _clients.map((c) => DropdownMenuItem(
                value: c, child: Text(c.fullName),
              )).toList(),
              onChanged: (v) => setState(() {
                _selectedClient = v;
                _appointments = [];
              }),
              hint: Text('Seleziona cliente'),
            ),
            SizedBox(height: 16),

            // ── PERIODO ───────────────────────────────────────────
            _sectionLabel('Periodo', primary),
            SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _periodoChip('mese',   'Mese',        primary),
                _periodoChip('anno',   'Anno',         primary),
                _periodoChip('sempre', 'Sempre',       primary),
                _periodoChip('custom', 'Personalizzato', primary),
              ],
            ),
            SizedBox(height: 12),

            // Selettore mese/anno
            if (_periodoType == 'mese' || _periodoType == 'anno') ...[
              Row(children: [
                if (_periodoType == 'mese') ...[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      decoration: InputDecoration(
                        labelText: 'Mese',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthName(i + 1)),
                      )),
                      onChanged: (v) => setState(() => _selectedMonth = v!),
                    ),
                  ),
                  SizedBox(width: 12),
                ],
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: InputDecoration(
                      labelText: 'Anno',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: List.generate(8, (i) => DropdownMenuItem(
                      value: 2024 + i,
                      child: Text('${2024 + i}'),
                    )),
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                ),
              ]),
              SizedBox(height: 12),
            ],

            // Date picker custom
            if (_periodoType == 'custom') ...[
              Row(children: [
                Expanded(child: _datePicker('Dal', _customFrom, (d) => setState(() => _customFrom = d), primary)),
                SizedBox(width: 12),
                Expanded(child: _datePicker('Al',  _customTo,   (d) => setState(() => _customTo   = d), primary)),
              ]),
              SizedBox(height: 12),
            ],

            // ── FILTRI STATO ──────────────────────────────────────
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Fatturato', primary),
                  SizedBox(height: 6),
                  _statoSegmented(
                    value: _filtroFatturato,
                    onChange: (v) => setState(() => _filtroFatturato = v),
                    primary: primary,
                  ),
                ],
              )),
              SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Pagato', primary),
                  SizedBox(height: 6),
                  _statoSegmented(
                    value: _filtroPageto,
                    onChange: (v) => setState(() => _filtroPageto = v),
                    primary: primary,
                  ),
                ],
              )),
            ]),
            SizedBox(height: 20),

            // ── BOTTONE CERCA ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _selectedClient == null || _loading ? null : _search,
                icon: _loading
                    ? SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.search),
                label: Text('Cerca', style: TextStyle(fontSize: 15)),
              ),
            ),

            // ── RISULTATI ─────────────────────────────────────────
            if (_appointments.isNotEmpty) ...[
              SizedBox(height: 24),

              // CARDS METRICHE
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  _metricCard('Ore totali',    '${_totOre.toStringAsFixed(1)}h', Icons.access_time, primary),
                  _metricCard('Totale',        DateHelpers.formatCurrency(_totGuadagno), Icons.euro, Colors.blueGrey),
                  _metricCard('Incassato',     DateHelpers.formatCurrency(_totPagato),   Icons.check_circle, Colors.green),
                  _metricCard('Non fatturato', DateHelpers.formatCurrency(_totNonFatt),  Icons.receipt_long, Colors.red),
                ],
              ),
              SizedBox(height: 20),

              // TABELLA APPUNTAMENTI
              _sectionLabel('Dettaglio appuntamenti (${_appointments.length})', primary),
              SizedBox(height: 10),
              _buildTable(primary, isAdmin),
            ],

            if (_appointments.isEmpty && !_loading && _selectedClient != null)
              Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                    SizedBox(height: 8),
                    Text('Nessun appuntamento trovato',
                        style: TextStyle(color: Colors.grey)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── TABELLA ────────────────────────────────────────────────────────────────
  Widget _buildTable(Color primary, bool isAdmin) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(primary.withOpacity(0.07)),
        dataRowMinHeight: 40,
        dataRowMaxHeight: 52,
        columnSpacing: 16,
        columns: [
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
          final nome = _userNames[apt.userId] ?? apt.userId.substring(0, 8);
          return DataRow(cells: [
            DataCell(Text(DateHelpers.formatDateShort(apt.data),
                style: TextStyle(fontSize: 12))),
            DataCell(ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 140),
              child: Text(apt.titolo,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            )),
            // ✅ Colonna Persona
            DataCell(Text(nome, style: TextStyle(fontSize: 12))),
            DataCell(Text(apt.oreTotali.toStringAsFixed(1),
                style: TextStyle(fontSize: 12))),
            DataCell(Text('€${apt.tariffa.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12))),
            DataCell(Text(DateHelpers.formatCurrency(apt.totale),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataCell(_statusDot(apt.fatturato, Colors.orange)),
            DataCell(_statusDot(apt.pagato, Colors.green)),
          ]);
        }).toList(),
        // ── RIGA TOTALI ────────────────────────────────────────
        ...[],
      ),
    );
  }

  Widget _statusDot(bool active, Color color) {
    return Icon(
      active ? Icons.check_circle : Icons.radio_button_unchecked,
      color: active ? color : Colors.grey[300],
      size: 18,
    );
  }

  // ── WIDGET HELPERS ─────────────────────────────────────────────────────────
  Widget _periodoChip(String value, String label, Color primary) {
    final active = _periodoType == value;
    return GestureDetector(
      onTap: () => setState(() { _periodoType = value; _appointments = []; }),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? primary : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey[700],
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
      ),
    );
  }

  Widget _statoSegmented({
    required String value,
    required Function(String) onChange,
    required Color primary,
  }) {
    return Row(children: [
      _segBtn('tutti', 'Tutti', value, onChange, primary),
      SizedBox(width: 6),
      _segBtn('si', 'Sì', value, onChange, primary),
      SizedBox(width: 6),
      _segBtn('no', 'No', value, onChange, primary),
    ]);
  }

  Widget _segBtn(String val, String label, String current,
      Function(String) onChange, Color primary) {
    final active = current == val;
    return GestureDetector(
      onTap: () => onChange(val),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? primary : Colors.grey.shade300,
              width: active ? 1.5 : 1.0),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              color: active ? primary : Colors.grey[700],
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value,
      Function(DateTime) onPick, Color primary) {
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: value != null ? primary.withOpacity(0.05) : Colors.grey[50],
          border: Border.all(
              color: value != null ? primary.withOpacity(0.4) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
              size: 15, color: value != null ? primary : Colors.grey),
          SizedBox(width: 8),
          Text(
            value != null
                ? '${value.day.toString().padLeft(2, '0')}/'
                  '${value.month.toString().padLeft(2, '0')}/'
                  '${value.year}'
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        )),
      ]),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5));
  }

  String _monthName(int m) {
    const months = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
                    'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
    return months[m - 1];
  }
}
