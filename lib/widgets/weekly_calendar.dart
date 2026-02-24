import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../models/room.dart';
import '../services/appointment_service.dart';
import '../services/room_service.dart';
import '../services/auth_service.dart';

class WeeklyCalendar extends StatefulWidget {
  final DateTime focusedWeek;
  final Function(Appointment) onTapAppointment;
  final Function(DateTime) onTapSlot;

  WeeklyCalendar({
    required this.focusedWeek,
    required this.onTapAppointment,
    required this.onTapSlot,
  });

  @override
  _WeeklyCalendarState createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  final AppointmentService _aptService = AppointmentService();
  final RoomService _roomService = RoomService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final double _hourH = 64.0;
  final double _timeW = 52.0;
  final int _start = 7;
  final int _end = 22;

  Map<String, Color> _userColors = {};
  Map<String, String> _userNames = {};
  Map<String, String> _clientNames = {}; // ✅ NUOVO: clientId → fullName
  Map<String, Room> _rooms = {};

  List<DateTime> get _days {
    final mon = widget.focusedWeek
        .subtract(Duration(days: widget.focusedWeek.weekday - 1));
    return List.generate(7, (i) => mon.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadClients(); // ✅ NUOVO
    _roomService.getRooms().listen((rooms) =>
        setState(() => _rooms = {for (var r in rooms) r.id!: r}));
  }

  Future<void> _loadUsers() async {
    final snap = await _db.collection('users').get();
    final c = <String, Color>{};
    final n = <String, String>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final hex = d['personaColor']?.toString().replaceAll('#', '') ?? '607D8B';
      try { c[doc.id] = Color(int.parse('FF$hex', radix: 16)); }
      catch (_) { c[doc.id] = Colors.blueGrey; }
      n[doc.id] = d['displayName']?.toString() ?? d['email']?.toString() ?? 'Utente';
    }
    setState(() { _userColors = c; _userNames = n; });
  }

  // ✅ NUOVO: carica nome+cognome di tutti i clienti
  Future<void> _loadClients() async {
    final snap = await _db.collection('clients').get();
    final m = <String, String>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final nome = d['nome']?.toString() ?? '';
      final cognome = d['cognome']?.toString() ?? '';
      m[doc.id] = '$nome $cognome'.trim();
    }
    setState(() => _clientNames = m);
  }

  Color _uColor(String uid) => _userColors[uid] ?? Colors.blueGrey;
  String _uName(String uid) => _userNames[uid] ?? '';
  String _cName(String cid) => _clientNames[cid] ?? ''; // ✅ NUOVO

  Color _rColor(String? id) {
    if (id == null || !_rooms.containsKey(id)) return Colors.grey;
    try {
      return Color(int.parse('FF${_rooms[id]!.color.replaceAll('#', '')}', radix: 16));
    } catch (_) { return Colors.grey; }
  }

  double _topOf(String t) {
    final p = t.split(':');
    if (p.length < 2) return 0;
    return ((int.parse(p[0]) - _start) + int.parse(p[1]) / 60.0) * _hourH;
  }

  double _hOf(String s, String e) {
    final sp = s.split(':'); final ep = e.split(':');
    if (sp.length < 2 || ep.length < 2) return _hourH;
    final diff = (int.parse(ep[0]) * 60 + int.parse(ep[1])) -
                 (int.parse(sp[0]) * 60 + int.parse(sp[1]));
    return (diff.clamp(15, 900) / 60.0) * _hourH;
  }

  Map<String, _ColLayout> _computeLayout(List<Appointment> apts) {
    final result = <String, _ColLayout>{};
    final sorted = [...apts]..sort((a, b) => a.oraInizio.compareTo(b.oraInizio));
    final clusters = <List<Appointment>>[];
    for (final apt in sorted) {
      bool added = false;
      for (final cluster in clusters) {
        if (cluster.any((c) => _overlaps(c, apt))) {
          cluster.add(apt);
          added = true;
          break;
        }
      }
      if (!added) clusters.add([apt]);
    }
    for (final cluster in clusters) {
      final n = cluster.length;
      for (int i = 0; i < n; i++) {
        result[cluster[i].id ?? cluster[i].titolo] = _ColLayout(i, n);
      }
    }
    return result;
  }

  bool _overlaps(Appointment a, Appointment b) {
    final s1 = _toMin(a.oraInizio); final e1 = _toMin(a.oraFine);
    final s2 = _toMin(b.oraInizio); final e2 = _toMin(b.oraFine);
    return s1 < e2 && e1 > s2;
  }

  int _toMin(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  @override
  Widget build(BuildContext context) {
    final totalH = (_end - _start) * _hourH;
    final auth = Provider.of<AuthService>(context);
    final me = auth.currentUser;
    final primary = Theme.of(context).colorScheme.primary;

    return StreamBuilder<List<Appointment>>(
      stream: _aptService.getAppointments(_days.first, _days.last),
      builder: (context, snap) {
        final apts = snap.data ?? [];

        return LayoutBuilder(builder: (context, constraints) {
          final dw = (constraints.maxWidth - _timeW) / 7;

          return Column(children: [

            // ── HEADER ──────────────────────────────────────────
            Row(children: [
              Container(
                width: _timeW, height: 56,
                decoration: BoxDecoration(color: Colors.white),
              ),
              ..._days.map((d) {
                final today = _isToday(d);
                return Container(
                  width: dw, height: 56,
                  decoration: BoxDecoration(
                    color: today ? primary.withOpacity(0.07) : Colors.white,
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade200),
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_dn(d.weekday), style: TextStyle(
                        fontSize: 10, letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: today ? primary : Colors.grey.shade500,
                      )),
                      SizedBox(height: 3),
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: today ? primary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('${d.day}', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: today ? Colors.white : Colors.black87,
                        )),
                      ),
                    ],
                  ),
                );
              }),
            ]),

            // ── CORPO SCROLLABILE ────────────────────────────────
            Expanded(child: SingleChildScrollView(
              child: SizedBox(
                height: totalH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // COLONNA ORE
                    Container(
                      width: _timeW,
                      height: totalH,
                      color: Colors.white,
                      child: Stack(
                        children: List.generate(_end - _start, (i) =>
                          Positioned(
                            top: i * _hourH - 8,
                            right: 6,
                            child: Text(
                              '${(_start + i).toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // COLONNE GIORNI
                    ..._days.map((d) {
                      final today = _isToday(d);
                      final dayApts = apts.where((a) =>
                        a.data.year == d.year &&
                        a.data.month == d.month &&
                        a.data.day == d.day
                      ).toList();

                      final layout = _computeLayout(dayApts);

                      return SizedBox(
                        width: dw,
                        height: totalH,
                        child: Stack(
                          children: [

                            // SFONDO + GRIGLIA
                            ...List.generate(_end - _start, (i) =>
                              Positioned(
                                top: i * _hourH,
                                left: 0, right: 0,
                                height: _hourH,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: today
                                        ? primary.withOpacity(0.02)
                                        : Colors.white,
                                    border: Border(
                                      top: BorderSide(color: Colors.grey.shade200),
                                      left: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // LINEA MEZZ'ORA
                            ...List.generate(_end - _start, (i) =>
                              Positioned(
                                top: i * _hourH + _hourH / 2,
                                left: 4, right: 0, height: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                              ),
                            ),

                            // AREA TAP VUOTA
                            ...List.generate(_end - _start, (i) =>
                              Positioned(
                                top: i * _hourH,
                                left: 0, right: 0, height: _hourH,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () => widget.onTapSlot(DateTime(
                                      d.year, d.month, d.day, _start + i)),
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ),

                            // LINEA ORA CORRENTE
                            if (today) _buildNowLine(primary),

                            // ── APPUNTAMENTI ──────────────────────
                            ...dayApts.map((apt) {
                              final key = apt.id ?? apt.titolo;
                              final col = layout[key] ?? _ColLayout(0, 1);
                              final top = _topOf(apt.oraInizio).clamp(0.0, totalH - 26.0);
                              final h   = _hOf(apt.oraInizio, apt.oraFine).clamp(26.0, totalH - top);
                              final uColor = _uColor(apt.userId);
                              final rColor = _rColor(apt.roomId);
                              final room   = _rooms[apt.roomId];
                              final isMine = apt.userId == me?.uid;
                              final canSee = isMine || (me?.isAdmin ?? false);

                              // ✅ Nome cliente (solo se canSee)
                              final clienteNome = canSee ? _cName(apt.clientId) : '';

                              final padding = 2.0;
                              final colW = (dw - padding * (col.total + 1)) / col.total;
                              final leftPos = padding + col.index * (colW + padding);

                              // ✅ Soglie altezza adattive per colonne affiancate
                              final sogliaStanza  = col.total > 1 ? 36.0 : 44.0;
                              final sogliaCliente = col.total > 1 ? 52.0 : 60.0;
                              final sogliaTariffa = col.total > 1 ? 70.0 : 76.0;

                              return Positioned(
                                top: top,
                                left: leftPos,
                                width: colW,
                                height: h,
                                child: GestureDetector(
                                  onTap: () => widget.onTapAppointment(apt),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: uColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: uColor, width: 1.5),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [

                                          // BARRA SINISTRA = colore stanza
                                          Container(
                                            width: 4,
                                            decoration: BoxDecoration(
                                              color: rColor,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(4),
                                                bottomLeft: Radius.circular(4),
                                              ),
                                            ),
                                          ),

                                          // CONTENUTO
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 3),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [

                                                  // ── ORARIO
                                                  Text(
                                                    '${apt.oraInizio}–${apt.oraFine}',
                                                    style: TextStyle(
                                                      fontSize: col.total > 1 ? 10 : 13,
                                                      color: Colors.black54,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),

                                                  // ── TITOLO
                                                  Text(
                                                    apt.titolo,
                                                    style: TextStyle(
                                                      fontSize: col.total > 1 ? 11 : 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.black87,
                                                      height: 1.2,
                                                    ),
                                                    maxLines: col.total > 1 ? 1 : 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),

                                                  // ── STANZA (visibile a tutti)
                                                  if (room != null && h > sogliaStanza)
                                                    Row(children: [
                                                      Container(
                                                        width: 6, height: 6,
                                                        margin: EdgeInsets.only(right: 3, top: 1),
                                                        decoration: BoxDecoration(
                                                          color: rColor,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          room.name,
                                                          style: TextStyle(
                                                            fontSize: col.total > 1 ? 10 : 12,
                                                            color: rColor,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ]),

                                                  // ── CLIENTE ✅ solo proprietario/admin
                                                  if (canSee && h > sogliaCliente && clienteNome.isNotEmpty)
                                                    Row(children: [
                                                      Icon(
                                                        Icons.person,
                                                        size: col.total > 1 ? 9 : 11,
                                                        color: Colors.black45,
                                                      ),
                                                      SizedBox(width: 2),
                                                      Expanded(
                                                        child: Text(
                                                          clienteNome,
                                                          style: TextStyle(
                                                            fontSize: col.total > 1 ? 10 : 12,
                                                            color: Colors.black54,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ]),

                                                  // ── TARIFFA ✅ solo proprietario/admin
                                                  if (canSee && h > sogliaTariffa)
                                                    Text(
                                                      '€${apt.tariffa.toStringAsFixed(0)}/h · €${apt.totale.toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                        fontSize: col.total > 1 ? 9 : 11,
                                                        color: Colors.black38,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),

                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            )),

          ]);
        });
      },
    );
  }

  Widget _buildNowLine(Color c) {
    final n = DateTime.now();
    if (n.hour < _start || n.hour >= _end) return SizedBox.shrink();
    final top = ((n.hour - _start) + n.minute / 60.0) * _hourH;
    return Positioned(
      top: top, left: 0, right: 0,
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        Expanded(child: Container(
          height: 2,
          decoration: BoxDecoration(color: c.withOpacity(0.5)),
        )),
      ]),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String _dn(int w) => ['LUN','MAR','MER','GIO','VEN','SAB','DOM'][w - 1];
}

// ── Helper layout colonne ─────────────────────────────────────────
class _ColLayout {
  final int index;
  final int total;
  const _ColLayout(this.index, this.total);
}
