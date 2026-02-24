import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/app_drawer.dart';
import '../services/auth_service.dart';
import '../models/appointment.dart';
import 'appointment_form_screen.dart';
import 'appointment_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedWeek = DateTime.now();

  void _previousWeek() => setState(() =>
      _focusedWeek = _focusedWeek.subtract(Duration(days: 7)));

  void _nextWeek() => setState(() =>
      _focusedWeek = _focusedWeek.add(Duration(days: 7)));

  void _goToday() => setState(() => _focusedWeek = DateTime.now());

  String _weekLabel() {
    final monday = _focusedWeek.subtract(
        Duration(days: _focusedWeek.weekday - 1));
    final sunday = monday.add(Duration(days: 6));
    if (monday.month == sunday.month) {
      return '${monday.day} - ${sunday.day} ${_monthName(monday.month)} ${monday.year}';
    }
    return '${monday.day} ${_monthName(monday.month)} - ${sunday.day} ${_monthName(sunday.month)} ${monday.year}';
  }

  String _monthName(int m) {
    const months = ['Gen','Feb','Mar','Apr','Mag','Giu','Lug','Ago','Set','Ott','Nov','Dic'];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendario'),
        actions: [
          IconButton(
            icon: Icon(Icons.today),
            tooltip: 'Oggi',
            onPressed: _goToday,
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [
          // NAVIGAZIONE SETTIMANA
          Container(
            color: theme.colorScheme.primary.withOpacity(0.05),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: _previousWeek,
                  color: theme.colorScheme.primary,
                ),
                Text(
                  _weekLabel(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: _nextWeek,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),

          // CALENDARIO SETTIMANALE
          Expanded(
            child: WeeklyCalendar(
              focusedWeek: _focusedWeek,
              onTapAppointment: (apt) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailScreen(appointment: apt),
                ),
              ),
              onTapSlot: (dateTime) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentFormScreen(
                    selectedDay: dateTime,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentFormScreen(selectedDay: DateTime.now()),
          ),
        ),
        icon: Icon(Icons.add),
        label: Text('Nuovo'),
      ),
    );
  }
}
