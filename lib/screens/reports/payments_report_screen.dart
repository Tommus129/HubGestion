import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../utils/date_helpers.dart';
import '../../widgets/app_drawer.dart';

class PaymentsReportScreen extends StatefulWidget {
  @override
  _PaymentsReportScreenState createState() => _PaymentsReportScreenState();
}

class _PaymentsReportScreenState extends State<PaymentsReportScreen> {
  final AppointmentService _aptService = AppointmentService();

  List<Appointment> _all = [];
  String _periodo = 'mese';
  String _filtroFatturato = 'tutti';
  String _filtroPagato = 'tutti';
  final DateTime _now = DateTime.now();

  // Ruolo utente — impostato nel build e usato nel load
  bool _canSeeAll = false;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    // Il caricamento avviene nel build al primo frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAppointments());
  }

  void _loadAppointments() {
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
        // ✅ Se non è admin → filtra solo i suoi
        _all = _canSeeAll
            ? apts
            : apts.where((a) => a.userId == _myUid).toList();
      });
    });
  }

  List<Appointment> get _filtered {
    return _all.where((a) {
      if (_filtroFatturato == 'si' && !a.fatturato) return false;
      if (_filtroFatturato == 'no' && a.fatturato) return false;
      if (_filtroPagato == 'si' && !a.pagato) return false;
      if (_filtroPagato == 'no' && a.pagato) return false;
      return true;
    }).toList();
  }

  double get _potenziale   => _all.fold(0.0, (s, a) => s + a.totale);
  double get _incassato    => _all.where((a) => a.pagato).fold(0.0, (s, a) => s + a.totale);
  double get _fatturatoNP  => _all.where((a) => a.fatturato && !a.pagato).fold(0.0, (s, a) => s + a.totale);
  double get _nonFatturato => _all.where((a) => !a.fatturato).fold(0.0, (s, a) => s + a.totale);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final me = auth.currentUser;

    // ✅ Aggiorna ruolo e ricarica se cambia
    final canSeeAll = me?.isAdmin ?? false;
    final myUid = me?.uid;
    if (canSeeAll != _canSeeAll || myUid != _myUid) {
      _canSeeAll = canSeeAll;
      _myUid = myUid;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAppointments());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Pagamenti'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [

          // ── FILTRI ────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // BANNER EMPLOYEE
                if (!canSeeAll)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 10),
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
                          'Visualizzi solo i tuoi pagamenti.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ),
                    ]),
                  ),

                // PERIODO
                Text('Periodo',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  children: ['mese', 'anno', 'sempre'].map((p) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(
                          p == 'mese' ? 'Mese'
                              : p == 'anno' ? 'Anno'
                              : 'Sempre',
                          style: TextStyle(fontSize: 12),
                        ),
                        selected: _periodo == p,
                        selectedColor: Colors.teal,
                        labelStyle: TextStyle(
                            color: _periodo == p
                                ? Colors.white
                                : Colors.black),
                        onSelected: (_) {
                          setState(() => _periodo = p);
                          _loadAppointments();
                        },
                      ),
                    ),
                  )).toList(),
                ),
                SizedBox(height: 8),

                // FILTRI FATTURATO / PAGATO
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fatturato',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: _filtroFatturato,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                  value: 'tutti', child: Text('Tutti')),
                              DropdownMenuItem(
                                  value: 'si',
                                  child: Text('Solo fatturati')),
                              DropdownMenuItem(
                                  value: 'no',
                                  child: Text('Non fatturati')),
                            ],
                            onChanged: (v) =>
                                setState(() => _filtroFatturato = v!),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pagato',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: _filtroPagato,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                  value: 'tutti', child: Text('Tutti')),
                              DropdownMenuItem(
                                  value: 'si',
                                  child: Text('Solo pagati')),
                              DropdownMenuItem(
                                  value: 'no',
                                  child: Text('Non pagati')),
                            ],
                            onChanged: (v) =>
                                setState(() => _filtroPagato = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── CARDS METRICHE ────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    _metricCard(
                      canSeeAll ? 'Potenziale' : 'I miei incassi',
                      DateHelpers.formatCurrency(_potenziale),
                      Colors.blue,
                      Icons.trending_up,
                    ),
                    SizedBox(width: 8),
                    _metricCard(
                      'Incassato',
                      DateHelpers.formatCurrency(_incassato),
                      Colors.green,
                      Icons.check_circle,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _metricCard(
                      'Fatt.\nnon pagato',
                      DateHelpers.formatCurrency(_fatturatoNP),
                      Colors.orange,
                      Icons.receipt,
                    ),
                    SizedBox(width: 8),
                    _metricCard(
                      'Non\nfatturato',
                      DateHelpers.formatCurrency(_nonFatturato),
                      Colors.red,
                      Icons.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── LISTA ─────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text(
                    'Nessun appuntamento trovato',
                    style: TextStyle(color: Colors.grey),
                  ))
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final apt = _filtered[i];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          title: Text(apt.titolo,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              DateHelpers.formatDate(apt.data)),
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
                                  Icon(Icons.receipt,
                                      color: apt.fatturato
                                          ? Colors.orange
                                          : Colors.grey[300],
                                      size: 14),
                                  SizedBox(width: 4),
                                  Icon(Icons.check_circle,
                                      color: apt.pagato
                                          ? Colors.green
                                          : Colors.grey[300],
                                      size: 14),
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

  Widget _metricCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 15)),
                  Text(label,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
