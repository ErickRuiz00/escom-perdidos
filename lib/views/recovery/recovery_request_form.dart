import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/escom.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/report.dart';
import '../../viewmodels/recovery_viewmodel.dart';
import '../widgets/common.dart';
import 'recovery_request_view.dart';

class RecoveryRequestForm extends StatefulWidget {
  const RecoveryRequestForm({super.key, required this.report});
  final Report report;
  @override
  State<RecoveryRequestForm> createState() => _RecoveryRequestFormState();
}

class _RecoveryRequestFormState extends State<RecoveryRequestForm> {
  final _form = GlobalKey<FormState>();
  final _evidence = TextEditingController();
  final _id = const Uuid().v4();
  late final int _session;
  bool _sending = false;
  @override
  void initState() {
    super.initState();
    _session = context.read<RecoveryViewModel>().sessionRevision;
  }

  @override
  void dispose() {
    _evidence.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.watch<RecoveryViewModel>().sessionRevision != _session &&
        _evidence.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _evidence.clear();
      });
    }
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final ok = await confirmAction(
        context,
        title: '¿Enviar solicitud privada?',
        message:
            'Solo tú y el encontrador podrán ver las características que describes. Enviar la solicitud no confirma que seas el propietario.',
        confirmLabel: 'Enviar solicitud',
        destructive: false,
      );
      if (!mounted || !ok) return;
      final saved = await context.read<RecoveryViewModel>().create(
        id: _id,
        itemId: widget.report.id,
        evidence: _evidence.text,
        session: _session,
      );
      if (mounted) {
        showSnack(context, 'Solicitud enviada');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => RecoveryRequestView(requestId: saved.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, userMessageFor(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecoveryViewModel>();
    final r = widget.report;
    final allowed =
        vm.userId != null &&
        vm.sessionRevision == _session &&
        vm.userId != r.userId &&
        r.isActive &&
        r.custody == ItemCustody.student;
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar recuperación')),
      body: SafeArea(
        top: false,
        child: !allowed
            ? const SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Solicitud no disponible',
                  message:
                      'La sesión o disponibilidad del hallazgo cambió. Vuelve a su detalle.',
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedContent(
                  maxWidth: 640,
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: ListTile(
                            leading: Icon(r.category.icon),
                            title: Text(r.title),
                            subtitle: Text(
                              '${r.category.label} · ${r.location}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Cuéntale lo que solo tú conoces',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Describe marcas, contenido o características que no aparecen en la publicación. No compartas contraseñas, datos bancarios ni fotografías de documentos. Esta información es privada.',
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          key: const Key('recovery-evidence'),
                          controller: _evidence,
                          enabled: !_sending,
                          minLines: 4,
                          maxLines: 8,
                          maxLength: 1200,
                          decoration: const InputDecoration(
                            labelText: 'Características privadas',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) => (value?.trim().length ?? 0) < 20
                              ? 'Escribe al menos 20 caracteres.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _sending ? null : _send,
                          icon: Icon(
                            _sending
                                ? Icons.hourglass_top_rounded
                                : Icons.send_outlined,
                          ),
                          label: Text(
                            _sending ? 'Enviando…' : 'Enviar solicitud',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
