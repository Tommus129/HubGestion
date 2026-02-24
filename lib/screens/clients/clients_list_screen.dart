import 'package:flutter/material.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../widgets/app_drawer.dart';

class ClientsListScreen extends StatefulWidget {
  @override
  _ClientsListScreenState createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  final ClientService _clientService = ClientService();
  final _searchController = TextEditingController();
  String _search = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clienti'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: _showArchived ? 'Nascondi archiviati' : 'Mostra archiviati',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca cliente...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Client>>(
              stream: _clientService.getClients(includeArchived: _showArchived),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 64, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text('Nessun cliente', style: TextStyle(color: Colors.grey, fontSize: 18)),
                      ],
                    ),
                  );
                }

                final clients = snapshot.data!.where((c) =>
                  _search.isEmpty ||
                  c.fullName.toLowerCase().contains(_search) ||
                  (c.email?.toLowerCase().contains(_search) ?? false)
                ).toList();

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: clients.length,
                  itemBuilder: (context, i) {
                    final client = clients[i];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: client.archived ? Colors.grey : Colors.teal,
                          child: Text(
                            client.nome.isNotEmpty ? client.nome[0].toUpperCase() : 'C',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(client.fullName, style: TextStyle(fontWeight: FontWeight.bold)),
                            if (client.archived) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Archiviato', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(client.email ?? client.telefono ?? ''),
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Modifica')])),
                            PopupMenuItem(
                              value: 'archive',
                              child: Row(children: [
                                Icon(client.archived ? Icons.unarchive : Icons.archive, size: 16),
                                SizedBox(width: 8),
                                Text(client.archived ? 'Riattiva' : 'Archivia'),
                              ]),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') _showClientDialog(context, client: client);
                            if (value == 'archive') _clientService.archiveClient(client.id!, !client.archived);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClientDialog(context),
        backgroundColor: Colors.teal,
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text('Nuovo Cliente', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showClientDialog(BuildContext context, {Client? client}) {
    final nomeController = TextEditingController(text: client?.nome ?? '');
    final cognomeController = TextEditingController(text: client?.cognome ?? '');
    final emailController = TextEditingController(text: client?.email ?? '');
    final telefonoController = TextEditingController(text: client?.telefono ?? '');
    final noteController = TextEditingController(text: client?.note ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(client == null ? 'Nuovo Cliente' : 'Modifica Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: TextField(controller: nomeController,
                  decoration: InputDecoration(labelText: 'Nome *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                SizedBox(width: 8),
                Expanded(child: TextField(controller: cognomeController,
                  decoration: InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
              ]),
              SizedBox(height: 12),
              TextField(controller: emailController,
                decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              SizedBox(height: 12),
              TextField(controller: telefonoController,
                decoration: InputDecoration(labelText: 'Telefono', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              SizedBox(height: 12),
              TextField(controller: noteController, maxLines: 3,
                decoration: InputDecoration(labelText: 'Note', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              if (nomeController.text.isEmpty || cognomeController.text.isEmpty) return;
              final newClient = Client(
                id: client?.id,
                nome: nomeController.text,
                cognome: cognomeController.text,
                email: emailController.text,
                telefono: telefonoController.text,
                note: noteController.text,
              );
              if (client == null) {
                await ClientService().createClient(newClient);
              } else {
                await ClientService().updateClient(client.id!, newClient.toFirestore());
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: Text(client == null ? 'Crea' : 'Salva'),
          ),
        ],
      ),
    );
  }
}
