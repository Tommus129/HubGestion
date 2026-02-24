import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../models/appointment.dart';
import '../widgets/app_drawer.dart';
import 'appointment_form_screen.dart';
import 'appointment_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AppointmentService _service = AppointmentService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Appointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Appointment> _getEventsForDay(DateTime day) {
    return _appointments.where((apt) =>
      apt.data.year == day.year &&
      apt.data.month == day.month &&
      apt.data.day == day.day
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendario'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(),
      body: StreamBuilder<List<Appointment>>(
        stream: _service.getAppointments(
          DateTime(_focusedDay.year, _focusedDay.month - 1, 1),
          DateTime(_focusedDay.year, _focusedDay.month + 2, 0),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) _appointments = snapshot.data!;
          return Column(
            children: [
              TableCalendar<Appointment>(
                firstDay: DateTime(2024),
                lastDay: DateTime(2028),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getEventsForDay,
                onDaySelected: (selected, focused) {
                  setState(() { _selectedDay = selected; _focusedDay = focused; });
                },
                onFormatChanged: (f) => setState(() => _calendarFormat = f),
                onPageChanged: (f) => setState(() => _focusedDay = f),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: Colors.teal.withOpacity(0.4), shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(color: Colors.teal[700], shape: BoxShape.circle),
                ),
                headerStyle: HeaderStyle(
                  formatButtonDecoration: BoxDecoration(
                    border: Border.all(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  formatButtonTextStyle: TextStyle(color: Colors.teal),
                ),
              ),
              Divider(height: 1),
              Expanded(child: _buildEventList()),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AppointmentFormScreen(selectedDay: _selectedDay ?? DateTime.now()),
        )),
        backgroundColor: Colors.teal,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Nuovo', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
            SizedBox(height: 8),
            Text('Nessun appuntamento', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final apt = events[i];
        final oraLabel = apt.oraInizio.isNotEmpty ? apt.oraInizio : '--:--';
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AppointmentDetailScreen(appointment: apt),
            )),
            leading: CircleAvatar(
              backgroundColor: Colors.teal,
              child: Text(
                oraLabel.length >= 2 ? oraLabel.substring(0, 2) : oraLabel,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(apt.titolo, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${apt.oraInizio} - ${apt.oraFine}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (apt.fatturato) Icon(Icons.receipt, color: Colors.orange, size: 16),
                if (apt.pagato) Icon(Icons.check_circle, color: Colors.green, size: 16),
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}
