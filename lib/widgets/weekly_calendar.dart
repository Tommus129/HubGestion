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
  final String? filterUserId;
  final String? filterRoomId;
  final String? filterClientId;

  WeeklyCalendar({
    required this.focusedWeek,
    required this.onTapAppointment,
    required this.onTapSlot,
    this.filterUserId,
    this.filterRoomId,
    this.filterClientId,
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
  final int _end   = 22;

  Map<String, Color>  _userColors  = {};
  Map<String, String> _userNames   = {};
  Map<String, String> _clientNames = {};
  Map<String, Room>   _rooms       = {};

  List<DateTime> get _days {
    final mon = widget.focusedWeek
        .subtract(Duration(days: widget.focusedWeek.weekday - 1));
    return List.generate(7, (i) => mon.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadClients();
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

  Future<void> _loadClients() async {
    final snap = await _db.collection('clients').get();
    final m = <String, String>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      m[doc.id] = '${d['nome'] ?? ''} ${d['cognome'] ?? ''}'.trim();
    }
    setState(() => _clientNames = m);
  }

  Color _darker(Color c, double amount) {
    final a = amount.clamp(0.0, 1.0);
    return Color.fromARGB(c.alpha,
      (c.red   * (1 - a)).round(),
      (c.green * (1 - a)).round(),
      (c.blue  * (1 - a)).round(),
    );
  }

  Color  _uColor(String uid) => _userColors[uid] ?? Colors.blueGrey;
  String _cName(String cid)  => _clientNames[cid] ?? '';

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

  int _toMin(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  bool _overlaps(Appointment a, Appointment b) {
    return _toMin(a.oraInizio) < _toMin(b.oraFine) &&
           _toMin(a.oraFine)   > _toMin(b.oraInizio);
  }

  Map<String, _ColLayout> _computeLayout(List<Appointment> apts) {
    final result = <String, _ColLayout>{};
    final sorted = [...apts]..sort((a, b) => a.oraInizio.compareTo(b.oraInizio));
    final clusters = <List<Appointment>>[];
    for (final apt in sorted) {
      bool added = false;
      for (final cluster in clusters) {
        if (cluster.any((c) => _overlaps(c, apt))) {
          cluster.add(apt); added = true; break;
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

  List<Appointment> _applyFilters(List<Appointment> apts) {
    return apts.where((a) {
      if (widget.filterUserId   != null && a.userId   != widget.filterUserId)   return false;
      if (widget.filterRoomId   != null && a.roomId   != widget.filterRoomId)   return false;
      if (widget.filterClientId != null && a.clientId != widget.filterClientId) return false;
      return true;
    }).toList();
  }

  // ── Contenuto card adattivo in base ai pixel disponibili ─────────────────
  Widget _aptContent({
    required Appointment apt,
    required double h,
    required double w,
    required int n,
    required Color uColor,
    required Color rColor,
    required Room? room,
    required bool canSee,
    required String clienteNome,
  }) {
    // Padding verticale adattivo: meno spazio per card piccole
    final vPad  = h < 32 ? 1.0 : (h < 48 ? 2.0 : 3.0);
    final avail = h - vPad * 2;

    // Altezze stimate ridotte per stare nel budget
    const double rowOrario  = 11.0;
    const double rowTitolo  = 13.0;
    const double rowStanza  = 11.0;
    const double rowCliente = 11.0;
    const double rowTariffa = 10.0;
    const double rowBadge   = 13.0;
    const double gap        = 1.0;


    double used = 0;

    bool show(double rowH) {
      if (used + rowH + gap > avail) return false;
      used += rowH + gap;
      return true;
    }

    final showOrario  = show(rowOrario);
    final showTitolo  = showOrario && show(rowTitolo);
    final showStanza  = room != null && canSee && show(rowStanza);
    final showCliente = canSee && clienteNome.isNotEmpty && show(rowCliente);
    final showTariffa = canSee && n == 1 && show(rowTariffa);
    final showBadge   = canSee && n <= 2 && show(rowBadge);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3, vertical: vPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showOrario)
            Text(
              n >= 3 ? apt.oraInizio : '${apt.oraInizio}–${apt.oraFine}',
              style: TextStyle(
                fontSize: n >= 3 ? 8 : 10,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          if (showTitolo)
            Text(
              apt.titolo,
              style: TextStyle(
                fontSize: n >= 3 ? 9 : (n == 2 ? 10 : 12),
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.1,
              ),
              maxLines: n >= 3 ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (showStanza)
            Row(children: [
              Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(color: rColor, shape: BoxShape.circle),
              ),
              Expanded(child: Text(
                room!.name,
                style: TextStyle(fontSize: 9, color: rColor, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
            ]),
          if (showCliente)
            Row(children: [
              const Icon(Icons.person, size: 8, color: Colors.black38),
              const SizedBox(width: 2),
              Expanded(child: Text(
                clienteNome,
                style: const TextStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
            ]),
          if (showTariffa)
            Text(
              '€${apt.tariffa.toStringAsFixed(0)}/h · €${apt.totale.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 8, color: Colors.black38, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          if (showBadge)
            Row(children: [
              _badge(apt.fatturato ? 'Fatt.✓' : 'Fatt.✗',
                     apt.fatturato ? Colors.orange : Colors.grey),
              const SizedBox(width: 2),
              _badge(apt.pagato ? 'Pag.✓' : 'Pag.✗',
                     apt.pagato ? Colors.green : Colors.grey),
            ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalH = (_end - _start) * _hourH;
    final auth    = Provider.of<AuthService>(context);
    final me      = auth.currentUser;
    final primary = Theme.of(context).colorScheme.primary;

    return StreamBuilder<List<Appointment>>(
      stream: _aptService.getAppointments(_days.first, _days.last),
      builder: (context, snap) {
        final allApts = snap.data ?? [];

        return LayoutBuilder(builder: (context, constraints) {
          final dw = (constraints.maxWidth - _timeW) / 7;

          return Column(children: [

            // ── HEADER ──────────────────────────────────────────
            Row(children: [
              Container(width: _timeW, height: 56, color: Colors.white),
              ..._days.map((d) {
                final today = _isToday(d);
                return Container(
                  width: dw, height: 56,
                  decoration: BoxDecoration(
                    color: today ? primary.withOpacity(0.07) : Colors.white,
                    border: Border(
                      left:   BorderSide(color: Colors.grey.shade200),
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_dn(d.weekday), style: TextStyle(
                        fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w700,
                        color: today ? primary : Colors.grey.shade500,
                      )),
                      const SizedBox(height: 3),
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

            // ── CORPO ───────────────────────────────────────────
            Expanded(child: SingleChildScrollView(
              child: SizedBox(
                height: totalH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Colonna ore
                    SizedBox(
                      width: _timeW, height: totalH,
                      child: Stack(
                        children: List.generate(_end - _start, (i) =>
                          Positioned(
                            top: i * _hourH - 8, right: 6,
                            child: Text(
                              '${(_start + i).toString().padLeft(2, '0')}:00',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Colonne giorni
                    ..._days.map((d) {
                      final today   = _isToday(d);
                      final dayApts = _applyFilters(
                        allApts.where((a) =>
                          a.data.year  == d.year &&
                          a.data.month == d.month &&
                          a.data.day   == d.day
                        ).toList(),
                      );
                      final layout = _computeLayout(dayApts);

                      return SizedBox(
                        width: dw, height: totalH,
                        child: ClipRect(
                          child: Stack(children: [

                            // Griglia
                            ...List.generate(_end - _start, (i) =>
                              Positioned(
                                top: i * _hourH, left: 0, right: 0, height: _hourH,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: today ? primary.withOpacity(0.02) : Colors.white,
                                    border: Border(
                                      top:  BorderSide(color: Colors.grey.shade200),
                                      left: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Linee mezz'ora
                            ...List.generate(_end - _start, (i) =>
                              Positioned(
                                top: i * _hourH + _hourH / 2,
                                left: 4, right: 0, height: 1,
                                child: Container(color: Colors.grey.shade100),
                              ),
                            ),

                            // Tap slot vuoto
                            ...List.generate(_end - _start, (i) =>
                              Positioned(
                                top: i * _hourH, left: 0, right: 0, height: _hourH,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () => widget.onTapSlot(
                                      DateTime(d.year, d.month, d.day, _start + i)),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),

                            // Linea ora corrente
                            if (today) _buildNowLine(primary),

                            // Appuntamenti
                            ...dayApts.map((apt) {
                              final key    = apt.id ?? apt.titolo;
                              final col    = layout[key] ?? _ColLayout(0, 1);
                              final top    = _topOf(apt.oraInizio).clamp(0.0, totalH - 24.0);
                              // ✅ FIX: hMax ridotto di 1px per evitare bottom overflow
                              // su appuntamenti brevi (es. 30 min) a fine griglia
                              final hRaw   = _hOf(apt.oraInizio, apt.oraFine);
                              final hMax   = (totalH - top - 1.0).clamp(22.0, totalH);
                              final h      = hRaw.clamp(22.0, hMax);

                              final uColor = _uColor(apt.userId);
                              final rColor = _rColor(apt.roomId);
                              final room   = _rooms[apt.roomId];
                              final isMine = apt.userId == me?.uid;
                              final canSee = isMine || (me?.isAdmin ?? false);
                              final clienteNome = canSee ? _cName(apt.clientId) : '';

                              final gap2   = 2.0;
                              final colW   = (dw - gap2 * (col.total + 1)) / col.total;
                              final leftPos = gap2 + col.index * (colW + gap2);
                              final n      = col.total;

                              return Positioned(
                                top: top, left: leftPos, width: colW, height: h,
                                child: GestureDetector(
                                  onTap: () => widget.onTapAppointment(apt),
                                  child: Container(
                                    // ✅ clipBehavior: taglia fisicamente tutto ciò che sfora
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                      color: uColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: uColor, width: 1.5),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Barra stanza
                                        Container(
                                          width: 4,
                                          color: rColor,
                                        ),
                                        // Contenuto adattivo
                                        Expanded(
                                          child: _aptContent(
                                            apt: apt,
                                            h: h,
                                            w: colW - 4,
                                            n: n,
                                            uColor: uColor,
                                            rColor: rColor,
                                            room: room,
                                            canSee: canSee,
                                            clienteNome: clienteNome,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ]),
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

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 7, fontWeight: FontWeight.w700,
          color: color == Colors.grey ? Colors.grey.shade500 : _darker(color, 0.35),
        ),
        overflow: TextOverflow.clip, maxLines: 1,
      ),
    );
  }

  Widget _buildNowLine(Color c) {
    final n = DateTime.now();
    if (n.hour < _start || n.hour >= _end) return const SizedBox.shrink();
    final top = ((n.hour - _start) + n.minute / 60.0) * _hourH;
    return Positioned(
      top: top, left: 0, right: 0,
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        Expanded(child: Container(height: 2, color: c.withOpacity(0.5))),
      ]),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String _dn(int w) => ['LUN','MAR','MER','GIO','VEN','SAB','DOM'][w - 1];
}

class _ColLayout {
  final int index;
  final int total;
  const _ColLayout(this.index, this.total);
}
