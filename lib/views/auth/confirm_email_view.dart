import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/common.dart';
import 'auth_widgets.dart';

class ConfirmEmailView extends StatefulWidget {
  const ConfirmEmailView({super.key, this.email = ''});
  final String email;

  @override
  State<ConfirmEmailView> createState() => _ConfirmEmailViewState();
}

class _ConfirmEmailViewState extends State<ConfirmEmailView> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthViewModel>().confirmEmail(_email.text, _code.text);
  }

  Future<void> _resend() async {
    if (Validators.email(_email.text) != null) {
      showSnack(context, 'Escribe un correo electrónico válido.', error: true);
      return;
    }
    final ok = await context.read<AuthViewModel>().resendConfirmation(
      _email.text,
    );
    if (ok && mounted) {
      showSnack(context, vmMessage(context));
    }
  }

  String vmMessage(BuildContext context) =>
      context.read<AuthViewModel>().emailOtpEnabled
      ? 'Si tu cuenta necesita confirmación, recibirás otro código.'
      : 'Si tu cuenta necesita confirmación, recibirás otro enlace por correo.';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return AuthScaffold(
      showBack: true,
      title: 'Confirma tu correo',
      subtitle: vm.emailOtpEnabled
          ? 'Escribe el código que recibiste por correo. Revisa también spam.'
          : 'Abre el enlace de confirmación que recibiste por correo y después '
                'inicia sesión. Revisa también la carpeta de spam.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorBanner(message: vm.error),
            if (vm.notice case final notice?)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(notice),
              ),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 14),
            if (vm.emailOtpEnabled) ...[
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                validator: Validators.resetCode,
                maxLength: 6,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _confirm(),
                decoration: const InputDecoration(
                  labelText: 'Código de confirmación',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Confirmar correo',
                loading: vm.busy,
                onPressed: _confirm,
              ),
            ],
            TextButton(
              onPressed: vm.busy ? null : _resend,
              child: Text(
                vm.emailOtpEnabled ? 'Reenviar código' : 'Reenviar enlace',
              ),
            ),
            TextButton(
              onPressed: vm.busy
                  ? null
                  : () {
                      vm.clearError();
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
              child: const Text('Volver a iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
