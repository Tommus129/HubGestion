import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/client_file.dart';
import '../services/storage_service.dart';

class ClientFilesWidget extends StatelessWidget {
  final String clientId;
  final StorageService _storageService = StorageService();

  ClientFilesWidget({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Documenti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Carica file'),
              onPressed: () => _caricaFile(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ClientFile>>(
          stream: _storageService.getFilesStream(clientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final files = snapshot.data ?? [];
            if (files.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nessun documento caricato.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: files.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) => _FileTile(
                file: files[i],
                onDelete: () => _eliminaFile(context, files[i]),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _caricaFile(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final file = await _storageService.uploadFilePerCliente(clientId: clientId);
      if (file != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('File "\${file.nomeFile}" caricato con successo!')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Errore durante il caricamento: \$e')),
      );
    }
  }

  Future<void> _eliminaFile(BuildContext context, ClientFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina file'),
        content: Text('Eliminare "\${file.nomeFile}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _storageService.eliminaFile(file);
    }
  }
}

class _FileTile extends StatelessWidget {
  final ClientFile file;
  final VoidCallback onDelete;

  const _FileTile({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(file.icona, style: const TextStyle(fontSize: 28)),
      title: Text(file.nomeFile, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '\${file.dimensioneFormattata} • \${_formatData(file.caricatoAt)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Apri',
            onPressed: () => _apriFile(file.url),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Elimina',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _apriFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatData(DateTime dt) {
    return '\${dt.day.toString().padLeft(2, '0')}/\${dt.month.toString().padLeft(2, '0')}/\${dt.year}';
  }
}
