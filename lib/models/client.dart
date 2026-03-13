import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String? id;

  // Anagrafica base
  final String nome;
  final String cognome;
  final String? dataNascita;     // es. "1990-05-23"
  final String? luogoNascita;
  final String? sesso;           // "M" | "F"

  // Contatti
  final String? email;
  final String? telefono;
  final String? telefonoSecondario;
  final String? pec;

  // Residenza / domicilio
  final String? indirizzo;       // via + numero civico
  final String? cap;
  final String? citta;
  final String? provincia;       // es. "GE"
  final String? nazione;         // default "Italia"

  // Dati fiscali
  final String? codiceFiscale;

  // Fatturazione (persona fisica)
  final String? indirizzoFatturazione; // se diverso dalla residenza
  final String? capFatturazione;
  final String? cittaFatturazione;
  final String? provinciaFatturazione;
  final String? nazioneFatturazione;
  final String? codiceSdi;       // Codice Destinatario SDI (7 cifre)

  // Genitori / tutore
  final String? genitori;

  // Note
  final String? note;

  // Stato
  final bool archived;
  final bool isSocio;

  Client({
    this.id,
    required this.nome,
    required this.cognome,
    this.dataNascita,
    this.luogoNascita,
    this.sesso,
    this.email,
    this.telefono,
    this.telefonoSecondario,
    this.pec,
    this.indirizzo,
    this.cap,
    this.citta,
    this.provincia,
    this.nazione,
    this.codiceFiscale,
    this.indirizzoFatturazione,
    this.capFatturazione,
    this.cittaFatturazione,
    this.provinciaFatturazione,
    this.nazioneFatturazione,
    this.codiceSdi,
    this.genitori,
    this.note,
    this.archived = false,
    this.isSocio = true,
  });

  String get fullName => '$nome $cognome';

  factory Client.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isArchived =
        (data['archived'] as bool?) ??
        (data['archiviato'] as bool?) ??
        false;
    return Client(
      id: doc.id,
      nome: data['nome'] ?? '',
      cognome: data['cognome'] ?? '',
      dataNascita: data['dataNascita'],
      luogoNascita: data['luogoNascita'],
      sesso: data['sesso'],
      email: data['email'],
      telefono: data['telefono'],
      telefonoSecondario: data['telefonoSecondario'],
      pec: data['pec'],
      indirizzo: data['indirizzo'],
      cap: data['cap'],
      citta: data['citta'],
      provincia: data['provincia'],
      nazione: data['nazione'],
      codiceFiscale: data['codiceFiscale'],
      indirizzoFatturazione: data['indirizzoFatturazione'],
      capFatturazione: data['capFatturazione'],
      cittaFatturazione: data['cittaFatturazione'],
      provinciaFatturazione: data['provinciaFatturazione'],
      nazioneFatturazione: data['nazioneFatturazione'],
      codiceSdi: data['codiceSdi'],
      genitori: data['genitori'],
      note: data['note'],
      archived: isArchived,
      isSocio: data['isSocio'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'cognome': cognome,
      'dataNascita': dataNascita ?? '',
      'luogoNascita': luogoNascita ?? '',
      'sesso': sesso ?? '',
      'email': email ?? '',
      'telefono': telefono ?? '',
      'telefonoSecondario': telefonoSecondario ?? '',
      'pec': pec ?? '',
      'indirizzo': indirizzo ?? '',
      'cap': cap ?? '',
      'citta': citta ?? '',
      'provincia': provincia ?? '',
      'nazione': nazione ?? 'Italia',
      'codiceFiscale': codiceFiscale ?? '',
      'indirizzoFatturazione': indirizzoFatturazione ?? '',
      'capFatturazione': capFatturazione ?? '',
      'cittaFatturazione': cittaFatturazione ?? '',
      'provinciaFatturazione': provinciaFatturazione ?? '',
      'nazioneFatturazione': nazioneFatturazione ?? 'Italia',
      'codiceSdi': codiceSdi ?? '',
      'genitori': genitori ?? '',
      'note': note ?? '',
      'archived': archived,
      'isSocio': isSocio,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
