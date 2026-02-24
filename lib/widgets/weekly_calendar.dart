import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../models/room.dart';
import '../models/user.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final double _hourHeight = 64.0;
  final double _timeColWidth = 48.0;
  final int _startHour = 7;
  final int _endHour = 22;

  Map<String, Color> _userColors = {};
  Map<String, String> _userNames = {};
  Map<String, Room> _rooms = {};
  List<Appointment> _appointments = [];

  List<DateTime> get _weekDays {
    final monday = widget.focusedWeek.subtract(
        Duration(days: widget.focusedWeek.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadRooms();
  }

  Future<void> _loadUsers() async {
    final snap = await _firestore.collection('users').get();
    final colors = <String, Color>{};
    final names = <String, String>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final hex = (d['personaColor'] ?? '#888888').replaceAll('#', '');
      colors[doc.id] = Color(int.parse('FF$hex', radix: 16));
      names[doc.id] = d['displayName'] ?? d['email'] ?? '';
    }
    setState(() { _userColors = colors; _userNames = names; });
  }

  void _loadRooms() {
    _roomService.getRooms().listen((rooms) {
      setState(() => _rooms = {for (var r in rooms) r.id!: r});
    });
  }

  Color _userColor(String uid) => _userColors[uid] ?? Colors.blueGrey;
  String _userName(String uid) => _userNames[uid] ?? '';

  Color _roomColor(String? roomId) {
    if (roomId == null || !_rooms.containsKey(roomId)) return Colors.grey;
    final hex = _rooms[roomId]!.color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  double _timeToOffset(String time) {
    final p = time.split(':');
    return ((int.parse(p[0]) - _startHour) + int.parse(p[1]) / 60.0) * _hourHeight;
  }

  double _durationToHeight(String start, String end) {
    final s = start.split(':');
    final e = end.split(':');
    final diff = (int.parse(e[0]) * 60 + int.parse(e[1])) -
                 (int.parse(s[0]) * 60 + int.parse(s[1]));
    return (diff / 60.0) * _hourHeight;
  }

  @override
  Widget build(BuildContext context) {
    final totalHeight = (_endHour - _startHour) * _hourHeight;
    final auth = Provider.of<AuthService>(context);
    final currentUser = auth.currentUser;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return StreamBuilder<List<Appointment>>(
      stream: _aptService.getAppointments(_weekDays.first, _weekDays.last),
      builder: (context, snapshot) {
        _appointments = snapshot.data ?? [];

        return LayoutBuilder(builder: (context, constraints) {
          final dayColWidth = (constraints.maxWidth - _timeColWidth) / 7;

          return Column(children: [

            // HEADER GIORNI
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(children: [
                SizedBox(width: _timeColWidth),
                ..._weekDays.map((day) {
                  final isToday = _isToday(day);
                  return SizedBox(
                    width: dayColWidth,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isToday ? primary.withOpacity(0.08) : null,
                        border: Border(left: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Column(children: [
                        Text(_dayName(day.weekday),
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday ? primary : Colors.grey[500],
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 3),
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: isToday ? primary : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text('${day.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isToday ? Colors.white : Colors.grey[800],
                            ),
                          )),
                        ),
                      ]),
                    ),
                  );
                }),
              ]),
            ),

            // GRIGLIA
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: totalHeight,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // COLONNA ORA
                    SizedBox(
                      width: _timeColWidth,
                      child: Stack(
                        children: List.generate(_endHour - _startHour, (i) =>
                          Positioned(
                            top: i * _hourHeight - 7,
                            right: 6,
                            child: Text(
                              '${(_startHour + i).toString().padLeft(2,'0')}:00',
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // COLONNE GIORNI
                    ..._weekDays.map((day) {
                      final dayApts = _appointments.where((a) =>
                        a.data.year == day.year &&
                        a.data.month == day.month &&
                        a.data.day == day.day
                      ).toList();
                      final isToday = _isToday(day);

                      return SizedBox(
                        width: dayColWidth,
                        height: totalHeight,
                        child: Stack(children: [

                          // RIGHE ORE
                          ...List.generate(_endHour - _startHour, (i) =>
                            Positioned(
                              top: i * _hourHeight, left: 0, right: 0,
                              child: Container(
                                height: _hourHeight,
                                decoration: BoxDecoration(
                                  color: isToday ? primary.withOpacity(0.015) : null,
                                  border: Border(
                                    top: BorderSide(color: Colors.grey[200]!),
                                    left: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // MEZZ'ORA
                          ...List.generate(_endHour - _startHour, (i) =>
                            Positioned(
                              top: i * _hourHeight + _hourHeight / 2,
                              left: 0, right: 0,
                              child: Container(height: 1, color: Colors.grey[100]),
                            ),
                          ),

                          // SLOT CLICCABILI
                          ...List.generate(_endHour - _startHour, (i) =>
                            Positioned(
                              top: i * _hourHeight, left: 0, right: 0,
                              height: _hourHeight,
                              child: GestureDetector(
                                onTap: () => widget.onTapSlot(DateTime(
                                  day.year, day.month, day.day, _startHour + i)),
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                          ),

                          // LINEA ORA CORRENTE
                          if (isToday) _nowLine(primary),

                          // APPUNTAMENTI
                          ...dayApts.map((apt) {
                            final top = _timeToOffset(apt.oraInizio).clamp(0.0, totalHeight);
                            final height = _durationToHeight(apt.oraInizio, apt.oraFine)
                                .clamp(20.0, totalHeight - top);

                            final uColor = _userColor(apt.userId);
                            final rColor = _roomColor(apt.roomId);
                            final room = _rooms[apt.roomId];
                            final isMine = apt.userId == currentUser?.uid;
                            final canSeeDetails = isMine || (currentUser?.isAdmin ?? false);

                            return Positioned(
                              top: top, left: 2, right: 2, height: height,
                              child: GestureDetector(
                                onTap: () => widget.onTapAppointment(apt),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: uColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border(
                                      left: BorderSide(color: rColor, width: 3),
                                      top: BorderSide(color: uColor.withOpacity(0.5), width: 1),
                                      right: BorderSide(color: uColor.withOpacity(0.5), width: 1),
                                      bottom: BorderSide(color: uColor.withOpacity(0.5), width: 1),
                                    ),
                                  ),
                                  padding: EdgeInsets.only(left: 5, top: 3, right: 4, bottom: 2),
                                  child: _aptContent(
                                    apt: apt,
                                    height: height,
                                    uColor: uColor,
                                    rColor: rColor,
                                    room: room,
                                    canSeeDetails: canSeeDetails,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ]),
                      );
                    }),
                  ]),
                ),
              ),
            ),
          ]);
        });
      },
    );
  }

  Widget _aptContent({
    required Appointment apt,
    required double height,
    required Color uColor,
    required Color rColor,
    required Room? room,
    required bool canSeeDetails,
  }) {
    final userName = _userName(apt.userId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TITOLO + ORA
        Row(children: [
          Expanded(
            child: Text(
              apt.titolo,
              style: TextStyle(
                color: uColor.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                fontSize: height > 40 ? 11 : 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (height > 24)
            Text(
              '${apt.oraInizio}',
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
        ]),

        // STANZA (sempre visibile)
        if (room != null && height > 28)
          Row(children: [
            Container(width: 6, height: 6, margin: EdgeInsets.only(right: 3),
              decoration: BoxDecoration(color: rColor, shape: BoxShape.circle)),
            Expanded(child: Text(
              room.name,
              style: TextStyle(fontSize: 9, color: rColor, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
          ]),

        // DETTAGLI (solo per chi può vedere)
        if (canSeeDetails && height > 44) ...[
          if (userName.isNotEmpty)
            Text(
              '👤 $userName',
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          if (height > 58)
            Text(
              '${apt.oraInizio} – ${apt.oraFine}  •  €${apt.tariffa.toStringAsFixed(0)}/h',
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
        ],

        // ICONE STATO
        if (height > 70)
          Row(children: [
            if (apt.fatturato)
              Icon(Icons.receipt, size: 10, color: Colors.orange[400]),
            if (apt.pagato)
              Icon(Icons.check_circle, size: 10, color: Colors.green[400]),
          ]),
      ],
    );
  }

  Widget _nowLine(Color primary) {
    final now = DateTime.now();
    if (now.hour < _startHour || now.hour >= _endHour) return SizedBox.shrink();
    final top = ((now.hour - _startHour) + now.minute / 60.0) * _hourHeight;
    return Positioned(
      top: top, left: 0, right: 0,
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: primary, shape: BoxShape.circle)),
        Expanded(child: Container(height: 1.5, color: primary.withOpacity(0.5))),
      ]),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String _dayName(int w) {
    const d = ['LUN','MAR','MER','GIO','VEN','SAB','DOM'];
    return d[w - 1];
  }
}
