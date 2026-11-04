import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../auth/auth_widgets.dart';
import '../widgets/common.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await context
        .read<ProfileViewModel>()
        .changePassword(_current.text, _next.text);
    if (!mounted) return;
    if (error != null) {
      showSnack(context, error, error: true);
    } else {
      showSnack(context, 'Contraseña actualizada');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<ProfileViewModel>().saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedContent(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PasswordField(
                  controller: _current,
                  label: 'Contraseña actual',
                  validator: (v) => Validators.required(v, field: 'La contraseña'),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _next,
                  label: 'Nueva contraseña',
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirmar nueva contraseña',
                  validator: Validators.confirmPassword(() => _next.text),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 24),
                LoadingButton(label: 'Actualizar', loading: saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
