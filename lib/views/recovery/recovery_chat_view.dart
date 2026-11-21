import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/recovery.dart';
import '../../viewmodels/recovery_viewmodel.dart';
import '../../viewmodels/recovery_chat_viewmodel.dart';
import '../widgets/common.dart';
import 'recovery_request_view.dart';

class RecoveryChatView extends StatelessWidget {
  const RecoveryChatView({super.key, required this.conversation});
  final RecoveryConversation conversation;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => RecoveryChatViewModel(
      recovery: context.read<RecoveryViewModel>(),
      conversation: conversation,
    )..start(),
    child: const _Chat(),
  );
}

class _Chat extends StatefulWidget {
  const _Chat();
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> with WidgetsBindingObserver {
  final _text = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!context.watch<RecoveryChatViewModel>().active &&
        _text.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _text.clear();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<RecoveryViewModel>().load();
      context.read<RecoveryChatViewModel>().load();
    }
  }

  Future<void> _send() async {
    final vm = context.read<RecoveryChatViewModel>();
    final text = _text.text.trim();
    if (text.isEmpty || vm.sending || !vm.active) return;
    _text.clear();
    try {
      await vm.send(text);
    } catch (e) {
      if (mounted && vm.active && !vm.sessionEnded) {
        if (_text.text.isEmpty) _text.text = text;
        showSnack(context, userMessageFor(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecoveryChatViewModel>();
    final r = context.watch<RecoveryViewModel>().byId(
      vm.conversation.requestId,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat privado'),
        actions: [
          IconButton(
            tooltip: 'Solicitud y acuerdo',
            onPressed: vm.sessionEnded
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecoveryRequestView(
                        requestId: vm.conversation.requestId,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.assignment_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar mensajes',
            onPressed: vm.loading || !vm.active ? null : () => vm.load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !vm.active
            ? const SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Conversación cerrada',
                  message:
                      'La solicitud o la sesión ya no permite leer ni enviar mensajes. Revisa el historial de la solicitud.',
                ),
              )
            : Column(
                children: [
                  if (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom >
                      550)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            r?.itemTitle ?? 'Hallazgo',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            vm.connected
                                ? 'Conectado · Solo participantes'
                                : 'Actualización periódica activa · Reconectando al tiempo real',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (r?.meetingPoint != null)
                            Text(
                              'Encuentro: ${r!.meetingPoint} · ${Formatters.dateTime(r.meetingAt!.toLocal())}',
                            ),
                          if (vm.loading) const LinearProgressIndicator(),
                        ],
                      ),
                    ),
                  Expanded(
                    child:
                        vm.messages.isEmpty &&
                            vm.pending.isEmpty &&
                            !vm.loading &&
                            vm.error == null
                        ? const SingleChildScrollView(
                            child: EmptyState(
                              icon: Icons.forum_outlined,
                              title: 'Empieza la conversación',
                              message:
                                  'Aclaren las características del objeto y acuerden un encuentro seguro dentro de ESCOM.',
                            ),
                          )
                        : ListView(
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (vm.error != null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Text(
                                        vm.error!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => vm.load(),
                                        child: const Text(
                                          'Reintentar mensajes',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              for (final m in vm.pending.reversed)
                                _bubble(
                                  context,
                                  m.body,
                                  true,
                                  m.sending
                                      ? 'Enviando…'
                                      : m.error ?? 'Pendiente',
                                  retry: m.sending
                                      ? null
                                      : () => vm.retry(m.id),
                                ),
                              for (final m in vm.messages.reversed)
                                _bubble(
                                  context,
                                  m.body,
                                  m.senderId == vm.userId,
                                  '${m.senderId == vm.userId
                                      ? 'Tú'
                                      : m.senderId == r?.finderId
                                      ? 'Encontrador'
                                      : 'Solicitante'} · ${Formatters.dateTime(m.createdAt.toLocal())}',
                                ),
                              if (vm.hasOlder)
                                TextButton(
                                  onPressed: vm.loading
                                      ? null
                                      : () => vm.load(older: true),
                                  child: const Text(
                                    'Cargar mensajes anteriores',
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('recovery-message'),
                            controller: _text,
                            minLines: 1,
                            maxLines: 3,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                              hintText: 'Mensaje privado',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Enviar mensaje',
                          onPressed: vm.sending ? null : _send,
                          icon: Icon(
                            vm.sending
                                ? Icons.hourglass_top_rounded
                                : Icons.send_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    String body,
    bool mine,
    String state, {
    VoidCallback? retry,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              body,
              style: TextStyle(
                color: mine ? colors.onPrimaryContainer : colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mine ? colors.onPrimaryContainer : colors.onSurface,
              ),
            ),
            if (retry != null)
              TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar mensaje'),
              ),
          ],
        ),
      ),
    );
  }
}
