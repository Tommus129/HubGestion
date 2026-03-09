import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../widgets/app_drawer.dart';

class OverdueReportScreen extends StatefulWidget {
  @override
  _OverdueReportScreenState createState() => _OverdueReportScreenState();
}

class _OverdueReportScreenState extends State<OverdueReportScreen> {
  final AppointmentService _aptService = AppointmentService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Appointment> _insoluti = [];
  bool _loading = true;
  Map<String, String> _clientNames = {};
  Map<String, String> _userNames = {};

  // Filtri
  String _filtro = 'non_pagato';   // 'non_pagato' | 'non_fatturato' | 'entrambi'
  String _periodo = 'sempre';      // 'mese' | 'anno' | 'sempre'
  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    // Carica nomi
    final users   = await _db.collection('users').get();
    final clients = await _db.collection('clients').get();
    _userNames = {
      for (final d in users.docs)
        d.id: (d.data()['displayName']?.toString().isNotEmpty == true
            ? d.data()['displayName'] : d.data()['email']) ?? d.id
    };
    _clientNames = {
      for (final d in clients.docs)
        d.id: '${d.data()['nome'] ?? ''} ${d.data()['cognome'] ?? ''}'.trim()
    };

    // Range date
    DateTime start, end;
    switch (_periodo) {
      case 'mese':
        start = DateTime(_now.year, _now.month, 1);
        end   = DateTime(_now.year, _now.month + 1, 0);
        break;
      case 'anno':
        start = DateTime(_now.year, 1, 1);
        end   = DateTime(_now.year, 12, 31);
        break;
      default:
        start = DateTime(2020);
        end   = DateTime(2030);
    }

    _aptService.getAppointments(start, end).listen((apts) {
      setState(() {
        _insoluti = apts.where((a) {
          switch (_filtro) {
            case 'non_pagato':     return !a.pagato;
            case 'non_fatturato':  return !a.fatturato;
            case 'entrambi':       return !a.pagato && !a.fatturato;
            default:               return true;
          }
        }).toList()
          ..sort((a, b) => a.data.compareTo(b.data));
        _loading = false;
      });
    });
  }

  double get _totaleInsoluto =>
      _insoluti.fold(0.0, (s, a) => s + a.totale);

  String _formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  String _formatCurrency(double v) =>
      NumberFormat.currency(locale: 'it_IT', symbol: 'EUR ').format(v);

  // ── GENERA PDF ─────────────────────────────────────────────
  Future<void> _generatePdf() async {
    // Font con pieno supporto Unicode (€, •, –, ecc.)
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();

    final styleBase = pw.TextStyle(font: fontRegular, fontSize: 9);
    final styleBold = pw.TextStyle(font: fontBold, fontSize: 9);

    final doc = pw.Document();
    final labelFiltro = _filtro == 'non_pagato'
        ? 'Non pagati'
        : _filtro == 'non_fatturato'
            ? 'Non fatturati'
            : 'Non pagati e non fatturati';
    final labelPeriodo = _periodo == 'mese'
        ? 'Mese corrente'
        : _periodo == 'anno' ? 'Anno corrente' : 'Tutto il periodo';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Report Insoluti',
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 22)),
                    pw.SizedBox(height: 4),
                    pw.Text('$labelFiltro  -  $labelPeriodo',
                        style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 11,
                            color: PdfColors.grey600)),
                  ],
                ),
                pw.Text(
                  'Generato il ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            // Riepilogo
            pw.Container(
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.red200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Totale insoluto: ${_formatCurrency(_totaleInsoluto)}',
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 13,
                          color: PdfColors.red800)),
                  pw.Text('${_insoluti.length} appuntamenti',
                      style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 11,
                          color: PdfColors.red600)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (ctx) => [
          // Tabella
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey300),
              top: pw.BorderSide(color: PdfColors.grey300),
            ),
            columnWidths: {
              0: pw.FlexColumnWidth(2.2),  // Titolo
              1: pw.FlexColumnWidth(1.4),  // Cliente
              2: pw.FlexColumnWidth(1.2),  // Data
              3: pw.FlexColumnWidth(1.0),  // Orario
              4: pw.FlexColumnWidth(0.8),  // F
              5: pw.FlexColumnWidth(0.8),  // P
              6: pw.FlexColumnWidth(1.0),  // Importo
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  'Titolo', 'Cliente', 'Data', 'Orario', 'Fatt.', 'Pag.', 'Importo'
                ].map((h) => pw.Padding(
                  padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Text(h, style: styleBold.copyWith(color: PdfColors.grey700)),
                )).toList(),
              ),
              // Righe
              ..._insoluti.map((a) {
                final clienteNome = _clientNames[a.clientId] ?? a.clientId;
                final fStr = a.fatturato ? 'Si' : 'No';
                final pStr = a.pagato ? 'Si' : 'No';
                return pw.TableRow(
                  children: [
                    _cell(a.titolo, styleBase),
                    _cell(clienteNome, styleBase),
                    _cell(_formatDate(a.data), styleBase),
                    _cell('${a.oraInizio}-${a.oraFine}', styleBase),
                    _cellColored(fStr, a.fatturato ? PdfColors.green700 : PdfColors.red600, fontBold),
                    _cellColored(pStr, a.pagato ? PdfColors.green700 : PdfColors.red600, fontBold),
                    _cell(_formatCurrency(a.totale), styleBold),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),
          // Totale fine
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey900,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'TOTALE  ${_formatCurrency(_totaleInsoluto)}',
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 13,
                    color: PdfColors.white),
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (fmt) async => doc.save(),
      name: 'insoluti_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _cell(String text, pw.TextStyle style) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(text, style: style, maxLines: 2),
  );

  pw.Widget _cellColored(String text, PdfColor color, pw.Font font) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(text,
        style: pw.TextStyle(font: font, fontSize: 9, color: color)),
  );

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Insoluti'),
        actions: [
          if (!_loading && _insoluti.isNotEmpty)
            IconButton(
              icon: Icon(Icons.picture_as_pdf),
              tooltip: 'Esporta PDF',
              onPressed: _generatePdf,
            ),
        ],
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [
          // FILTRI
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Periodo
                Text('Periodo', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                SizedBox(height: 6),
                Row(children: ['mese', 'anno', 'sempre'].map((p) {
                  final active = _periodo == p;
                  final label = p == 'mese' ? 'Mese corrente' : p == 'anno' ? 'Anno corrente' : 'Tutto';
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () { setState(() => _periodo = p); _loadAll(); },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? primary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: active ? primary : Colors.grey.shade300),
                          ),
                          child: Center(child: Text(label, style: TextStyle(
                            fontSize: 12,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            color: active ? Colors.white : Colors.grey[700],
                          ))),
                        ),
                      ),
                    ),
                  );
                }).toList()),
                SizedBox(height: 12),
                // Tipo insoluto
                Text('Tipo insoluto', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                SizedBox(height: 6),
                Row(children: [
                  _filtroBtn('non_pagato', 'Non pagati', Icons.money_off, Colors.red),
                  SizedBox(width: 8),
                  _filtroBtn('non_fatturato', 'Non fatturati', Icons.receipt_long, Colors.orange),
                  SizedBox(width: 8),
                  _filtroBtn('entrambi', 'Entrambi', Icons.warning_amber, Colors.deepOrange),
                ]),
              ],
            ),
          ),

          // SUMMARY BOX
          if (!_loading)
            Container(
              margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Totale insoluto', style: TextStyle(fontSize: 11, color: Colors.red[400])),
                    Text(_formatCurrency(_totaleInsoluto),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red[700])),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${_insoluti.length} appuntamenti',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red[600])),
                    SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: _insoluti.isEmpty ? null : _generatePdf,
                      icon: Icon(Icons.picture_as_pdf, size: 16),
                      label: Text('Esporta PDF', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ]),
                ],
              ),
            ),

          SizedBox(height: 8),

          // LISTA
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _insoluti.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[200]),
                          SizedBox(height: 12),
                          Text('Nessun insoluto! :)',
                              style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                        ],
                      ))
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _insoluti.length,
                        itemBuilder: (_, i) => _insolutiCard(_insoluti[i], primary),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filtroBtn(String val, String label, IconData icon, Color color) {
    final active = _filtro == val;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _filtro = val); _loadAll(); },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color : Colors.grey.shade300, width: active ? 1.5 : 1.0),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: active ? color : Colors.grey[400]),
            SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? color : Colors.grey[600],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _insolutiCard(Appointment apt, Color primary) {
    final clienteNome = _clientNames[apt.clientId] ?? apt.clientId;
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color:
            !apt.pagato && !apt.fatturato ? Colors.red.shade200 :
            !apt.pagato ? Colors.red.shade100 : Colors.orange.shade100),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // Indicatore colorato sinistra
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: !apt.pagato && !apt.fatturato ? Colors.red :
                       !apt.pagato ? Colors.red[300]! : Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(apt.titolo,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(_formatCurrency(apt.totale),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red[700])),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.person_outline, size: 12, color: Colors.grey[400]),
                    SizedBox(width: 4),
                    Text(clienteNome, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    SizedBox(width: 10),
                    Icon(Icons.calendar_today, size: 11, color: Colors.grey[400]),
                    SizedBox(width: 4),
                    Text('${_formatDate(apt.data)}  ${apt.oraInizio}-${apt.oraFine}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  SizedBox(height: 6),
                  Row(children: [
                    _badge(apt.fatturato ? 'Fatturato' : 'Non fatturato',
                        apt.fatturato ? Colors.green : Colors.orange),
                    SizedBox(width: 6),
                    _badge(apt.pagato ? 'Pagato' : 'Non pagato',
                        apt.pagato ? Colors.green : Colors.red),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}
