import 'package:flutter/material.dart';
import '../models/appointment.dart';
import 'package:intl/intl.dart';

/// Tile ottimizzata per gli appuntamenti.
/// Usa [const] costruttori dove possibile per ridurre i rebuild.
class AppointmentListTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const AppointmentListTile({
    super.key,
    required this.appointment,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        DateFormat('EEE d MMM', 'it').format(appointment.data);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          appointment.titolo,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$dateStr  •  ${appointment.oraInizio}–${appointment.oraFine}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (appointment.pagato)
              const Icon(Icons.check_circle,
                  color: Colors.green, size: 18)
            else
              const Icon(Icons.radio_button_unchecked,
                  color: Colors.orange, size: 18),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
