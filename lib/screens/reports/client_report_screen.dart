import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../models/appointment.dart';
import '../../services/client_service.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../utils/date_helpers.dart';
import '../../widgets/app_drawer.dart';

class ClientReportScreen extends StatefulWidget {
  @override
  _ClientReportScreenState createState() => _ClientReportScreenState();
}

class _ClientReportScreenState extends State<ClientReportScreen> {
  final ClientService _clientService = ClientService();
  final AppointmentService _aptService = AppointmentService();

  Client? _selectedClient;
  List<Client> _clients = [];
  List<Appointment> _appointments = [];
  String _periodo = 'mese';
  final DateTime _now = DateTime.now();

  // ✅ Filtri pagato / fatturato: null=tutti, true=sì, false=no
  bool? _filtroPagato;
  bool? _filtroFatturato;

  @override
  void initState() {
    super.initState();
    _clientService.getClients().listen((c) => setState(() => _clients = c));
  }

  void _loadAppointments() {
    if (_selectedClient == null) return;

    DateTime start;
    DateTime end;
    switch (_periodo) {
      case 'mese':
        start = DateTime(_now.year, _now.month, 1);
        end = DateTime(_now.year, _now.month + 1, 0);
        break;
      case 'anno':
        start = DateTime(_now.year, 1, 1);
        end = DateTime(_now.year, 12, 31);
        break;
      default:
        start = DateTime(2020);
        end = DateTime(2030);
    }

    _aptService.getAppointments(start, end).listen((apts) {
      setState(() {
        _appointments = apts
            .where((a) => a.clientId == _selectedClient!.id)
            .toList();
      });
    });
  }

  // Filtro ruolo (employee vede solo i suoi)
  List<Appointment> _byRole(String? myUid, bool isAdmin) {
    if (isAdmin || myUid == null) return _appointments;
    return _appointments.where((a) => a.userId == myUid).toList();
  }

  // ✅ Applica anche i filtri pagato/fatturato
  List<Appointment> _filtered(String? myUid, bool isAdmin) {
    var list = _byRole(myUid, isAdmin);
    if (_filtroPagato != null) {
      list = list.where((a) => a.pagato == _filtroPagato).toList();
    }
    if (_filtroFatturato != null) {
      list = list.where((a) => a.fatturato == _filtroFatturato).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final me = auth.currentUser;
    final isAdmin = me?.isAdmin ?? false;
    final myUid = me?.uid;

    final visApts = _filtered(myUid, isAdmin);

    final totaleOre      = visApts.fold(0.0, (s, a) => s + a.oreTotali);
    final totaleImporto  = visApts.fold(0.0, (s, a) => s + a.totale);
    final totalePagato   = visApts.where((a) => a.pagato).fold(0.0, (s, a) => s + a.totale);
    final totaleNonPagato = totaleImporto - totalePagato;

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Cliente'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [

          // ── FILTRI ────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // SELEZIONE CLIENTE
                DropdownButtonFormField<Client>(
                  value: _selectedClient,
                  decoration: InputDecoration(
                    labelText: 'Seleziona Cliente',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _clients.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.fullName),
                  )).toList(),
                  onChanged: (c) {
                    setState(() => _selectedClient = c);
                    _loadAppointments();
                  },
                  hint: Text('Scegli un cliente...'),
                ),
                SizedBox(height: 12),

                // PERIODO
                Row(
                  children: ['mese', 'anno', 'sempre'].map((p) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(
                          p == 'mese' ? 'Questo mese'
                              : p == 'anno' ? 'Quest\'anno'
                              : 'Sempre',
                        ),
                        selected: _periodo == p,
                        selectedColor: Colors.teal,
                        labelStyle: TextStyle(
                            color: _periodo == p ? Colors.white : Colors.black),
                        onSelected: (_) {
                          setState(() => _periodo = p);
                          _loadAppointments();
                        },
                      ),
                    ),
                  )).toList(),
                ),
                SizedBox(height: 12),

                // ✅ FILTRO PAGATO
                Text('Pagamento',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.4)),
                SizedBox(height: 6),
                Row(
                  children: [
                    _filtroChip(
                      label: 'Tutti',
                      selected: _filtroPagato == null,
                      color: Colors.grey,
                      onTap: () => setState(() => _filtroPagato = null),
                    ),
                    SizedBox(width: 8),
                    _filtroChip(
                      label: '✓ Pagato',
                      selected: _filtroPagato == true,
                      color: Colors.green,
                      onTap: () => setState(() =>
                          _filtroPagato = _filtroPagato == true ? null : true),
                    ),
                    SizedBox(width: 8),
                    _filtroChip(
                      label: '✗ Non pagato',
                      selected: _filtroPagato == false,
                      color: Colors.red,
                      onTap: () => setState(() =>
                          _filtroPagato = _filtroPagato == false ? null : false),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // ✅ FILTRO FATTURATO
                Text('Fatturazione',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.4)),
                SizedBox(height: 6),
                Row(
                  children: [
                    _filtroChip(
                      label: 'Tutti',
                      selected: _filtroFatturato == null,
                      color: Colors.grey,
                      onTap: () => setState(() => _filtroFatturato = null),
                    ),
                    SizedBox(width: 8),
                    _filtroChip(
                      label: '✓ Fatturato',
                      selected: _filtroFatturato == true,
                      color: Colors.orange,
                      onTap: () => setState(() =>
                          _filtroFatturato = _filtroFatturato == true ? null : true),
                    ),
                    SizedBox(width: 8),
                    _filtroChip(
                      label: '✗ Non fatturato',
                      selected: _filtroFatturato == false,
                      color: Colors.grey.shade600,
                      onTap: () => setState(() =>
                          _filtroFatturato = _filtroFatturato == false ? null : false),
                    ),
                  ],
                ),

                // Banner employee
                if (!isAdmin && _selectedClient != null)
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Visualizzi solo i tuoi appuntamenti con questo cliente.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),

          // ── CARDS RIASSUNTIVE ─────────────────────────────────
          if (_selectedClient != null && visApts.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _statCard('Ore', '${totaleOre.toStringAsFixed(1)}h', Colors.blue),
                  SizedBox(width: 6),
                  _statCard('Totale', DateHelpers.formatCurrency(totaleImporto), Colors.teal),
                  SizedBox(width: 6),
                  _statCard('Pagato', DateHelpers.formatCurrency(totalePagato), Colors.green),
                  SizedBox(width: 6),
                  _statCard('Da Pagare', DateHelpers.formatCurrency(totaleNonPagato), Colors.red),
                ],
              ),
            ),

          // ── LISTA APPUNTAMENTI ────────────────────────────────
          Expanded(
            child: _selectedClient == null
                ? Center(child: Text(
                    'Seleziona un cliente per vedere il report',
                    style: TextStyle(color: Colors.grey),
                  ))
                : visApts.isEmpty
                    ? Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list_off, color: Colors.grey, size: 40),
                          SizedBox(height: 8),
                          Text('Nessun appuntamento con questi filtri',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        itemCount: visApts.length,
                        itemBuilder: (context, i) {
                          final apt = visApts[i];
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(apt.titolo,
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${DateHelpers.formatDate(apt.data)} • '
                                '${apt.oraInizio}–${apt.oraFine} • '
                                '${apt.oreTotali.toStringAsFixed(1)}h',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    DateHelpers.formatCurrency(apt.totale),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal),
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Badge fatturato
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: apt.fatturato
                                              ? Colors.orange.withOpacity(0.15)
                                              : Colors.grey.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(
                                            color: apt.fatturato
                                                ? Colors.orange
                                                : Colors.grey.shade400,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          apt.fatturato ? 'Fatt.' : 'No fatt.',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: apt.fatturato
                                                ? Colors.orange.shade800
                                                : Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      // Badge pagato
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: apt.pagato
                                              ? Colors.green.withOpacity(0.15)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(
                                            color: apt.pagato
                                                ? Colors.green
                                                : Colors.red,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          apt.pagato ? 'Pagato' : 'Da pagare',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: apt.pagato
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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

  // ✅ Chip filtro riutilizzabile
  Widget _filtroChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? color : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
