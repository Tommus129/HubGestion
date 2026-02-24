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
    _roomService.getRooms().listen((rooms) =>
        setState(() => _rooms = {for (var r in rooms) r.id!: r}));
  }

  Future<void> _loadUsers() async {
    final snap = await _db.collection('users').get();
    final colors = <String, Color>{};
    final names = <String, String>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final hex = (d['personaColor'] ?? '#607D8B').replaceAll('#', '');
      try {
        colors[doc.id] = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {
        colors[doc.id] = Colors.blueGrey;
      }
      names[doc.id] = (d['displayName'] ?? d['email'] ?? '').toString();
    }
    setState(() { _userColors = colors; _userNames = names; });
  }

  Color _uColor(String uid) => _userColors[uid] ?? Colors.blueGrey;
  String _uName(String uid) => _userNames[uid] ?? '';

  Color _rColor(String? id) {
    if (id == null || !_rooms.containsKey(id)) return Colors.grey;
    try {
      final hex = _rooms[id]!.color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) { return Colors.grey; }
  }

  double _topOf(String t) {
    final p = t.split(':');
    if (p.length < 2) return 0;
    return ((int.parse(p[0]) - _start) + int.parse(p[1]) / 60.0) * _hourH;
  }

  double _heightOf(String s, String e) {
    final sp = s.split(':'); final ep = e.split(':');
    if (sp.length < 2 || ep.length < 2) return _hourH;
    final diff = (int.parse(ep[0]) * 60 + int.parse(ep[1])) -
                 (int.parse(sp[0]) * 60 + int.parse(sp[1]));
    return (diff / 60.0) * _hourH;
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

        return LayoutBuilder(builder: (context, box) {
          final dw = (box.maxWidth - _timeW) / 7;

          return Column(children: [

            // ── HEADER GIORNI ──
            Container(
              color: Colors.white,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(children: [
                SizedBox(width: _timeW),
                ..._days.map((d) {
                  final isToday = _isToday(d);
                  return SizedBox(width: dw, child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday ? primary.withOpacity(0.08) : Colors.white,
                      border: Border(left: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Column(children: [
                      Text(
                        _dn(d.weekday),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: isToday ? primary : Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: isToday ? primary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: isToday ? Colors.white : Colors.black87,
                          ),
                        )),
                      ),
                    ]),
                  ));
                }),
              ]),
            ),

            // ── GRIGLIA ──
            Expanded(child: SingleChildScrollView(
              child: SizedBox(height: totalH, child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // COLONNA ORARI
                  SizedBox(width: _timeW, child: Stack(
                    children: List.generate(_end - _start, (i) => Positioned(
                      top: i * _hourH - 8, right: 6,
                      child: Text(
                        '${(_start + i).toString().padLeft(2,'0')}:00',
                        style: TextStyle(fontSize: 10,
                            color: Colors.grey[400], fontWeight: FontWeight.w500),
                      ),
                    )),
                  )),

                  // COLONNE GIORNI
                  ..._days.map((d) {
                    final dayApts = apts.where((a) =>
                      a.data.year == d.year &&
                      a.data.month == d.month &&
                      a.data.day == d.day
                    ).toList();
                    final isToday = _isToday(d);

                    return SizedBox(width: dw, height: totalH,
                      child: Stack(children: [

                        // CELLE ORE
                        ...List.generate(_end - _start, (i) => Positioned(
                          top: i * _hourH, left: 0, right: 0,
                          child: Column(children: [
                            Container(
                              height: _hourH / 2,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? primary.withOpacity(0.02)
                                    : Colors.white,
                                border: Border(
                                  top: BorderSide(color: Colors.grey[200]!),
                                  left: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                            ),
                            Container(
                              height: _hourH / 2,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? primary.withOpacity(0.02)
                                    : Colors.white,
                                border: Border(
                                  top: BorderSide(color: Colors.grey[100]!),
                                  left: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                            ),
                          ]),
                        )),

                        // SLOT TAP
                        ...List.generate(_end - _start, (i) => Positioned(
                          top: i * _hourH, left: 0, right: 0, height: _hourH,
                          child: GestureDetector(
                            onTap: () => widget.onTapSlot(
                                DateTime(d.year, d.month, d.day, _start + i)),
                            child: Container(color: Colors.transparent),
                          ),
                        )),

                        // LINEA ORA ATTUALE
                        if (isToday) _nowLine(primary, totalH),

                        // ── APPUNTAMENTI ──
                        ...dayApts.map((apt) {
                          final top = _topOf(apt.oraInizio).clamp(0.0, totalH);
                          final h = _heightOf(apt.oraInizio, apt.oraFine)
                              .clamp(24.0, totalH - top);

                          final uColor = _uColor(apt.userId);
                          final rColor = _rColor(apt.roomId);
                          final room = _rooms[apt.roomId];
                          final isMine = apt.userId == me?.uid;
                          final canDetail = isMine || (me?.isAdmin ?? false);

                          return Positioned(
                            top: top, left: 2, right: 2, height: h,
                            child: GestureDetector(
                              onTap: () => widget.onTapAppointment(apt),
                              child: Container(
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  color: uColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border(
                                    left: BorderSide(color: rColor, width: 4),
                                    top: BorderSide(color: uColor.withOpacity(0.5), width: 1),
                                    right: BorderSide(color: uColor.withOpacity(0.5), width: 1),
                                    bottom: BorderSide(color: uColor.withOpacity(0.5), width: 1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.only(
                                    left: 5, top: 3, right: 4, bottom: 2),
                                child: _aptContent(
                                  apt: apt,
                                  h: h,
                                  uColor: uColor,
                                  rColor: rColor,
                                  room: room,
                                  canDetail: canDetail,
                                ),
                              ),
                            ),
                          );
                        }),
                      ]),
                    );
                  }),
                ],
              )),
            )),
          ]);
        });
      },
    );
  }

  Widget _aptContent({
    required Appointment apt,
    required double h,
    required Color uColor,
    required Color rColor,
    required Room? room,
    required bool canDetail,
  }) {
    return DefaultTextStyle(
      style: TextStyle(color: Colors.black87),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ORARIO
          Text(
            '${apt.oraInizio} – ${apt.oraFine}',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),

          // TITOLO - sempre visibile
          Text(
            apt.titolo,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            maxLines: h > 50 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),

          // STANZA - sempre visibile
          if (room != null && h > 34)
            Row(children: [
              Container(
                width: 8, height: 8,
                margin: EdgeInsets.only(right: 3),
                decoration: BoxDecoration(color: rColor, shape: BoxShape.circle),
              ),
              Expanded(child: Text(
                room.name,
                style: TextStyle(
                  fontSize: 9,
                  color: rColor,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
            ]),

          // UTENTE (solo admin/creatore)
          if (canDetail && h > 52 && _uName(apt.userId).isNotEmpty)
            Text(
              _uName(apt.userId),
              style: TextStyle(
                fontSize: 9,
                color: uColor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          // TARIFFA
          if (canDetail && h > 68)
            Text(
              '€${apt.tariffa.toStringAsFixed(0)}/h · €${apt.totale.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
            ),

          // BADGE
          if (h > 84)
            Row(children: [
              if (apt.fatturato) _badge('FAT', Colors.orange),
              if (apt.pagato) _badge('PAG', Colors.green),
            ]),
        ],
      ),
    );
  }

  Widget _badge(String txt, Color c) => Container(
    margin: EdgeInsets.only(right: 3, top: 2),
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: c.withOpacity(0.15),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: c.withOpacity(0.5)),
    ),
    child: Text(txt, style: TextStyle(
        fontSize: 8, color: c, fontWeight: FontWeight.bold)),
  );

  Widget _nowLine(Color c, double totalH) {
    final n = DateTime.now();
    if (n.hour < _start || n.hour >= _end) return SizedBox.shrink();
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

  String _dn(int w) =>
      ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'][w - 1];
}
