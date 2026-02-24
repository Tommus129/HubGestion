import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimePicker24h extends StatefulWidget {
  final TimeOfDay initialTime;
  final String label;
  final Function(TimeOfDay) onChanged;

  TimePicker24h({required this.initialTime, required this.label, required this.onChanged});

  @override
  _TimePicker24hState createState() => _TimePicker24hState();
}

class _TimePicker24hState extends State<TimePicker24h> {
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = TextEditingController(text: _pad(_hour));
    _minuteController = TextEditingController(text: _pad(_minute));
  }

  @override
  void didUpdateWidget(TimePicker24h oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _hour = widget.initialTime.hour;
      _minute = widget.initialTime.minute;
      _hourController.text = _pad(_hour);
      _minuteController.text = _pad(_minute);
    }
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  void _emit() {
    widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ORE
              SizedBox(
                width: 36,
                child: TextField(
                  controller: _hourController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary),
                  onChanged: (v) {
                    int? h = int.tryParse(v);
                    if (h != null && h >= 0 && h <= 23) {
                      _hour = h;
                      _emit();
                    }
                  },
                  onTap: () => _hourController.selection = TextSelection(
                      baseOffset: 0, extentOffset: _hourController.text.length),
                ),
              ),
              Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: primary)),
              // MINUTI
              SizedBox(
                width: 36,
                child: TextField(
                  controller: _minuteController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary),
                  onChanged: (v) {
                    int? m = int.tryParse(v);
                    if (m != null && m >= 0 && m <= 59) {
                      _minute = m;
                      _emit();
                    }
                  },
                  onTap: () => _minuteController.selection = TextSelection(
                      baseOffset: 0, extentOffset: _minuteController.text.length),
                ),
              ),
              // FRECCE SU/GIU minuti
              Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _minute = (_minute + 5) % 60;
                        _minuteController.text = _pad(_minute);
                      });
                      _emit();
                    },
                    child: Icon(Icons.keyboard_arrow_up, size: 18, color: Colors.grey[500]),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _minute = (_minute - 5 + 60) % 60;
                        _minuteController.text = _pad(_minute);
                      });
                      _emit();
                    },
                    child: Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }
}
