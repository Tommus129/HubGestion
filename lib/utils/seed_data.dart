import 'package:cloud_firestore/cloud_firestore.dart';

/// Popola Firestore con dati di test realistici.
/// CHIAMARE UNA VOLTA SOLA, poi ricommentare in main.dart.
///
/// Crea:
///   - 4 stanze
///   - 10 clienti
///   - 12 appuntamenti distribuiti su 3 settimane
Future<void> seedFirestore() async {
  final db = FirebaseFirestore.instance;

  // ── 1. STANZE ────────────────────────────────────────────────────────
  final rooms = [
    {'name': 'Sala A', 'color': '#4CAF50', 'capacity': 1},
    {'name': 'Sala B', 'color': '#2196F3', 'capacity': 2},
    {'name': 'Sala C', 'color': '#FF9800', 'capacity': 1},
    {'name': 'Sala D', 'color': '#9C27B0', 'capacity': 3},
  ];

  final roomRefs = <DocumentReference>[];
  for (final r in rooms) {
    final ref = await db.collection('rooms').add({
      ...r,
      'createdAt': FieldValue.serverTimestamp(),
    });
    roomRefs.add(ref);
    print('✅ Stanza: ${r['name']} → ${ref.id}');
  }

  // ── 2. CLIENTI ───────────────────────────────────────────────────────
  final clients = [
    {
      'nome': 'Marco', 'cognome': 'Rossi',
      'email': 'marco.rossi@email.it', 'telefono': '3331234567',
      'codiceFiscale': 'RSSMRC85M01H501Z', 'isSocio': true,
      'indirizzo': 'Via Roma 10, Milano',
    },
    {
      'nome': 'Giulia', 'cognome': 'Bianchi',
      'email': 'giulia.bianchi@email.it', 'telefono': '3347654321',
      'codiceFiscale': 'BNCGLI90F41F205Y', 'isSocio': true,
      'indirizzo': 'Via Torino 5, Milano',
    },
    {
      'nome': 'Luca', 'cognome': 'Ferrari',
      'email': 'luca.ferrari@email.it', 'telefono': '3359876543',
      'codiceFiscale': 'FRRLCU78C15L219K', 'isSocio': false,
      'indirizzo': 'Corso Buenos Aires 22, Milano',
    },
    {
      'nome': 'Sofia', 'cognome': 'Conti',
      'email': 'sofia.conti@email.it', 'telefono': '3361112233',
      'codiceFiscale': 'CNTSFO95P55G273W', 'isSocio': true,
      'indirizzo': 'Via Venezia 3, Bergamo',
    },
    {
      'nome': 'Alessandro', 'cognome': 'Mancini',
      'email': 'ale.mancini@email.it', 'telefono': '3383334455',
      'codiceFiscale': 'MNCLSN88H20A944P', 'isSocio': false,
      'indirizzo': 'Via Napoli 8, Brescia',
    },
    {
      'nome': 'Chiara', 'cognome': 'Russo',
      'email': 'chiara.russo@email.it', 'telefono': '3395556677',
      'codiceFiscale': 'RSSCHR92D44H501V', 'isSocio': true,
      'indirizzo': 'Via Firenze 15, Milano',
    },
    {
      'nome': 'Matteo', 'cognome': 'Gallo',
      'email': 'matteo.gallo@email.it', 'telefono': '3407778899',
      'codiceFiscale': 'GLLMTT91A01C933X', 'isSocio': true,
      'indirizzo': 'Viale Monza 100, Milano',
    },
    {
      'nome': 'Federica', 'cognome': 'Lombardi',
      'email': 'fede.lombardi@email.it', 'telefono': '3419990011',
      'codiceFiscale': 'LMBFRC89P52H501T', 'isSocio': false,
      'indirizzo': 'Via Como 7, Monza',
    },
    {
      'nome': 'Davide', 'cognome': 'Marino',
      'email': 'davide.marino@email.it', 'telefono': '3421122334',
      'codiceFiscale': 'MRNDVD87E09F839J', 'isSocio': true,
      'indirizzo': 'Via Genova 20, Milano',
    },
    {
      'nome': 'Valentina', 'cognome': 'Ricci',
      'email': 'vale.ricci@email.it', 'telefono': '3433344556',
      'codiceFiscale': 'RCCVNT93R55H501Q', 'isSocio': true,
      'indirizzo': 'Piazza Duomo 1, Milano',
    },
  ];

  final clientRefs = <DocumentReference>[];
  for (final c in clients) {
    final data = Map<String, dynamic>.from(c);
    data['archived'] = false;
    data['createdAt'] = FieldValue.serverTimestamp();
    final ref = await db.collection('clients').add(data);
    clientRefs.add(ref);
    print('✅ Cliente: ${c['nome']} ${c['cognome']} → ${ref.id}');
  }

  // ── 3. APPUNTAMENTI ──────────────────────────────────────────────────
  // Usa uid placeholder — in produzione sostituire con UID reale dell'utente.
  // Puoi recuperarlo da Firebase Console > Authentication.
  const workerUid = 'REPLACE_WITH_YOUR_UID';

  final now = DateTime.now();
  // Base: lunedì della settimana corrente
  final monday = now.subtract(Duration(days: now.weekday - 1));

  final appointments = [
    // Settimana corrente
    _apt('Consulenza iniziale', monday,             '09:00', '10:00', 1.0,  50.0, 50.0,  true,  false, false, clientRefs[0].id, roomRefs[0].id, workerUid),
    _apt('Seduta fisioterapia', monday,             '11:00', '12:00', 1.0,  60.0, 60.0,  true,  true,  true,  clientRefs[1].id, roomRefs[1].id, workerUid),
    _apt('Follow-up Marco',    monday.add(Duration(days: 1)), '09:30', '10:30', 1.0, 50.0, 50.0, true, false, false, clientRefs[0].id, roomRefs[0].id, workerUid),
    _apt('Allenamento Luca',   monday.add(Duration(days: 1)), '14:00', '15:30', 1.5, 57.5, 86.25, false, false, false, clientRefs[2].id, roomRefs[2].id, workerUid),
    _apt('Sessione Sofia',     monday.add(Duration(days: 2)), '10:00', '11:00', 1.0, 50.0, 50.0, true, true, true, clientRefs[3].id, roomRefs[1].id, workerUid),
    _apt('Trattamento Ale',    monday.add(Duration(days: 2)), '15:00', '16:00', 1.0, 57.5, 57.5, false, true, false, clientRefs[4].id, roomRefs[3].id, workerUid),
    _apt('Rieducazione Chiara',monday.add(Duration(days: 3)), '09:00', '10:30', 1.5, 50.0, 75.0, true, false, false, clientRefs[5].id, roomRefs[0].id, workerUid),
    _apt('Consulenza Matteo',  monday.add(Duration(days: 3)), '11:00', '12:00', 1.0, 50.0, 50.0, true, true, true, clientRefs[6].id, roomRefs[2].id, workerUid),
    // Settimana prossima
    _apt('Fede - prima seduta',monday.add(Duration(days: 7)), '10:00', '11:00', 1.0, 57.5, 57.5, false, false, false, clientRefs[7].id, roomRefs[1].id, workerUid),
    _apt('Davide - follow-up', monday.add(Duration(days: 8)), '14:00', '15:00', 1.0, 50.0, 50.0, true, false, false, clientRefs[8].id, roomRefs[0].id, workerUid),
    _apt('Valentina - terapia',monday.add(Duration(days: 9)), '09:00', '10:30', 1.5, 50.0, 75.0, true, false, false, clientRefs[9].id, roomRefs[3].id, workerUid),
    // Settimana scorsa (storico)
    _apt('Seduta storica',     monday.subtract(Duration(days: 3)), '10:00', '11:00', 1.0, 50.0, 50.0, true, true, true, clientRefs[1].id, roomRefs[0].id, workerUid),
  ];

  for (final a in appointments) {
    final ref = await db.collection('appointments').add(a);
    print('✅ Appuntamento: ${a['titolo']} → ${ref.id}');
  }

  print('\n🎉 Seed completato! Ricommentare seedFirestore() in main.dart.');
}

Map<String, dynamic> _apt(
  String titolo,
  DateTime data,
  String oraInizio,
  String oraFine,
  double oreTotali,
  double tariffa,
  double totale,
  bool isSocio,
  bool fatturato,
  bool pagato,
  String? clientId,
  String? roomId,
  String workerUid,
) {
  return {
    'titolo': titolo,
    'data': Timestamp.fromDate(DateTime(data.year, data.month, data.day)),
    'oraInizio': oraInizio,
    'oraFine': oraFine,
    'oreTotali': oreTotali,
    'tariffa': tariffa,
    'totale': totale,
    'isSocio': isSocio,
    'fatturato': fatturato,
    'pagato': pagato,
    'clientId': clientId ?? '',
    'roomId': roomId ?? '',
    'userId': workerUid,
    'createdBy': workerUid,
    'workerIds': [workerUid],
    'note': '',
    'deleted': false,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
