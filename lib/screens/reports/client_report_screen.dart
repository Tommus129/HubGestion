import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/appointment.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../utils/date_helpers.dart';

import 'dart:html' as html;

class ClientReportScreen extends StatefulWidget {
  @override
  _ClientReportScreenState createState() => _ClientReportScreenState();
}

class _ClientReportScreenState extends State<ClientReportScreen> {
  final ClientService _clientService = ClientService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Client? _selectedClient;
  String _periodoType = 'mese';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear  = DateTime.now().year;
  DateTime? _customFrom;
  DateTime? _customTo;
  String _filtroFatturato = 'tutti';
  String _filtroPageto    = 'tutti';
  String? _filtroLavoratore; // null = tutti

  String _pdfFiltro = 'mese';

  List<Client> _clients = [];
  List<Appointment> _allFetched = [];
  List<Appointment> _appointments = [];
  Map<String, String> _userNames = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _clientService.getClients().listen((c) => setState(() => _clients = c));
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    final snap = await _db.collection('users').get();
    setState(() {
      _userNames = {
        for (final d in snap.docs)
          d.id: (d.data()['displayName']?.toString().isNotEmpty == true
              ? d.data()['displayName']
              : d.data()['email']) ?? d.id
      };
    });
  }

  Future<void> _autoSearch() async {
    if (_selectedClient == null) return;
    if (_periodoType == 'custom' && (_customFrom == null || _customTo == null)) return;
    setState(() { _loading = true; _appointments = []; _allFetched = []; });
    try {
      final snap = await _db
          .collection('appointments')
          .where('clientId', isEqualTo: _selectedClient!.id)
          .get();
      final all = snap.docs.map((d) {
        try { return Appointment.fromFirestore(d); } catch (_) { return null; }
      }).whereType<Appointment>().toList()
        ..sort((a, b) => a.data.compareTo(b.data));
      setState(() { _allFetched = all; });
      _applyLocalFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    }
  }

  void _applyLocalFilters() {
    DateTime start;
    DateTime end;
    switch (_periodoType) {
      case 'mese':
        start = DateTime(_selectedYear, _selectedMonth, 1);
        end   = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
        break;
      case 'anno':
        start = DateTime(_selectedYear, 1, 1);
        end   = DateTime(_selectedYear, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        if (_customFrom == null || _customTo == null) return;
        start = _customFrom!;
        end   = DateTime(_customTo!.year, _customTo!.month, _customTo!.day, 23, 59, 59);
        break;
      default:
        start = DateTime(2000); end = DateTime(2099);
    }
    List<Appointment> f = _allFetched.where((a) {
      if (a.deleted == true) return false;
      if (a.data.isBefore(start) || a.data.isAfter(end)) return false;
      return true;
    }).toList();
    if (_filtroFatturato == 'si') f = f.where((a) => a.fatturato).toList();
    if (_filtroFatturato == 'no') f = f.where((a) => !a.fatturato).toList();
    if (_filtroPageto    == 'si') f = f.where((a) => a.pagato).toList();
    if (_filtroPageto    == 'no') f = f.where((a) => !a.pagato).toList();
    // Filtro lavoratore
    if (_filtroLavoratore != null) {
      f = f.where((a) =>
          a.userId == _filtroLavoratore ||
          (a.workerIds?.contains(_filtroLavoratore) ?? false)).toList();
    }
    setState(() { _appointments = f; _loading = false; });
  }

  // Lavoratori presenti negli appuntamenti caricati
  List<MapEntry<String, String>> get _lavoratoriDisponibili {
    final ids = <String>{};
    for (final a in _allFetched) {
      if (a.userId.isNotEmpty) ids.add(a.userId);
      a.workerIds?.forEach(ids.add);
    }
    return ids
        .map((id) => MapEntry(id, _userNames[id] ?? id))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  double get _totGuadagno => _appointments.fold(0, (s, a) => s + a.totale);
  double get _totPagato   => _appointments.where((a) => a.pagato).fold(0, (s, a) => s + a.totale);
  double get _totNonFatt  => _appointments.where((a) => !a.fatturato).fold(0, (s, a) => s + a.totale);
  double get _totOre      => _appointments.fold(0, (s, a) => s + a.oreTotali);

  String _formatCurrency(double v) =>
      NumberFormat.currency(locale: 'it_IT', symbol: 'EUR ').format(v);

  (DateTime, DateTime, String) _pdfRange() {
    final now = DateTime.now();
    switch (_pdfFiltro) {
      case 'settimana':
        final lunedi = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(lunedi.year, lunedi.month, lunedi.day);
        final end   = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        final label = 'Settimana ${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';
        return (start, end, label);
      case 'mese':
        final start = DateTime(now.year, now.month, 1);
        final end   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        final label = '${_monthName(now.month)} ${now.year}';
        return (start, end, label);
      default:
        return (DateTime(2000), DateTime(2099), 'Tutti i periodi');
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedClient == null) return;

    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();

    final (start, end, periodoLabel) = _pdfRange();

    // Applica anche il filtro lavoratore al PDF
    List<Appointment> pdfData = _allFetched.where((a) {
      if (a.deleted == true) return false;
      if (a.fatturato == true) return false;
      if (a.data.isBefore(start) || a.data.isAfter(end)) return false;
      return true;
    }).toList();
    if (_filtroLavoratore != null) {
      pdfData = pdfData.where((a) =>
          a.userId == _filtroLavoratore ||
          (a.workerIds?.contains(_filtroLavoratore) ?? false)).toList();
    }
    pdfData.sort((a, b) => a.data.compareTo(b.data));

    if (pdfData.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nessun appuntamento non fatturato in "$periodoLabel"'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final clienteNome   = _selectedClient!.fullName;
    final dataOggi      = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final totaleImporto = pdfData.fold(0.0, (s, a) => s + a.totale);
    final totPagato     = pdfData.where((a) => a.pagato).fold(0.0, (s, a) => s + a.totale);
    final totNonPagato  = totaleImporto - totPagato;
    final lavoratoreLabel = _filtroLavoratore != null
        ? (_userNames[_filtroLavoratore] ?? _filtroLavoratore!)
        : 'Tutti i lavoratori';

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PAGAMENTI NON FATTURATI',
                  style: pw.TextStyle(font: fontBold, fontSize: 22)),
              pw.SizedBox(height: 6),
              pw.Container(width: double.infinity, height: 3, color: PdfColors.teal600),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Cliente',
                          style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
                      pw.SizedBox(height: 3),
                      pw.Text(clienteNome,
                          style: pw.TextStyle(font: fontBold, fontSize: 14)),
                      pw.SizedBox(height: 10),
                      pw.Text('Periodo',
                          style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
                      pw.SizedBox(height: 3),
                      pw.Text(periodoLabel,
                          style: pw.TextStyle(font: fontRegular, fontSize: 12)),
                      pw.SizedBox(height: 10),
                      pw.Text('Lavoratore',
                          style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
                      pw.SizedBox(height: 3),
                      pw.Text(lavoratoreLabel,
                          style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Data generazione',
                          style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
                      pw.SizedBox(height: 3),
                      pw.Text(dataOggi,
                          style: pw.TextStyle(font: fontRegular, fontSize: 12)),
                      pw.SizedBox(height: 10),
                      pw.Text('N. appuntamenti',
                          style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
                      pw.SizedBox(height: 3),
                      pw.Text('${pdfData.length}',
                          style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
            ],
          ),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(0.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildHeaderCell('Data', fontBold),
                  _buildHeaderCell('Descrizione', fontBold),
                  _buildHeaderCell('Ore', fontBold, align: pw.TextAlign.center),
                  _buildHeaderCell('Tariffa', fontBold, align: pw.TextAlign.right),
                  _buildHeaderCell('Importo', fontBold, align: pw.TextAlign.right),
                  _buildHeaderCell('Pagato', fontBold, align: pw.TextAlign.center),
                ],
              ),
              ...pdfData.map((a) {
                final persona = _userNames[a.userId] ?? '';
                final descrizione = a.titolo + (persona.isNotEmpty ? ' ($persona)' : '');
                return pw.TableRow(
                  children: [
                    _buildDataCell(
                      '${DateFormat('dd/MM/yy').format(a.data)}\n${a.oraInizio}-${a.oraFine}',
                      fontRegular,
                    ),
                    _buildDataCell(descrizione, fontRegular),
                    _buildDataCell(a.oreTotali.toStringAsFixed(1), fontRegular, align: pw.TextAlign.center),
                    _buildDataCell('EUR ${a.tariffa.toStringAsFixed(0)}', fontRegular, align: pw.TextAlign.right),
                    _buildDataCell('EUR ${a.totale.toStringAsFixed(2)}', fontBold, align: pw.TextAlign.right),
                    _buildDataCell(
                      a.pagato ? 'SI' : 'NO',
                      fontBold,
                      align: pw.TextAlign.center,
                      color: a.pagato ? PdfColors.green700 : PdfColors.red700,
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 280,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.grey50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildTotalRow('Totale importo:', 'EUR ${totaleImporto.toStringAsFixed(2)}', fontRegular, fontRegular),
                  pw.SizedBox(height: 6),
                  pw.Divider(color: PdfColors.grey300, height: 1),
                  pw.SizedBox(height: 6),
                  _buildTotalRow('Gia pagato:', 'EUR ${totPagato.toStringAsFixed(2)}', fontRegular, fontRegular,
                      valueColor: PdfColors.green700),
                  pw.SizedBox(height: 4),
                  _buildTotalRow('Non pagato:', 'EUR ${totNonPagato.toStringAsFixed(2)}', fontRegular, fontRegular,
                      valueColor: PdfColors.red700),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: PdfColors.grey400, height: 2),
                  pw.SizedBox(height: 10),
                  _buildTotalRow(
                    'DA FATTURARE:',
                    'EUR ${totaleImporto.toStringAsFixed(2)}',
                    fontBold,
                    fontBold,
                    labelSize: 11,
                    valueSize: 14,
                    valueColor: PdfColors.teal700,
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Text(
            'Documento generato automaticamente da HubGestion',
            style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    final Uint8List bytes = await doc.save();
    final safeName = clienteNome.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    final fileName = 'non_fatturati_${safeName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF scaricato: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  pw.Widget _buildHeaderCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10), textAlign: align),
    );
  }

  pw.Widget _buildDataCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(font: font, fontSize: 9, color: color ?? PdfColors.black),
          textAlign: align, maxLines: 3),
    );
  }

  pw.Widget _buildTotalRow(String label, String value, pw.Font labelFont, pw.Font valueFont,
      {double labelSize = 10, double valueSize = 10, PdfColor? valueColor}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: labelSize)),
        pw.Text(value, style: pw.TextStyle(font: valueFont, fontSize: valueSize, color: valueColor ?? PdfColors.black)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth    = Provider.of<AuthService>(context);
    final isAdmin = auth.currentUser?.isAdmin ?? false;
    final hasDati = _allFetched.isNotEmpty;
    final lavoratori = _lavoratoriDisponibili;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Cliente'),
        actions: [
          if (_selectedClient != null && hasDati)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Esporta PDF non fatturati',
              onPressed: _generatePdf,
            ),
        ],
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Cliente
                DropdownButtonFormField<Client>(
                  value: _selectedClient,
                  decoration: InputDecoration(
                    labelText: 'Cliente',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: _clients.map((c) => DropdownMenuItem(value: c, child: Text(c.fullName))).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedClient = v;
                      _appointments = [];
                      _allFetched = [];
                      _filtroLavoratore = null; // reset filtro
                    });
                    _autoSearch();
                  },
                  hint: const Text('Seleziona cliente'),
                ),
                const SizedBox(height: 10),

                // Filtro lavoratore (visibile solo se ci sono appuntamenti)
                if (hasDati) ...[
                  DropdownButtonFormField<String?>(
                    value: _filtroLavoratore,
                    decoration: InputDecoration(
                      labelText: 'Lavoratore',
                      prefixIcon: const Icon(Icons.person_pin_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tutti i lavoratori'),
                      ),
                      ...lavoratori.map((e) => DropdownMenuItem<String?>(
                        value: e.key,
                        child: Text(e.value),
                      )),
                    ],
                    onChanged: (v) {
                      setState(() => _filtroLavoratore = v);
                      _applyLocalFilters();
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Periodo chips
                Row(
                  children: [
                    _periodoChip('mese',   'Mese',   primary),
                    const SizedBox(width: 6),
                    _periodoChip('anno',   'Anno',   primary),
                    const SizedBox(width: 6),
                    _periodoChip('sempre', 'Sempre', primary),
                    const SizedBox(width: 6),
                    _periodoChip('custom', 'Custom', primary),
                  ],
                ),
                const SizedBox(height: 8),

                if (_periodoType == 'mese')
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int>(
                        value: _selectedMonth,
                        isDense: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        ),
                        items: List.generate(12, (i) => DropdownMenuItem(
                            value: i + 1, child: Text(_monthName(i + 1), overflow: TextOverflow.ellipsis))),
                        onChanged: (v) { setState(() => _selectedMonth = v!); _applyLocalFilters(); },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: _selectedYear,
                        isDense: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        ),
                        items: List.generate(8, (i) => DropdownMenuItem(
                            value: 2024 + i, child: Text('${2024 + i}'))),
                        onChanged: (v) { setState(() => _selectedYear = v!); _applyLocalFilters(); },
                      ),
                    ),
                  ]),

                if (_periodoType == 'anno')
                  Row(children: [
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<int>(
                        value: _selectedYear,
                        isDense: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        ),
                        items: List.generate(8, (i) => DropdownMenuItem(
                            value: 2024 + i, child: Text('${2024 + i}'))),
                        onChanged: (v) { setState(() => _selectedYear = v!); _applyLocalFilters(); },
                      ),
                    ),
                  ]),

                if (_periodoType == 'custom')
                  Row(children: [
                    Expanded(child: _datePicker('Dal', _customFrom, (d) {
                      setState(() => _customFrom = d); _applyLocalFilters();
                    }, primary)),
                    const SizedBox(width: 8),
                    Expanded(child: _datePicker('Al', _customTo, (d) {
                      setState(() => _customTo = d); _applyLocalFilters();
                    }, primary)),
                  ]),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 6, runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Fatturato:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    _segBtn('tutti', 'Tutti', _filtroFatturato, (v) { setState(() => _filtroFatturato = v); _applyLocalFilters(); }, primary),
                    _segBtn('si', 'Si', _filtroFatturato, (v) { setState(() => _filtroFatturato = v); _applyLocalFilters(); }, primary),
                    _segBtn('no', 'No', _filtroFatturato, (v) { setState(() => _filtroFatturato = v); _applyLocalFilters(); }, primary),
                    const SizedBox(width: 8),
                    Text('Pagato:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    _segBtn('tutti', 'Tutti', _filtroPageto, (v) { setState(() => _filtroPageto = v); _applyLocalFilters(); }, primary),
                    _segBtn('si', 'Si', _filtroPageto, (v) { setState(() => _filtroPageto = v); _applyLocalFilters(); }, primary),
                    _segBtn('no', 'No', _filtroPageto, (v) { setState(() => _filtroPageto = v); _applyLocalFilters(); }, primary),
                  ],
                ),

                if (_selectedClient != null && hasDati) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 15, color: Colors.deepOrange[400]),
                      const SizedBox(width: 6),
                      Text('PDF non fatturati:',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      _pdfChip('settimana', 'Settimana'),
                      const SizedBox(width: 6),
                      _pdfChip('mese', 'Mese'),
                      const SizedBox(width: 6),
                      _pdfChip('tutti', 'Tutti'),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          if (!_loading && _appointments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _metricBox('Ore totali', '${_totOre.toStringAsFixed(1)}h',
                      Icons.schedule, primary, _totPagato, _totGuadagno),
                  const SizedBox(width: 8),
                  _metricBox('Totale', DateHelpers.formatCurrency(_totGuadagno),
                      Icons.euro_rounded, Colors.blueGrey, _totGuadagno, _totGuadagno),
                  const SizedBox(width: 8),
                  _metricBox('Incassato', DateHelpers.formatCurrency(_totPagato),
                      Icons.check_circle_outline, Colors.green, _totPagato, _totGuadagno),
                  const SizedBox(width: 8),
                  _metricBox('Non fatt.', DateHelpers.formatCurrency(_totNonFatt),
                      Icons.receipt_long_outlined, Colors.deepOrange, _totNonFatt, _totGuadagno),
                ],
              ),
            ),

          if (!_loading && _appointments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(text: '${_appointments.length}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
                      TextSpan(text: '  appuntamenti',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      if (_filtroLavoratore != null)
                        TextSpan(
                          text: '  •  ${_userNames[_filtroLavoratore] ?? _filtroLavoratore}',
                          style: TextStyle(fontSize: 13, color: primary, fontWeight: FontWeight.w600),
                        ),
                    ],
                  )),
                  Row(children: [
                    Icon(Icons.touch_app, size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('Tocca Fatt./Pag. per aggiornare',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ]),
                ],
              ),
            ),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          if (!_loading && _selectedClient == null)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 64, color: Colors.grey[200]),
                const SizedBox(height: 12),
                Text('Seleziona un cliente', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                const SizedBox(height: 4),
                Text('per visualizzare il report', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
              ],
            ))),

          if (!_loading && _selectedClient != null && _allFetched.isEmpty)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 56, color: Colors.grey[200]),
                const SizedBox(height: 10),
                Text('Nessun appuntamento trovato', style: TextStyle(color: Colors.grey[400])),
              ],
            ))),

          if (!_loading && _selectedClient != null && _appointments.isEmpty && _allFetched.isNotEmpty)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_off, size: 56, color: Colors.grey[200]),
                const SizedBox(height: 10),
                Text('Nessun risultato con questi filtri', style: TextStyle(color: Colors.grey[400])),
              ],
            ))),

          if (!_loading && _appointments.isNotEmpty)
            Expanded(child: _buildTable(primary, isAdmin)),
        ],
      ),
    );
  }

  Widget _pdfChip(String value, String label) {
    final active = _pdfFiltro == value;
    return GestureDetector(
      onTap: () => setState(() => _pdfFiltro = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.deepOrange : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? Colors.deepOrange : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : Colors.grey[700],
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        )),
      ),
    );
  }

  Widget _metricBox(String label, String value, IconData icon, Color color, double amount, double total) {
    final pct = (total > 0 && amount >= 0) ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500))),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(Color primary, bool isAdmin) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(primary.withOpacity(0.06)),
              headingRowHeight: 38,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 54,
              columnSpacing: 24,
              horizontalMargin: 16,
              dividerThickness: 0.5,
              columns: const [
                DataColumn(label: Text('Data',    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Titolo',  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Persona', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Ore',     style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                DataColumn(label: Text('Tariffa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                DataColumn(label: Text('Totale',  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                DataColumn(label: Text('Fatt.',   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Pag.',    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ],
              rows: _appointments.asMap().entries.map((entry) {
                final idx = entry.key;
                final apt = entry.value;
                final uid  = apt.userId;
                final nome = _userNames[uid] ?? (uid.length > 8 ? uid.substring(0, 8) : uid);
                final rowBg = idx.isOdd ? const Color(0xFFF9FAFB) : Colors.white;

                return DataRow(
                  color: MaterialStateProperty.all(rowBg),
                  cells: [
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateHelpers.formatDateShort(apt.data),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${apt.oraInizio}-${apt.oraFine}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                      ],
                    )),
                    DataCell(SizedBox(
                      width: 160,
                      child: Text(apt.titolo, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: primary.withOpacity(0.12),
                          child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                              style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(nome, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    )),
                    DataCell(Text(apt.oreTotali.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${apt.tariffa.toStringAsFixed(0)} EUR/h',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(DateHelpers.formatCurrency(apt.totale),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    )),
                    DataCell(Tooltip(
                      message: isAdmin
                          ? (apt.fatturato ? 'Annulla fatturazione' : 'Segna fatturato')
                          : 'Solo admin',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: isAdmin ? () async {
                          await _db.collection('appointments').doc(apt.id)
                              .update({'fatturato': !apt.fatturato});
                          _autoSearch();
                        } : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: apt.fatturato ? Colors.orange.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: apt.fatturato ? Colors.orange : Colors.grey.shade300,
                              width: apt.fatturato ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(apt.fatturato ? Icons.check : Icons.circle_outlined,
                                size: 12, color: apt.fatturato ? Colors.orange[700] : Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(apt.fatturato ? 'Si' : 'No',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: apt.fatturato ? Colors.orange[700] : Colors.grey[400])),
                          ]),
                        ),
                      ),
                    )),
                    DataCell(Tooltip(
                      message: apt.pagato ? 'Annulla pagamento' : 'Segna pagato',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          await _db.collection('appointments').doc(apt.id)
                              .update({'pagato': !apt.pagato});
                          _autoSearch();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: apt.pagato ? Colors.green.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: apt.pagato ? Colors.green : Colors.grey.shade300,
                              width: apt.pagato ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(apt.pagato ? Icons.check : Icons.circle_outlined,
                                size: 12, color: apt.pagato ? Colors.green[700] : Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(apt.pagato ? 'Si' : 'No',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: apt.pagato ? Colors.green[700] : Colors.grey[400])),
                          ]),
                        ),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );
    });
  }

  Widget _periodoChip(String value, String label, Color primary) {
    final active = _periodoType == value;
    return GestureDetector(
      onTap: () { setState(() => _periodoType = value); _applyLocalFilters(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : Colors.grey[700],
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        )),
      ),
    );
  }

  Widget _segBtn(String val, String label, String current, Function(String) onChange, Color primary) {
    final active = current == val;
    return GestureDetector(
      onTap: () => onChange(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? primary : Colors.grey.shade300, width: active ? 1.5 : 1.0),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, color: active ? primary : Colors.grey[600],
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, Function(DateTime) onPick, Color primary) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2030),
        );
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: value != null ? primary.withOpacity(0.05) : Colors.grey[50],
          border: Border.all(color: value != null ? primary.withOpacity(0.4) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today, size: 13, color: value != null ? primary : Colors.grey),
          const SizedBox(width: 5),
          Text(
            value != null
                ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                : label,
            style: TextStyle(fontSize: 12,
                color: value != null ? Colors.black87 : Colors.grey,
                fontWeight: value != null ? FontWeight.w600 : FontWeight.normal),
          ),
        ]),
      ),
    );
  }

  String _monthName(int m) {
    const months = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
                    'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
    return months[m - 1];
  }
}
