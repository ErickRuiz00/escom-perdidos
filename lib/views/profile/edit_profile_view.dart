import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../auth/auth_widgets.dart';
import '../widgets/common.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final ProfileViewModel _vm = context.read<ProfileViewModel>();
  late final _name = TextEditingController(text: _vm.user.name);
  late final _boleta = TextEditingController(text: _vm.user.boleta);
  late final _phone = TextEditingController(text: _vm.user.phone);

  @override
  void dispose() {
    _name.dispose();
    _boleta.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await _vm.saveProfile(
      name: _name.text,
      boleta: _boleta.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    if (error != null) {
      showSnack(context, error, error: true);
    } else {
      showSnack(context, 'Perfil actualizado');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<ProfileViewModel>().saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Datos personales')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedContent(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: _vm.user.email,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _boleta,
                  validator: Validators.boleta,
                  decoration: const InputDecoration(
                    labelText: 'Boleta',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                LoadingButton(label: 'Guardar', loading: saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
