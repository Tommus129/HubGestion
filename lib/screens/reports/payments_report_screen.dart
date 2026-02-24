import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Appointment> _all = [];
  String _periodo = 'mese';
  String _filtroFatturato = 'tutti';
  String _filtroPagato = 'tutti';
  final DateTime _now = DateTime.now();
  bool _canSeeAll = false;
  String? _myUid;

  Map<String, String> _userNames   = {};
  Map<String, String> _clientNames = {};

  @override
  void initState() {
    super.initState();
    _loadNames();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAppointments());
  }

  Future<void> _loadNames() async {
    final users   = await _db.collection('users').get();
    final clients = await _db.collection('clients').get();
    setState(() {
      _userNames = {
        for (final d in users.docs)
          d.id: (d.data()['displayName']?.toString().isNotEmpty == true
              ? d.data()['displayName']
              : d.data()['email']) ?? d.id
      };
      _clientNames = {
        for (final d in clients.docs)
          d.id: '${d.data()['nome'] ?? ''} ${d.data()['cognome'] ?? ''}'.trim()
      };
    });
  }

  void _loadAppointments() {
    DateTime start, end;
    switch (_periodo) {
      case 'mese':
        start = DateTime(_now.year, _now.month, 1);
        end   = DateTime(_now.year, _now.month + 1, 0);
        break;
      case 'anno':
        start = DateTime(_now.year, 1, 1);
        end   = DateTime(_now.year, 12, 31);
        break;
      default:
        start = DateTime(2020);
        end   = DateTime(2030);
    }
    _aptService.getAppointments(start, end).listen((apts) {
      setState(() {
        _all = _canSeeAll ? apts : apts.where((a) => a.userId == _myUid).toList();
      });
    });
  }

  List<Appointment> get _filtered => _all.where((a) {
    if (_filtroFatturato == 'si' && !a.fatturato) return false;
    if (_filtroFatturato == 'no' && a.fatturato)  return false;
    if (_filtroPagato    == 'si' && !a.pagato)    return false;
    if (_filtroPagato    == 'no' && a.pagato)     return false;
    return true;
  }).toList();

  Future<void> _toggleFatturato(Appointment apt) async =>
      _db.collection('appointments').doc(apt.id).update({'fatturato': !apt.fatturato});

  Future<void> _togglePagato(Appointment apt) async =>
      _db.collection('appointments').doc(apt.id).update({'pagato': !apt.pagato});

  double get _potenziale   => _all.fold(0.0, (s, a) => s + a.totale);
  double get _incassato    => _all.where((a) => a.pagato).fold(0.0, (s, a) => s + a.totale);
  double get _fatturatoNP  => _all.where((a) => a.fatturato && !a.pagato).fold(0.0, (s, a) => s + a.totale);
  double get _nonFatturato => _all.where((a) => !a.fatturato).fold(0.0, (s, a) => s + a.totale);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth    = Provider.of<AuthService>(context);
    final me      = auth.currentUser;
    final canSeeAll = me?.isAdmin ?? false;
    final myUid     = me?.uid;
    if (canSeeAll != _canSeeAll || myUid != _myUid) {
      _canSeeAll = canSeeAll;
      _myUid     = myUid;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAppointments());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Report Pagamenti')),
      drawer: AppDrawer(),
      body: Column(
        children: [

          // ── FILTRI ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!canSeeAll)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Visualizzi solo i tuoi pagamenti.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700))),
                    ]),
                  ),

                Row(children: ['mese', 'anno', 'sempre'].map((p) {
                  final active = _periodo == p;
                  final label  = p == 'mese' ? 'Mese' : p == 'anno' ? 'Anno' : 'Sempre';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () { setState(() => _periodo = p); _loadAppointments(); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? primary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: active ? primary : Colors.grey.shade300),
                          ),
                          child: Center(child: Text(label, style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            color: active ? Colors.white : Colors.grey[700],
                          ))),
                        ),
                      ),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 6, runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Fatturato:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    _segBtn('tutti', 'Tutti', _filtroFatturato, (v) => setState(() => _filtroFatturato = v), primary),
                    _segBtn('si',    'Sì',    _filtroFatturato, (v) => setState(() => _filtroFatturato = v), primary),
                    _segBtn('no',    'No',    _filtroFatturato, (v) => setState(() => _filtroFatturato = v), primary),
                    const SizedBox(width: 8),
                    Text('Pagato:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    _segBtn('tutti', 'Tutti', _filtroPagato, (v) => setState(() => _filtroPagato = v), primary),
                    _segBtn('si',    'Sì',    _filtroPagato, (v) => setState(() => _filtroPagato = v), primary),
                    _segBtn('no',    'No',    _filtroPagato, (v) => setState(() => _filtroPagato = v), primary),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // ── METRIC BOX ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              _metricBox(canSeeAll ? 'Potenziale' : 'I miei incassi',
                  DateHelpers.formatCurrency(_potenziale), primary, Icons.trending_up, _potenziale, _potenziale),
              const SizedBox(width: 8),
              _metricBox('Incassato',
                  DateHelpers.formatCurrency(_incassato), Colors.green, Icons.check_circle_outline, _incassato, _potenziale),
              const SizedBox(width: 8),
              _metricBox('Fatt. non pag.',
                  DateHelpers.formatCurrency(_fatturatoNP), Colors.orange, Icons.receipt_outlined, _fatturatoNP, _potenziale),
              const SizedBox(width: 8),
              _metricBox('Non fatturato',
                  DateHelpers.formatCurrency(_nonFatturato), Colors.red, Icons.warning_amber_outlined, _nonFatturato, _potenziale),
            ]),
          ),

          // ── HEADER ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(text: '${_filtered.length}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary)),
                    TextSpan(text: '  appuntamenti',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                )),
                Row(children: [
                  Icon(Icons.touch_app, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 3),
                  Text('Tocca Fatt./Pag. per aggiornare',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ]),
              ],
            ),
          ),

          // ── LISTA ───────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 56, color: Colors.grey[200]),
                      const SizedBox(height: 10),
                      Text('Nessun appuntamento trovato',
                          style: TextStyle(color: Colors.grey[400])),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _aptCard(_filtered[i], primary, canSeeAll),
                  ),
          ),
        ],
      ),
    );
  }

  // ── CARD ────────────────────────────────────────────────────────────────────
  Widget _aptCard(Appointment apt, Color primary, bool isAdmin) {
    final personaNome = _userNames[apt.userId]   ?? apt.userId;
    final clienteNome = _clientNames[apt.clientId] ?? (apt.clientId.isNotEmpty ? apt.clientId : '—');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Riga 1: titolo + importo ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(apt.titolo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${DateHelpers.formatDate(apt.data)}  •  ${apt.oraInizio}–${apt.oraFine}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(DateHelpers.formatCurrency(apt.totale),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primary)),
                    Text('${apt.oreTotali.toStringAsFixed(1)}h × ${apt.tariffa.toStringAsFixed(0)}€/h',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 8),

            // ── Riga 2: persona + cliente ──
            Row(
              children: [
                // Persona
                Expanded(
                  child: Row(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: primary.withOpacity(0.12),
                      child: Text(
                        personaNome.isNotEmpty ? personaNome[0].toUpperCase() : 'U',
                        style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Persona', style: TextStyle(fontSize: 9, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                        Text(personaNome,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ],
                    )),
                  ]),
                ),
                const SizedBox(width: 12),
                // Cliente
                Expanded(
                  child: Row(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.teal.withOpacity(0.12),
                      child: Text(
                        clienteNome.isNotEmpty && clienteNome != '—' ? clienteNome[0].toUpperCase() : 'C',
                        style: const TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cliente', style: TextStyle(fontSize: 9, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                        Text(clienteNome,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ],
                    )),
                  ]),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Riga 3: toggle Fatt. + Pag. ──
            Row(children: [
              _toggleBadge(
                label: 'Fatturato',
                active: apt.fatturato,
                activeColor: Colors.orange,
                enabled: isAdmin,
                tooltip: isAdmin
                    ? (apt.fatturato ? 'Annulla fatturazione' : 'Segna come fatturato')
                    : 'Solo admin',
                onTap: () => _toggleFatturato(apt),
              ),
              const SizedBox(width: 8),
              _toggleBadge(
                label: 'Pagato',
                active: apt.pagato,
                activeColor: Colors.green,
                enabled: true,
                tooltip: apt.pagato ? 'Annulla pagamento' : 'Segna come pagato',
                onTap: () => _togglePagato(apt),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── TOGGLE BADGE ────────────────────────────────────────────────────────────
  Widget _toggleBadge({
    required String label,
    required bool active,
    required Color activeColor,
    required bool enabled,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? activeColor.withOpacity(0.12) : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? activeColor : Colors.grey.shade300,
              width: active ? 1.5 : 1.0,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              active ? Icons.check : Icons.circle_outlined,
              size: 13,
              color: active ? activeColor : Colors.grey[400],
            ),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? activeColor : Colors.grey[400],
            )),
            if (!enabled) ...[
              const SizedBox(width: 4),
              Icon(Icons.lock_outline, size: 11, color: Colors.grey[300]),
            ],
          ]),
        ),
      ),
    );
  }

  // ── METRIC BOX ──────────────────────────────────────────────────────────────
  Widget _metricBox(String label, String value, Color color, IconData icon, double amount, double total) {
    final pct = (total > 0) ? (amount / total).clamp(0.0, 1.0) : 0.0;
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
                width: 26, height: 26,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500))),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
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
          color: active ? primary : Colors.grey[600],
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }
}

