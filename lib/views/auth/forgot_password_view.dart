import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/common.dart';
import 'auth_widgets.dart';

/// Recuperación de contraseña en dos pasos: pedir código y restablecer.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    if (!_codeSent) {
      final ok = await vm.requestPasswordReset(_email.text);
      if (ok && mounted) {
        setState(() => _codeSent = true);
        showSnack(context, 'Te enviamos el código en una notificación.');
      }
      return;
    }
    final ok = await vm.resetPassword(
      email: _email.text,
      code: _code.text,
      newPassword: _password.text,
    );
    if (ok && mounted) {
      showSnack(context, 'Contraseña actualizada. Ya puedes entrar.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return AuthScaffold(
      showBack: true,
      title: 'Recuperar contraseña',
      subtitle: _codeSent
          ? 'Escribe el código de 6 dígitos que recibiste y tu nueva contraseña.'
          : 'Te enviaremos un código para restablecerla.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorBanner(message: vm.error),
            TextFormField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: Validators.resetCode,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                label: 'Nueva contraseña',
                validator: Validators.password,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: 24),
            LoadingButton(
              label: _codeSent ? 'Restablecer contraseña' : 'Enviar código',
              loading: vm.busy,
              onPressed: _submit,
            ),
            if (_codeSent)
              TextButton(
                onPressed: vm.busy ? null : () => setState(() => _codeSent = false),
                child: const Text('Solicitar otro código'),
              ),
          ],
        ),
      ),
    );
  }
}
