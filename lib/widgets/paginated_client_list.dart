import 'package:flutter/material.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import 'package:provider/provider.dart';

/// Lista clienti con paginazione infinita e ricerca.
/// Usa [ClientProvider] per la gestione dello stato.
class PaginatedClientList extends StatefulWidget {
  final void Function(Client client)? onTap;
  final bool includeArchived;

  const PaginatedClientList({
    super.key,
    this.onTap,
    this.includeArchived = false,
  });

  @override
  State<PaginatedClientList> createState() => _PaginatedClientListState();
}

class _PaginatedClientListState extends State<PaginatedClientList> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ClientProvider>()
          .init(includeArchived: widget.includeArchived);
    });
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      context.read<ClientProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Cerca per cognome…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        context.read<ClientProvider>().init(
                            includeArchived: widget.includeArchived);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) =>
                context.read<ClientProvider>().search(v),
          ),
        ),
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(provider.error!,
                style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scroll,
                  itemCount: provider.clients.length +
                      (provider.loadingMore ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == provider.clients.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                            child: CircularProgressIndicator()),
                      );
                    }
                    final client = provider.clients[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(client.cognome[0].toUpperCase()),
                      ),
                      title: Text(client.fullName),
                      subtitle: client.telefono != null
                          ? Text(client.telefono!)
                          : null,
                      trailing: client.archived
                          ? const Icon(Icons.archive,
                              color: Colors.grey, size: 18)
                          : null,
                      onTap: () => widget.onTap?.call(client),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
