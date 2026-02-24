import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Clienti'),
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
                        Text('Nessun cliente',
                            style: TextStyle(color: Colors.grey, fontSize: 18)),
                      ],
                    ),
                  );
                }

                final clients = snapshot.data!.where((c) =>
                  _search.isEmpty ||
                  c.fullName.toLowerCase().contains(_search) ||
                  (c.email?.toLowerCase().contains(_search) ?? false) ||
                  (c.telefono?.toLowerCase().contains(_search) ?? false)
                ).toList();

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: clients.length,
                  itemBuilder: (context, i) {
                    final client = clients[i];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showClientDetail(context, client, primary),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: client.archived ? Colors.grey : primary,
                                child: Text(
                                  client.nome.isNotEmpty ? client.nome[0].toUpperCase() : 'C',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(client.fullName,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                                    ]),
                                    SizedBox(height: 2),
                                    if ((client.email ?? '').isNotEmpty)
                                      _infoRow(Icons.email_outlined, client.email!, 11),
                                    if ((client.telefono ?? '').isNotEmpty)
                                      _infoRow(Icons.phone_outlined, client.telefono!, 11),
                                    if ((client.note ?? '').isNotEmpty)
                                      Row(children: [
                                        Icon(Icons.note_outlined, size: 11, color: Colors.amber[700]),
                                        SizedBox(width: 3),
                                        Text('Note presenti',
                                            style: TextStyle(fontSize: 11, color: Colors.amber[700], fontStyle: FontStyle.italic)),
                                      ]),
                                  ],
                                ),
                              ),
                              PopupMenuButton(
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Modifica')]),
                                  ),
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
                                  if (value == 'edit') _showClientDialog(context, primary, client: client);
                                  if (value == 'archive') _clientService.archiveClient(client.id!, !client.archived);
                                },
                              ),
                            ],
                          ),
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
        onPressed: () => _showClientDialog(context, primary),
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text('Nuovo Cliente', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showClientDetail(BuildContext context, Client client, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12, bottom: 16),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: client.archived ? Colors.grey : primary,
                  child: Text(
                    client.nome.isNotEmpty ? client.nome[0].toUpperCase() : 'C',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (client.archived)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                          child: Text('Archiviato', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: primary),
                  tooltip: 'Modifica',
                  onPressed: () {
                    Navigator.pop(context);
                    _showClientDialog(context, primary, client: client);
                  },
                ),
              ]),
              Divider(height: 28),
              _sectionTitle('Contatto'),
              SizedBox(height: 10),
              if ((client.email ?? '').isNotEmpty)
                _detailRow(icon: Icons.email_outlined, color: Colors.blue, label: 'Email', value: client.email!, copiable: true),
              if ((client.telefono ?? '').isNotEmpty)
                _detailRow(icon: Icons.phone_outlined, color: Colors.green, label: 'Telefono', value: client.telefono!, copiable: true),
              if ((client.email ?? '').isEmpty && (client.telefono ?? '').isEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Nessun contatto inserito', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              if ((client.note ?? '').isNotEmpty) ...[
                Divider(height: 28),
                _sectionTitle('Note'),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(client.note!, style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
                ),
              ],
              SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _clientService.archiveClient(client.id!, !client.archived);
                    },
                    icon: Icon(client.archived ? Icons.unarchive : Icons.archive, size: 16),
                    label: Text(client.archived ? 'Riattiva' : 'Archivia'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!)),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showClientDialog(context, primary, client: client);
                    },
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('Modifica'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.8));

  Widget _detailRow({required IconData icon, required Color color, required String label, required String value, bool copiable = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (copiable)
            IconButton(
              icon: Icon(Icons.copy, size: 16, color: Colors.grey[400]),
              tooltip: 'Copia',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copiato'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, double size) => Row(
    children: [
      Icon(icon, size: size, color: Colors.grey[500]),
      SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: size, color: Colors.grey[600])),
    ],
  );

  void _showClientDialog(BuildContext context, Color primary, {Client? client}) {
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
                Expanded(child: TextField(controller: nomeController, decoration: InputDecoration(labelText: 'Nome *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                SizedBox(width: 8),
                Expanded(child: TextField(controller: cognomeController, decoration: InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
              ]),
              SizedBox(height: 12),
              TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              SizedBox(height: 12),
              TextField(controller: telefonoController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Telefono', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              SizedBox(height: 12),
              TextField(controller: noteController, maxLines: 3, decoration: InputDecoration(labelText: 'Note', prefixIcon: Icon(Icons.note_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
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
                nome: nomeController.text.trim(),
                cognome: cognomeController.text.trim(),
                email: emailController.text.trim(),
                telefono: telefonoController.text.trim(),
                note: noteController.text.trim(),
              );
              if (client == null) {
                await ClientService().createClient(newClient);
              } else {
                await ClientService().updateClient(client.id!, newClient.toFirestore());
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
            child: Text(client == null ? 'Crea' : 'Salva'),
          ),
        ],
      ),
    );
  }
}
