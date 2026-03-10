import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../models/room.dart';
import '../services/appointment_service.dart';
import '../services/room_service.dart';
import '../services/auth_service.dart';

const int _kMaxVisible = 3;

// Ombra leggera per rendere le scritte leggibili su sfondo colorato/striato
const _kTextShadow = [
  Shadow(color: Color(0x55FFFFFF), offset: Offset(0, 1), blurRadius: 2),
  Shadow(color: Color(0x33000000), offset: Offset(0, 0), blurRadius: 3),
];

class WeeklyCalendar extends StatefulWidget {
  final DateTime focusedWeek;
  final Function(Appointment) onTapAppointment;
  final Function(DateTime) onTapSlot;
  final String? filterUserId;
  final String? filterRoomId;
  final String? filterClientId;

  const WeeklyCalendar({
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
    _roomService.getRooms().listen(
        (rooms) => setState(() => _rooms = {for (var r in rooms) r.id!: r}));
  }

  Color _generateUserColor(String uid) {
    final hash = uid.hashCode;
    return Color.fromARGB(
      255,
      (hash & 0xFF0000) >> 16,
      (hash & 0x00FF00) >> 8,
      (hash & 0x0000FF),
    );
  }

  Future<void> _loadUsers() async {
    final snap = await _db.collection('users').get();
    final c = <String, Color>{};
    final n = <String, String>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final hex = d['personaColor']?.toString().replaceAll('#', '') ?? '';
      try {
        c[doc.id] = hex.isNotEmpty
            ? Color(int.parse('FF$hex', radix: 16))
            : _generateUserColor(doc.id);
      } catch (_) {
        c[doc.id] = _generateUserColor(doc.id);
      }
      n[doc.id] = d['displayName']?.toString() ??
          d['email']?.toString() ??
          'Utente';
    }
    setState(() { _userColors = c; _userNames = n; });
  }

  Future<void> _loadClients() async {
    final snap = await _db.collection('clients').get();
    setState(() {
      _clientNames = {
        for (final doc in snap.docs)
          doc.id: '${doc.data()['nome'] ?? ''} ${doc.data()['cognome'] ?? ''}'.trim()
      };
    });
  }

  Color  _uColor(String uid) => _userColors[uid] ?? _generateUserColor(uid);
  String _cName(String cid)  => _clientNames[cid] ?? '';
  Color  _rColor(String? id) {
    if (id == null || !_rooms.containsKey(id)) return Colors.grey;
    try {
      return Color(int.parse('FF${_rooms[id]!.color.replaceAll('#', '')}', radix: 16));
    } catch (_) { return Colors.grey; }
  }

  List<Color> _aptColors(Appointment apt) {
    final seen = <String>{};
    final ids  = <String>[];
    if (apt.userId.isNotEmpty && seen.add(apt.userId)) ids.add(apt.userId);
    for (final w in apt.workerIds) {
      if (w.isNotEmpty && seen.add(w)) ids.add(w);
    }
    if (ids.isEmpty) return [Colors.blueGrey.shade200];
    return ids.map(_uColor).toList();
  }

  double _topOf(String t) {
    final p = t.split(':');
    if (p.length < 2) return 0;
    return ((int.parse(p[0]) - _start) + int.parse(p[1]) / 60.0) * _hourH;
  }

  int _toMin(String t) {
    final p = t.split(':');
    if (p.length < 2) return 0;
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  bool _overlaps(Appointment a, Appointment b) =>
      _toMin(a.oraInizio) < _toMin(b.oraFine) &&
      _toMin(a.oraFine)   > _toMin(b.oraInizio);

  Map<String, _SlotLayout> _computeLayout(List<Appointment> apts) {
    final result = <String, _SlotLayout>{};
    if (apts.isEmpty) return result;

    final sorted = [...apts]..sort((a, b) {
      final cmp = a.oraInizio.compareTo(b.oraInizio);
      return cmp != 0 ? cmp : b.oraFine.compareTo(a.oraFine);
    });

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
      if (n <= _kMaxVisible) {
        for (int i = 0; i < n; i++) {
          result[cluster[i].id ?? cluster[i].titolo] = _SlotLayout(
            colIndex: i, colCount: n,
            isOverflow: false, overflowCount: 0, overflowApts: [],
          );
        }
      } else {
        final visible  = cluster.sublist(0, _kMaxVisible - 1);
        final overflow = cluster.sublist(_kMaxVisible - 1);
        for (int i = 0; i < visible.length; i++) {
          result[visible[i].id ?? visible[i].titolo] = _SlotLayout(
            colIndex: i, colCount: _kMaxVisible,
            isOverflow: false, overflowCount: 0, overflowApts: [],
          );
        }
        result['__badge__${cluster.first.id ?? cluster.first.titolo}'] = _SlotLayout(
          colIndex: _kMaxVisible - 1,
          colCount: _kMaxVisible,
          isOverflow: true,
          overflowCount: overflow.length,
          overflowApts: overflow,
          clusterOraInizio: cluster.map((a) => a.oraInizio)
              .reduce((a, b) => _toMin(a) < _toMin(b) ? a : b),
          clusterOraFine: cluster.map((a) => a.oraFine)
              .reduce((a, b) => _toMin(a) > _toMin(b) ? a : b),
        );
      }
    }
    return result;
  }

  List<Appointment> _applyFilters(List<Appointment> apts) {
    return apts.where((a) {
      if (widget.filterUserId != null) {
        if (a.userId != widget.filterUserId &&
            !a.workerIds.contains(widget.filterUserId)) return false;
      }
      if (widget.filterRoomId   != null && a.roomId   != widget.filterRoomId)   return false;
      if (widget.filterClientId != null && a.clientId != widget.filterClientId) return false;
      return true;
    }).toList();
  }

  // ── CARD CALENDARIO ────────────────────────────────────────────────────────
  // Struttura: [titolo grassetto] → [paziente con icona] → [orario + icone stato]
  // Testo con shadow per staccarsi dallo sfondo striato multi-colore.
  Widget _aptContent({
    required Appointment apt,
    required double cardH,
    required int colCount,
    required Color rColor,
    required Room? room,
    required bool canSee,
    required String clienteNome,
  }) {
    final isShort  = cardH < 40.0;
    final isNarrow = colCount >= 3;
    final hasPaziente = canSee && clienteNome.isNotEmpty && clienteNome != apt.titolo;
    final hasIcons = canSee;
    final roomName = room?.name ?? '';

    return OverflowBox(
      alignment: Alignment.topLeft,
      maxHeight: double.infinity,
      maxWidth:  double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 4 : 6, 3,
          isNarrow ? 3 : 5, 3,
        ),
        child: isShort
            // ── CARD CORTA: tutto su una riga ──────────────────────────
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      apt.titolo,
                      style: TextStyle(
                          fontSize: isNarrow ? 9 : 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          shadows: _kTextShadow),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasPaziente) ...[
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        clienteNome,
                        style: TextStyle(
                            fontSize: isNarrow ? 8 : 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            shadows: _kTextShadow),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (hasIcons && !isNarrow) ...[
                    const SizedBox(width: 3),
                    if (apt.note != null && apt.note!.trim().isNotEmpty)
                      Icon(Icons.sticky_note_2, size: 9,
                          color: Colors.amber.shade800),
                    Icon(
                      apt.pagato
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 9,
                      color: apt.pagato
                          ? Colors.green.shade700
                          : Colors.black38),
                  ],
                ],
              )
            // ── CARD ALTA: layout verticale ────────────────────────────
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Titolo in grassetto
                  Text(
                    apt.titolo,
                    style: TextStyle(
                        fontSize: isNarrow ? 10 : 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1.2,
                        shadows: _kTextShadow),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 2. Paziente sotto il titolo
                  if (hasPaziente) ...[
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: isNarrow ? 8 : 9,
                            color: Colors.black54),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            clienteNome,
                            style: TextStyle(
                                fontSize: isNarrow ? 9 : 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                shadows: _kTextShadow),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // 3. Riga orario + icone stato
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isNarrow
                            ? apt.oraInizio
                            : '${apt.oraInizio}-${apt.oraFine}',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                            shadows: _kTextShadow),
                      ),
                      if (hasIcons) ...[
                        const SizedBox(width: 4),
                        if (apt.note != null && apt.note!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(Icons.sticky_note_2, size: 9,
                                color: Colors.amber.shade800),
                          ),
                        Icon(
                          apt.fatturato
                              ? Icons.receipt_long
                              : Icons.receipt_long_outlined,
                          size: 9,
                          color: apt.fatturato
                              ? Colors.orange.shade800
                              : Colors.black38),
                        const SizedBox(width: 2),
                        Icon(
                          apt.pagato
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 9,
                          color: apt.pagato
                              ? Colors.green.shade700
                              : Colors.black38),
                      ],
                    ],
                  ),
                  // 4. Stanza (solo se c'è spazio)
                  if (!isNarrow && canSee && room != null && cardH > 70) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room, size: 9, color: rColor),
                        const SizedBox(width: 3),
                        Text(
                          roomName,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: rColor,
                              shadows: _kTextShadow),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // ── BADGE OVERFLOW ─────────────────────────────────────────────────────────
  Widget _buildOverflowBadge({
    required _SlotLayout slot,
    required double cardH,
    required Color primary,
  }) {
    final colors = slot.overflowApts.map((a) => _uColor(a.userId)).toList();
    final count  = slot.overflowCount;

    return GestureDetector(
      onTap: () => _showOverflowSheet(slot.overflowApts, primary),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 3, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (cardH > 32)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...colors.take(4).map((c) => Container(
                          width: 7, height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                              color: c, shape: BoxShape.circle),
                        )),
                    if (colors.length > 4)
                      Container(
                        width: 7, height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
            Text('+$count',
                style: TextStyle(
                    fontSize: cardH > 32 ? 13 : 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700)),
            if (cardH > 40)
              Text('altro',
                  style: TextStyle(
                      fontSize: 9, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM SHEET CARD ──────────────────────────────────────────────────────
  Widget _sheetCard({
    required Appointment apt,
    required bool canSee,
    required String clienteNome,
    required List<Color> workerColors,
    required Color rColor,
    required Room? room,
    required VoidCallback onTap,
  }) {
    final hasNote = apt.note != null && apt.note!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: _StripePainter(
            colors: workerColors,
            stripeHeight: 10.0,
            opacity: 0.20,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0, bottom: 0, left: 0,
                width: 5,
                child: Container(color: rColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            apt.titolo,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (canSee &&
                              clienteNome.isNotEmpty &&
                              clienteNome != apt.titolo) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.person_outline,
                                  size: 11, color: Colors.black45),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  clienteNome,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ],
                          const SizedBox(height: 5),
                          Row(children: [
                            const Icon(Icons.access_time,
                                size: 11, color: Colors.black45),
                            const SizedBox(width: 3),
                            Text(
                              '${apt.oraInizio} - ${apt.oraFine}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                            if (room != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.meeting_room,
                                  size: 11, color: rColor),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  room.name,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: rColor,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ]),
                          if (canSee) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _sheetChip(
                                  icon: Icons.receipt_long,
                                  label: 'Fatturato',
                                  active: apt.fatturato,
                                  activeColor: Colors.orange.shade700,
                                ),
                                _sheetChip(
                                  icon: Icons.check_circle,
                                  label: 'Pagato',
                                  active: apt.pagato,
                                  activeColor: Colors.green.shade600,
                                ),
                                if (hasNote)
                                  _sheetChip(
                                    icon: Icons.sticky_note_2,
                                    label: 'Note',
                                    active: true,
                                    activeColor: Colors.amber.shade700,
                                  ),
                              ],
                            ),
                          ],
                          if (canSee && hasNote) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Text(
                                apt.note!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.brown.shade700,
                                    height: 1.4),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: Colors.black26, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BOTTOM SHEET ───────────────────────────────────────────────────────────
  void _showOverflowSheet(List<Appointment> apts, Color primary) {
    final me = Provider.of<AuthService>(context, listen: false).currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(children: [
                  Icon(Icons.event_note, color: primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Altri ${apts.length} appuntament${apts.length == 1 ? 'o' : 'i'}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  itemCount: apts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final apt          = apts[i];
                    final workerColors = _aptColors(apt);
                    final rColor       = _rColor(apt.roomId);
                    final room         = _rooms[apt.roomId];
                    final canSee       = apt.userId == me?.uid ||
                        apt.workerIds.contains(me?.uid) ||
                        (me?.isAdmin ?? false);
                    final clienteNome  = canSee ? _cName(apt.clientId) : '';
                    return _sheetCard(
                      apt: apt,
                      canSee: canSee,
                      clienteNome: clienteNome,
                      workerColors: workerColors,
                      rColor: rColor,
                      room: room,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTapAppointment(apt);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetChip({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: active ? activeColor.withOpacity(0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? activeColor.withOpacity(0.4) : Colors.grey.shade300,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10,
            color: active ? activeColor : Colors.grey.shade400),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : Colors.grey.shade400)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalH  = (_end - _start) * _hourH;
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
                      Text(_dn(d.weekday),
                          style: TextStyle(
                            fontSize: 10, letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
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
                        child: Text('${d.day}',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: today ? Colors.white : Colors.black87,
                            )),
                      ),
                    ],
                  ),
                );
              }),
            ]),

            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: totalH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      SizedBox(
                        width: _timeW, height: totalH,
                        child: Stack(
                          children: List.generate(_end - _start, (i) =>
                            Positioned(
                              top: i * _hourH - 8, right: 6,
                              child: Text(
                                '${(_start + i).toString().padLeft(2, '0')}:00',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ),
                      ),

                      ..._days.map((d) {
                        final today = _isToday(d);
                        final dayApts = _applyFilters(
                          allApts.where((a) =>
                              a.data.year  == d.year &&
                              a.data.month == d.month &&
                              a.data.day   == d.day).toList(),
                        );
                        final layout = _computeLayout(dayApts);

                        return SizedBox(
                          width: dw, height: totalH,
                          child: ClipRect(
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                ...List.generate(_end - _start, (i) =>
                                  Positioned(
                                    top: i * _hourH, left: 0, right: 0,
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
                                ...List.generate(_end - _start, (i) =>
                                  Positioned(
                                    top: i * _hourH + _hourH / 2,
                                    left: 4, right: 0, height: 1,
                                    child: Container(color: Colors.grey.shade100),
                                  ),
                                ),
                                ...List.generate(_end - _start, (i) =>
                                  Positioned(
                                    top: i * _hourH, left: 0, right: 0,
                                    height: _hourH,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () => widget.onTapSlot(
                                        DateTime(d.year, d.month, d.day, _start + i)),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                                if (today) _buildNowLine(),
                                ...dayApts.map((apt) {
                                  final key  = apt.id ?? apt.titolo;
                                  final slot = layout[key];
                                  if (slot == null) return const SizedBox.shrink();
                                  final topPx    = _topOf(apt.oraInizio).clamp(0.0, totalH - 1.0);
                                  final bottomPx = _topOf(apt.oraFine).clamp(topPx + 22.0, totalH);
                                  final cardH    = bottomPx - topPx;
                                  final colors   = _aptColors(apt);
                                  final uColor   = colors.first;
                                  final rColor   = _rColor(apt.roomId);
                                  final room     = _rooms[apt.roomId];
                                  final canSee   = apt.userId == me?.uid ||
                                      apt.workerIds.contains(me?.uid) ||
                                      (me?.isAdmin ?? false);
                                  final clienteNome = canSee ? _cName(apt.clientId) : '';
                                  const gap = 2.0;
                                  final colW = (dw - gap * (slot.colCount + 1)) / slot.colCount;
                                  final left = gap + slot.colIndex * (colW + gap);
                                  return Positioned(
                                    top: topPx, bottom: totalH - bottomPx,
                                    left: left, width: colW,
                                    child: GestureDetector(
                                      onTap: () => widget.onTapAppointment(apt),
                                      child: Container(
                                        clipBehavior: Clip.hardEdge,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: uColor.withOpacity(0.22),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Container(width: 4, color: rColor),
                                              Expanded(
                                                child: CustomPaint(
                                                  painter: _StripePainter(
                                                    colors: colors,
                                                    stripeHeight: 8.0,
                                                    opacity: 0.18,
                                                  ),
                                                  child: _aptContent(
                                                    apt: apt, cardH: cardH,
                                                    colCount: slot.colCount,
                                                    rColor: rColor, room: room,
                                                    canSee: canSee,
                                                    clienteNome: clienteNome,
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
                                ...layout.entries
                                    .where((e) => e.value.isOverflow)
                                    .map((e) {
                                  final slot     = e.value;
                                  final topPx    = _topOf(slot.clusterOraInizio).clamp(0.0, totalH - 1.0);
                                  final bottomPx = _topOf(slot.clusterOraFine).clamp(topPx + 22.0, totalH);
                                  final cardH    = bottomPx - topPx;
                                  const gap = 2.0;
                                  final colW = (dw - gap * (slot.colCount + 1)) / slot.colCount;
                                  final left = gap + slot.colIndex * (colW + gap);
                                  return Positioned(
                                    top: topPx, bottom: totalH - bottomPx,
                                    left: left, width: colW,
                                    child: _buildOverflowBadge(
                                      slot: slot, cardH: cardH, primary: primary),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ]);
        });
      },
    );
  }

  Widget _buildNowLine() {
    final n = DateTime.now();
    if (n.hour < _start || n.hour >= _end) return const SizedBox.shrink();
    final top = ((n.hour - _start) + n.minute / 60.0) * _hourH;
    return Positioned(
      top: top, left: 0, right: 0,
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: Colors.redAccent, shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 4),
            ],
          ),
        ),
        Expanded(child: Container(
            height: 1.5, color: Colors.redAccent.withOpacity(0.6))),
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

// ── SLOT LAYOUT DATA ───────────────────────────────────────────────────────
class _SlotLayout {
  final int  colIndex;
  final int  colCount;
  final bool isOverflow;
  final int  overflowCount;
  final List<Appointment> overflowApts;
  final String clusterOraInizio;
  final String clusterOraFine;

  const _SlotLayout({
    required this.colIndex,
    required this.colCount,
    required this.isOverflow,
    required this.overflowCount,
    required this.overflowApts,
    this.clusterOraInizio = '',
    this.clusterOraFine   = '',
  });
}

// ── STRIPE PAINTER ─────────────────────────────────────────────────────────
class _StripePainter extends CustomPainter {
  final List<Color> colors;
  final double stripeHeight;
  final double opacity;

  const _StripePainter({
    required this.colors,
    this.stripeHeight = 8.0,
    this.opacity = 0.18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    if (colors.length == 1) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = colors.first.withOpacity(opacity),
      );
      return;
    }
    double y = 0;
    int idx = 0;
    while (y < size.height) {
      final h = (y + stripeHeight > size.height) ? size.height - y : stripeHeight;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, h),
        Paint()..color = colors[idx % colors.length].withOpacity(opacity),
      );
      y += stripeHeight;
      idx++;
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.colors != colors ||
      old.stripeHeight != stripeHeight ||
      old.opacity != opacity;
}
