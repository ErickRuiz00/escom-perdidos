import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/recovery.dart';
import '../../viewmodels/recovery_viewmodel.dart';
import '../widgets/common.dart';
import 'recovery_request_view.dart';
import 'recovery_chat_view.dart';

class RecoveryHubView extends StatefulWidget {
  const RecoveryHubView({super.key, this.notifications = false});
  final bool notifications;
  @override
  State<RecoveryHubView> createState() => _RecoveryHubViewState();
}

class _RecoveryHubViewState extends State<RecoveryHubView> {
  bool _received = true, _history = true;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecoveryViewModel>();
    final requests = vm.requests
        .where(
          (r) =>
              (_received ? r.finderId : r.requesterId) == vm.userId &&
              (_history || r.active),
        )
        .toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.notifications ? 'Notificaciones' : 'Chats'),
          actions: [
            IconButton(
              tooltip: 'Actualizar solicitudes',
              onPressed: vm.loading ? null : vm.load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Solicitudes'),
              Tab(text: 'Conversaciones'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              RefreshIndicator(
                onRefresh: vm.load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ConstrainedContent(
                      maxWidth: 720,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.notifications) ...[
                            Text(
                              'Tu centro de notificaciones',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            vm.incomingPending == 0
                                ? 'Solicitudes de recuperación'
                                : '${vm.incomingPending} solicitudes recibidas pendientes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Revisa la información privada antes de aceptar. La aceptación abre un chat; no confirma propiedad ni devolución.',
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Recibidas'),
                                selected: _received,
                                onSelected: (_) =>
                                    setState(() => _received = true),
                              ),
                              ChoiceChip(
                                label: const Text('Enviadas'),
                                selected: !_received,
                                onSelected: (_) =>
                                    setState(() => _received = false),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Incluir historial'),
                            value: _history,
                            onChanged: (value) =>
                                setState(() => _history = value),
                          ),
                          _RecoveryStatus(vm: vm),
                          if (requests.isEmpty &&
                              !vm.loading &&
                              vm.error == null)
                            const EmptyState(
                              icon: Icons.mark_chat_unread_outlined,
                              title: 'Sin solicitudes por ahora',
                              message:
                                  'Tus solicitudes confirmadas aparecerán aquí. Puedes solicitar un hallazgo desde su detalle.',
                            ),
                          for (final r in requests)
                            _RequestTile(
                              request: r,
                              onTap: () => _open(
                                context,
                                RecoveryRequestView(requestId: r.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ConstrainedContent(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Las conversaciones se abren al aceptar una solicitud. Cada solicitante tiene un espacio independiente.',
                        ),
                        const SizedBox(height: 16),
                        _RecoveryStatus(vm: vm),
                        if (vm.conversations.isEmpty &&
                            !vm.loading &&
                            vm.error == null)
                          const EmptyState(
                            icon: Icons.forum_outlined,
                            title: 'Sin conversaciones por ahora',
                            message:
                                'Acepta una solicitud recibida o espera a que acepten la tuya.',
                          ),
                        for (final c in vm.conversations)
                          if (vm.byId(c.requestId) case final RecoveryRequest r)
                            _RequestTile(
                              request: r,
                              conversation: true,
                              onTap: () => _open(
                                context,
                                c.closedAt == null &&
                                        r.status == RecoveryStatus.accepted
                                    ? RecoveryChatView(conversation: c)
                                    : RecoveryRequestView(requestId: r.id),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget view) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => view));
}

class _RecoveryStatus extends StatelessWidget {
  const _RecoveryStatus({required this.vm});
  final RecoveryViewModel vm;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (vm.loading) const LinearProgressIndicator(),
      if (vm.error != null)
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos actualizar tus solicitudes',
          message: vm.error!,
          action: TextButton(
            onPressed: vm.load,
            child: const Text('Reintentar'),
          ),
        ),
      if (!vm.connected && vm.error == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Comprobamos novedades periódicamente. También puedes actualizar manualmente.',
          ),
        ),
    ],
  );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onTap,
    this.conversation = false,
  });
  final RecoveryRequest request;
  final VoidCallback onTap;
  final bool conversation;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        conversation ? Icons.forum_outlined : Icons.inventory_2_outlined,
      ),
      title: Text(request.itemTitle),
      subtitle: Text(
        '${request.stateLabel}\n${request.closureLabel ?? 'Información visible solo para sus participantes.'}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
