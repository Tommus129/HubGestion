import 'package:flutter/material.dart';

class TimePicker24h extends StatefulWidget {
  final TimeOfDay initialTime;
  final String label;
  final Function(TimeOfDay) onChanged;

  const TimePicker24h({
    super.key,
    required this.initialTime,
    required this.label,
    required this.onChanged,
  });

  @override
  State<TimePicker24h> createState() => _TimePicker24hState();
}

class _TimePicker24hState extends State<TimePicker24h> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  @override
  void didUpdateWidget(TimePicker24h old) {
    super.didUpdateWidget(old);
    if (old.initialTime != widget.initialTime) {
      setState(() {
        _hour = widget.initialTime.hour;
        _minute = widget.initialTime.minute;
      });
    }
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  void _emit() => widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));

  void _showPicker(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    int tmpH = _hour;
    int tmpM = _minute;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(widget.label,
              style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DISPLAY ORARIO
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${_pad(tmpH)} : ${_pad(tmpM)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: primary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),

                // ORE
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ora',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600])),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(24, (h) {
                    final sel = tmpH == h;
                    return GestureDetector(
                      onTap: () => setS(() => tmpH = h),
                      child: Container(
                        width: 40,
                        height: 36,
                        decoration: BoxDecoration(
                          color: sel ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: sel ? primary : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _pad(h),
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.grey[700],
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 14),

                // MINUTI
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Minuti',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600])),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
                      .map((m) {
                    final sel = tmpM == m;
                    return GestureDetector(
                      onTap: () => setS(() => tmpM = m),
                      child: Container(
                        width: 44,
                        height: 36,
                        decoration: BoxDecoration(
                          color: sel ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: sel ? primary : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _pad(m),
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.grey[700],
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hour = tmpH;
                  _minute = tmpM;
                });
                _emit();
                Navigator.pop(context);
              },
              child: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _showPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 16, color: primary),
                const SizedBox(width: 6),
                Text(
                  '${_pad(_hour)} : ${_pad(_minute)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
