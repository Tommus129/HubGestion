import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../models/client_file.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ClientFile?> uploadFilePerCliente({
    required String clientId,
    String? descrizione,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    final Uint8List? bytes = picked.bytes;
    if (bytes == null) return null;

    final fileName = picked.name;
    final mimeType = picked.extension != null
        ? _mimeFromExtension(picked.extension!)
        : 'application/octet-stream';

    // Storage path allineato con la collection Firestore 'clients'
    final path = 'clients/$clientId/$fileName';
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: mimeType),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    final clientFile = ClientFile(
      clientId: clientId,
      nomeFile: fileName,
      url: downloadUrl,
      mimeType: mimeType,
      dimensione: bytes.length,
      caricatoAt: DateTime.now(),
      descrizione: descrizione,
    );

    final docRef = await _db
        .collection('clients')
        .doc(clientId)
        .collection('files')
        .add(clientFile.toFirestore());

    return ClientFile(
      id: docRef.id,
      clientId: clientFile.clientId,
      nomeFile: clientFile.nomeFile,
      url: clientFile.url,
      mimeType: clientFile.mimeType,
      dimensione: clientFile.dimensione,
      caricatoAt: clientFile.caricatoAt,
      descrizione: clientFile.descrizione,
    );
  }

  Stream<List<ClientFile>> getFilesStream(String clientId) {
    return _db
        .collection('clients')
        .doc(clientId)
        .collection('files')
        .orderBy('caricatoAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ClientFile.fromFirestore).toList());
  }

  Future<void> eliminaFile(ClientFile file) async {
    try {
      final ref = _storage.refFromURL(file.url);
      await ref.delete();
    } catch (_) {}

    await _db
        .collection('clients')
        .doc(file.clientId)
        .collection('files')
        .doc(file.id)
        .delete();
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
