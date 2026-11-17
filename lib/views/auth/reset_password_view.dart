import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'auth_widgets.dart';

/// Entered only after Supabase has validated a password-recovery email link.
class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthViewModel>().finishPasswordRecovery(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return AuthScaffold(
      title: 'Nueva contraseña',
      subtitle: 'Elige una contraseña para volver a entrar a tu cuenta.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorBanner(message: vm.error),
            PasswordField(
              controller: _password,
              newPassword: true,
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirm,
              newPassword: true,
              label: 'Confirmar contraseña',
              validator: Validators.confirmPassword(() => _password.text),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: 'Guardar nueva contraseña',
              loading: vm.busy,
              onPressed: _save,
            ),
            TextButton(
              onPressed: vm.busy ? null : vm.cancelPasswordRecovery,
              child: const Text('Cancelar recuperación'),
            ),
          ],
        ),
      ),
    );
  }
}
