import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/escom.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/recovery.dart';
import '../../viewmodels/recovery_viewmodel.dart';
import '../reports/report_detail_view.dart';
import '../widgets/common.dart';
import 'recovery_chat_view.dart';

class RecoveryRequestView extends StatefulWidget {
  const RecoveryRequestView({super.key, required this.requestId});
  final String requestId;
  @override
  State<RecoveryRequestView> createState() => _RecoveryRequestViewState();
}

class _RecoveryRequestViewState extends State<RecoveryRequestView> {
  late final int _session;
  int? _version;
  Future<List<RecoveryEvent>>? _history;
  @override
  void initState() {
    super.initState();
    _session = context.read<RecoveryViewModel>().sessionRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RecoveryViewModel>().load();
    });
  }

  Future<void> _action(
    RecoveryRequest r,
    String action,
    String title,
    String message,
    String label,
  ) async {
    final vm = context.read<RecoveryViewModel>();
    if (vm.busy(r.id)) return;
    if (!await confirmAction(
          context,
          title: title,
          message: message,
          confirmLabel: label,
          destructive: action != 'accept' && action != 'confirm',
        ) ||
        !mounted) {
      return;
    }
    try {
      vm.assertSession(_session);
      await vm.act(r, action);
      if (mounted) showSnack(context, 'Estado actualizado');
    } catch (e) {
      if (mounted) showSnack(context, userMessageFor(e), error: true);
    }
  }

  Future<void> _meeting(RecoveryRequest r) async {
    final vm = context.read<RecoveryViewModel>();
    String point = Escom.locations.contains(r.meetingPoint)
        ? r.meetingPoint!
        : 'Explanada';
    DateTime? date = r.meetingAt?.toLocal();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          scrollable: true,
          title: const Text('Coordinar en ESCOM'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Acuerden el lugar y horario por el chat. Elijan un espacio público dentro de ESCOM y eviten acudir solos a lugares aislados.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: point,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Zona de encuentro',
                ),
                items: Escom.locations
                    .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) set(() => point = v);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final day = await showDatePicker(
                    context: context,
                    initialDate: date != null && date!.isAfter(now)
                        ? date!
                        : now,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: now.add(const Duration(days: 30)),
                  );
                  if (day == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(date ?? now),
                  );
                  if (time != null && context.mounted) {
                    set(
                      () => date = DateTime(
                        day.year,
                        day.month,
                        day.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
                child: Text(
                  date == null
                      ? 'Elegir fecha y hora'
                      : Formatters.dateTime(date!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: date == null
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: const Text('Guardar acuerdo'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      vm.assertSession(_session);
      await vm.act(r, 'meeting', point: point, at: date);
    } catch (e) {
      if (mounted) showSnack(context, userMessageFor(e), error: true);
    }
  }

  Future<void> _safety(RecoveryRequest r, bool block) async {
    final vm = context.read<RecoveryViewModel>();
    if (block) {
      final blocked = vm.blocked.contains(r.peer(vm.userId!));
      if (!await confirmAction(
            context,
            title: blocked
                ? '¿Desbloquear participante?'
                : '¿Bloquear participante?',
            message: blocked
                ? 'Las conversaciones cerradas no se reabren. Podrán volver a contactar cuando las reglas de solicitudes lo permitan.'
                : 'Se cerrarán sus solicitudes y conversaciones activas contigo. No podrá enviarte nuevas solicitudes ni mensajes.',
            confirmLabel: blocked ? 'Desbloquear' : 'Bloquear',
          ) ||
          !mounted) {
        return;
      }
      try {
        vm.assertSession(_session);
        await vm.block(r, !blocked);
      } catch (e) {
        if (mounted) showSnack(context, userMessageFor(e), error: true);
      }
    } else {
      final controller = TextEditingController();
      final id = const Uuid().v4();
      try {
        final reason = await showDialog<String>(
          context: context,
          builder: (dialog) => AlertDialog(
            scrollable: true,
            title: const Text('Reportar abuso'),
            content: TextField(
              controller: controller,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Motivo privado (10 a 1000 caracteres)',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, controller.text),
                child: const Text('Enviar reporte'),
              ),
            ],
          ),
        );
        if (reason == null || !mounted) return;
        if (reason.trim().length < 10) {
          showSnack(
            context,
            'Describe el motivo con al menos 10 caracteres.',
            error: true,
          );
          return;
        }
        vm.assertSession(_session);
        await vm.report(r, id: id, reason: reason);
        if (mounted) showSnack(context, 'Reporte registrado');
      } catch (e) {
        if (mounted) showSnack(context, userMessageFor(e), error: true);
      } finally {
        controller.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecoveryViewModel>();
    final r = vm.sessionRevision == _session ? vm.byId(widget.requestId) : null;
    if (r != null && _version != r.version) {
      _version = r.version;
      _history = vm.repository.history(r.id);
    }
    final finder = r?.finderId == vm.userId;
    final busy = vm.busy(widget.requestId);
    final c = vm.conversation(widget.requestId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud privada'),
        actions: [
          IconButton(
            tooltip: 'Actualizar solicitud',
            onPressed: vm.loading ? null : vm.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: r == null
            ? (vm.loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.lock_outline,
                        title: 'Solicitud no disponible',
                        message:
                            vm.error ??
                            'La solicitud no pertenece a esta sesión.',
                        action: TextButton(
                          onPressed: vm.load,
                          child: const Text('Reintentar'),
                        ),
                      ),
                    ))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedContent(
                  maxWidth: 720,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vm.error != null) ...[
                        Text(
                          vm.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        r.itemTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(r.stateLabel)),
                          Chip(
                            label: Text(
                              finder
                                  ? 'Solicitud recibida'
                                  : 'Solicitud enviada',
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ReportDetailView(reportId: r.itemId),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Ver publicación'),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Características privadas',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              SelectableText(r.evidence),
                              const SizedBox(height: 12),
                              const Text(
                                'Esta descripción ayuda a verificar el objeto. El sistema no acredita automáticamente quién es su propietario.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (r.closureLabel != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(r.closureLabel!),
                        ),
                      if (r.status == RecoveryStatus.pending && finder) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => _action(
                                  r,
                                  'accept',
                                  '¿Aceptar solicitud?',
                                  'Se abrirá un chat privado para aclarar características y coordinar la entrega. No confirma propiedad ni devolución.',
                                  'Aceptar',
                                ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Aceptar solicitud'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _action(
                                  r,
                                  'reject',
                                  '¿Rechazar solicitud?',
                                  'Se conservará la solicitud en el historial.',
                                  'Rechazar',
                                ),
                          child: const Text('Rechazar solicitud'),
                        ),
                      ],
                      if (r.status == RecoveryStatus.accepted) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: busy || c == null || c.closedAt != null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        RecoveryChatView(conversation: c),
                                  ),
                                ),
                          icon: const Icon(Icons.forum_outlined),
                          label: const Text('Abrir chat privado'),
                        ),
                        if (r.meetingPoint != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(r.meetingPoint!),
                            subtitle: Text(
                              r.meetingAt == null
                                  ? ''
                                  : Formatters.dateTime(r.meetingAt!.toLocal()),
                            ),
                          ),
                        if (!r.hasConfirmation)
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => _meeting(r),
                            icon: const Icon(Icons.event_outlined),
                            label: const Text('Coordinar encuentro'),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          r.confirmedBy(vm.userId!)
                              ? 'Tu confirmación está registrada. Esperamos a la otra parte.'
                              : 'Confirma únicamente después de la devolución física. Se requieren ambas confirmaciones.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: busy || r.confirmedBy(vm.userId!)
                              ? null
                              : () => _action(
                                  r,
                                  'confirm',
                                  finder
                                      ? '¿Ya entregaste el objeto?'
                                      : '¿Ya recibiste el objeto?',
                                  finder
                                      ? 'Registrarás que entregaste físicamente el objeto a este solicitante. Solo se resolverá cuando ambos confirmen.'
                                      : 'Registrarás que recibiste físicamente el objeto. Solo se resolverá cuando ambos confirmen.',
                                  finder
                                      ? 'Confirmar entrega'
                                      : 'Confirmar recepción',
                                ),
                          icon: const Icon(Icons.handshake_outlined),
                          label: Text(
                            finder
                                ? 'Confirmar que entregué'
                                : 'Confirmar que recibí',
                          ),
                        ),
                        if (finder && !r.hasConfirmation)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => _action(
                                    r,
                                    'close',
                                    '¿Cerrar conversación?',
                                    'Se conservará el historial y no se confirmará una devolución.',
                                    'Cerrar conversación',
                                  ),
                            child: const Text('Cerrar sin devolución'),
                          ),
                      ],
                      if (!finder && r.active && !r.hasConfirmation)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _action(
                                  r,
                                  'cancel',
                                  '¿Cancelar solicitud?',
                                  'Se conservará en tu historial. Si hay un chat abierto, quedará cerrado.',
                                  'Cancelar solicitud',
                                ),
                          child: const Text('Cancelar solicitud'),
                        ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: busy ? null : () => _safety(r, true),
                            icon: const Icon(Icons.block_outlined),
                            label: Text(
                              vm.blocked.contains(r.peer(vm.userId!))
                                  ? 'Desbloquear participante'
                                  : 'Bloquear participante',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: busy ? null : () => _safety(r, false),
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Reportar abuso'),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        'Historial',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      FutureBuilder<List<RecoveryEvent>>(
                        key: ValueKey('$_session/${r.version}'),
                        future: _history,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return TextButton(
                              onPressed: () => setState(() => _version = null),
                              child: const Text('Reintentar historial'),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: LinearProgressIndicator(),
                            );
                          }
                          return Column(
                            children: [
                              for (final e in snapshot.data!)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(e.label),
                                  subtitle: Text(
                                    Formatters.dateTime(e.createdAt.toLocal()),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
