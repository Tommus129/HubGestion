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
  List<Appointment> _appointments = []; // tutti gli appuntamenti del cliente
  String _periodo = 'mese';
  final DateTime _now = DateTime.now();

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

  // ✅ Filtra per userId se employee — restituisce solo i suoi appuntamenti
  List<Appointment> _visibleApts(String? myUid, bool isAdmin) {
    if (isAdmin || myUid == null) return _appointments;
    return _appointments.where((a) => a.userId == myUid).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final me = auth.currentUser;
    final isAdmin = me?.isAdmin ?? false;
    final myUid = me?.uid;

    // ✅ Lista effettivamente visibile in base al ruolo
    final visApts = _visibleApts(myUid, isAdmin);

    // ✅ Stat calcolate solo sugli appuntamenti visibili
    final totaleOre     = visApts.fold(0.0, (s, a) => s + a.oreTotali);
    final totaleImporto = visApts.fold(0.0, (s, a) => s + a.totale);
    final totalePagato  = visApts.where((a) => a.pagato).fold(0.0, (s, a) => s + a.totale);
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

                // ✅ Banner informativo per employee
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

          // ── CARDS RIASSUNTIVE (solo se ci sono appuntamenti visibili) ──
          if (_selectedClient != null && visApts.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _statCard('Ore Totali', '${totaleOre.toStringAsFixed(1)}h', Colors.blue),
                  SizedBox(width: 8),
                  _statCard('Totale', DateHelpers.formatCurrency(totaleImporto), Colors.teal),
                  SizedBox(width: 8),
                  _statCard('Pagato', DateHelpers.formatCurrency(totalePagato), Colors.green),
                  SizedBox(width: 8),
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
                    ? Center(child: Text(
                        'Nessun appuntamento nel periodo selezionato',
                        style: TextStyle(color: Colors.grey),
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (apt.fatturato)
                                        Icon(Icons.receipt,
                                            color: Colors.orange, size: 14),
                                      if (apt.pagato)
                                        Icon(Icons.check_circle,
                                            color: Colors.green, size: 14),
                                      if (!apt.pagato)
                                        Icon(Icons.cancel,
                                            color: Colors.red, size: 14),
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

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
