import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'auth_widgets.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _boleta = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _boleta, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (context.read<AuthViewModel>().busy) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthViewModel>().register(
      name: _name.text,
      email: _email.text,
      password: _password.text,
      boleta: _boleta.text,
    );
    // AuthGate retira toda la pila al autenticarse.
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return AuthScaffold(
      showBack: true,
      title: 'Crear cuenta',
      subtitle: 'Tus cosas, más cerca de volver a ti.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErrorBanner(message: vm.error),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: Validators.name,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  hintText: 'tu@alumno.ipn.mx',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _boleta,
                textInputAction: TextInputAction.next,
                validator: Validators.boleta,
                decoration: const InputDecoration(
                  labelText: 'Boleta (opcional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                validator: Validators.password,
                newPassword: true,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirm,
                label: 'Confirmar contraseña',
                newPassword: true,
                validator: Validators.confirmPassword(() => _password.text),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Crear cuenta',
                loading: vm.busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 20),
              AccountLink(
                prompt: '¿Ya tienes cuenta?',
                label: 'Inicia sesión',
                onPressed: vm.busy
                    ? null
                    : () {
                        context.read<AuthViewModel>().clearError();
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
