import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/escom.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/report.dart';
import '../../data/services/media_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/report_form_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../auth/auth_widgets.dart';
import '../widgets/common.dart';
import '../widgets/publication_notice.dart';

class ReportFormView extends StatelessWidget {
  const ReportFormView({super.key, this.original});
  final Report? original;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => ReportFormViewModel(
      reports: context.read<ReportsViewModel>(),
      media: context.read<MediaService>(),
      author: context.read<AuthViewModel>().user!,
      original: original,
    ),
    child: _ReportForm(original: original),
  );
}

class _ReportForm extends StatefulWidget {
  const _ReportForm({this.original});
  final Report? original;
  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.original?.title);
  late final _description = TextEditingController(
    text: widget.original?.description,
  );
  bool _confirming = false;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vm = context.read<ReportFormViewModel>();
    if (vm.saving || vm.picking || _confirming) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (vm.custody == ItemCustody.prefecture &&
        widget.original?.custody != ItemCustody.prefecture) {
      _confirming = true;
      final ok = await confirmAction(
        context,
        title: '¿Lo entregaste a Prefectura?',
        message:
            'Registrarás tu declaración de entrega y dejarás de coordinar la devolución. Esto no confirma que Prefectura lo recibió ni que volvió a su dueño.',
        confirmLabel: 'Sí, lo entregué',
        destructive: false,
      );
      _confirming = false;
      if (!ok || !mounted) return;
    }
    final error = await vm.save(
      title: _title.text,
      description: _description.text,
    );
    if (!mounted) return;
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    final saved = vm.savedReport;
    if (saved == null) return;
    final open = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Center(child: BrandDialogLogo()),
        scrollable: true,
        title: Text(vm.isEditing ? 'Cambios guardados' : 'Hallazgo publicado'),
        content: Text(
          vm.isEditing
              ? 'La publicación ya muestra tus cambios.'
              : 'Tu hallazgo ya está disponible para la comunidad de ESCOM.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Listo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Ver publicación'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, open == true ? saved.id : null);
  }

  Future<void> _pickPhoto() async {
    final source = await pickPhotoSource(context);
    if (source == null || !mounted) return;
    final error = await context.read<ReportFormViewModel>().pickPhoto(
      fromCamera: source,
    );
    if (error != null && mounted) showSnack(context, error, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportFormViewModel>();
    return PopScope(
      canPop: !vm.saving && !vm.picking,
      child: Scaffold(
        appBar: AppBar(
          title: Text(vm.isEditing ? 'Editar hallazgo' : 'Publicar hallazgo'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ConstrainedContent(
                  maxWidth: 640,
                  child: AbsorbPointer(
                    absorbing: vm.saving || vm.picking,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PublicationNotice(),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (vm.photoPath != null ||
                                    vm.photoObjectPath != null)
                                  ReportImage(
                                    path: vm.photoPath,
                                    storagePath: vm.photoObjectPath,
                                    category: vm.category,
                                    decodeWidth: 640,
                                  )
                                else
                                  Material(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    child: InkWell(
                                      onTap: _pickPhoto,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_outlined,
                                            size: 40,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text('Agregar foto opcional'),
                                          const Text(
                                            'JPEG, PNG o WebP · hasta 3 MiB',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (vm.photoPath != null ||
                                    vm.photoObjectPath != null)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: IconButton.filledTonal(
                                      tooltip: 'Quitar foto',
                                      onPressed: vm.removePhoto,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ),
                                if (vm.picking)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (vm.photoPath != null || vm.photoObjectPath != null)
                          TextButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Cambiar foto'),
                          ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _title,
                          maxLength: 60,
                          validator: Validators.title,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: '¿Qué objeto es?',
                            hintText: 'Ej. Termo azul',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _description,
                          maxLength: 500,
                          minLines: 3,
                          maxLines: 6,
                          validator: Validators.description,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Color, marca, características…',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ItemCategory>(
                          value: vm.category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                          ),
                          items: [
                            for (final c in ItemCategory.values)
                              DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) vm.setCategory(value);
                          },
                        ),
                        if (vm.category == ItemCategory.documents)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Antes de fotografiar una credencial o documento, cubre nombre, boleta, rostro, códigos y cualquier dato personal.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: vm.place,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Zona de ESCOM',
                          ),
                          items: [
                            for (final zone in Escom.locations)
                              DropdownMenuItem(
                                value: zone,
                                child: Text(
                                  zone,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) vm.setPlace(value);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ItemCustody>(
                          value: vm.custody,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Custodia del objeto',
                          ),
                          items: [
                            for (final c in ItemCustody.values)
                              DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c == ItemCustody.student
                                      ? 'Lo tengo yo'
                                      : 'Lo entregué a Prefectura',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged:
                              widget.original?.custody == ItemCustody.prefecture
                              ? null
                              : (value) {
                                  if (value != null) vm.setCustody(value);
                                },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: vm.eventDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null && mounted) vm.setEventDate(date);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha del hallazgo',
                              suffixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                            child: Text(Formatters.date(vm.eventDate)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        LoadingButton(
                          label: vm.isEditing
                              ? 'Guardar cambios'
                              : 'Publicar hallazgo',
                          loading: vm.saving,
                          onPressed: _save,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No incluyas teléfonos, correos, boletas ni otros datos personales en la foto o descripción.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
