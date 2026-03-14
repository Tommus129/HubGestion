import 'package:cloud_firestore/cloud_firestore.dart';

class ClientFile {
  final String? id;
  final String clientId;
  final String nomeFile;
  final String url;
  final String mimeType;
  final int dimensione; // in bytes
  final DateTime caricatoAt;
  final String? descrizione;

  ClientFile({
    this.id,
    required this.clientId,
    required this.nomeFile,
    required this.url,
    required this.mimeType,
    required this.dimensione,
    required this.caricatoAt,
    this.descrizione,
  });

  factory ClientFile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClientFile(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      nomeFile: data['nomeFile'] ?? '',
      url: data['url'] ?? '',
      mimeType: data['mimeType'] ?? '',
      dimensione: data['dimensione'] ?? 0,
      caricatoAt: (data['caricatoAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      descrizione: data['descrizione'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'nomeFile': nomeFile,
      'url': url,
      'mimeType': mimeType,
      'dimensione': dimensione,
      'caricatoAt': FieldValue.serverTimestamp(),
      'descrizione': descrizione ?? '',
    };
  }

  String get dimensioneFormattata {
    if (dimensione < 1024) return '$dimensione B';
    if (dimensione < 1024 * 1024) return '${(dimensione / 1024).toStringAsFixed(1)} KB';
    return '${(dimensione / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get icona {
    if (mimeType.contains('pdf')) return '📄';
    if (mimeType.contains('image')) return '🖼️';
    if (mimeType.contains('word') || mimeType.contains('document')) return '📝';
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) return '📊';
    return '📎';
  }
}
