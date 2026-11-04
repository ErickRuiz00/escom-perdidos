import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/escom.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/report.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/report_form_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../auth/auth_widgets.dart';
import '../widgets/common.dart';

/// Formulario para crear (o editar, si recibe [original]) un reporte.
class ReportFormView extends StatelessWidget {
  const ReportFormView({super.key, this.original, this.initialType});

  final Report? original;
  final ReportType? initialType;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReportFormViewModel(
        reports: context.read<ReportsViewModel>(),
        media: context.read<MediaService>(),
        location: context.read<LocationService>(),
        author: context.read<AuthViewModel>().user!,
        original: original,
        initialType: initialType,
      ),
      child: _ReportForm(original: original),
    );
  }
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
  late final _description = TextEditingController(text: widget.original?.description);
  late final _contact = TextEditingController(text: widget.original?.contact);
  bool _saved = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showSnack(context, 'Revisa los campos marcados en rojo.', error: true);
      return;
    }
    final vm = context.read<ReportFormViewModel>();
    final error = await vm.save(
      title: _title.text,
      description: _description.text,
      contact: _contact.text,
    );
    if (!mounted) return;
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    _saved = true;
    showSnack(context, vm.isEditing ? 'Cambios guardados' : 'Reporte publicado');
    Navigator.pop(context);
  }

  Future<void> _pickPhoto() async {
    final fromCamera = await pickPhotoSource(context);
    if (fromCamera == null || !mounted) return;
    final error =
        await context.read<ReportFormViewModel>().pickPhoto(fromCamera: fromCamera);
    if (error != null && mounted) showSnack(context, error, error: true);
  }

  Future<void> _locate() async {
    final error = await context.read<ReportFormViewModel>().captureLocation();
    if (error != null && mounted) showSnack(context, error, error: true);
  }

  Future<void> _pickDate(ReportFormViewModel vm) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: vm.eventDate,
      firstDate: now.subtract(const Duration(days: 180)),
      lastDate: now,
    );
    if (date != null) vm.setEventDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportFormViewModel>();
    final theme = Theme.of(context);
    final lost = vm.type == ReportType.lost;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_saved) vm.discard();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(vm.isEditing ? 'Editar reporte' : 'Nuevo reporte')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ConstrainedContent(
                  maxWidth: 640,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<ReportType>(
                        segments: [
                          for (final t in ReportType.values)
                            ButtonSegment(value: t, icon: Icon(t.icon), label: Text(t.label)),
                        ],
                        selected: {vm.type},
                        onSelectionChanged: (s) => vm.setType(s.first),
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor:
                              AppTheme.typeColor(vm.type).withValues(alpha: 0.15),
                          selectedForegroundColor: AppTheme.typeColor(vm.type),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _PhotoField(
                        path: vm.photoPath,
                        category: vm.category,
                        onPick: _pickPhoto,
                        onRemove: vm.removePhoto,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _title,
                        maxLength: 60,
                        textCapitalization: TextCapitalization.sentences,
                        validator: Validators.title,
                        decoration: InputDecoration(
                          labelText: '¿Qué objeto es?',
                          hintText: lost ? 'Ej. Audífonos inalámbricos' : 'Ej. Credencial IPN',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        maxLength: 500,
                        minLines: 3,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        validator: Validators.description,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          hintText: 'Color, marca, señas particulares…',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ItemCategory>(
                        value: vm.category,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: [
                          for (final c in ItemCategory.values)
                            DropdownMenuItem(
                              value: c,
                              child: Row(children: [
                                Icon(c.icon, size: 20),
                                const SizedBox(width: 10),
                                Flexible(child: Text(c.label, overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                        ],
                        onChanged: (c) => vm.setCategory(c!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: vm.place,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: lost ? '¿Dónde lo perdiste?' : '¿Dónde lo encontraste?',
                        ),
                        items: [
                          for (final l in Escom.locations)
                            DropdownMenuItem(value: l, child: Text(l)),
                        ],
                        onChanged: (l) => vm.setPlace(l!),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _pickDate(vm),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            suffixIcon: Icon(Icons.calendar_month_rounded),
                          ),
                          child: Text(Formatters.date(vm.eventDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LocationField(
                        point: vm.point,
                        loading: vm.locating,
                        onLocate: _locate,
                        onClear: vm.clearLocation,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contact,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: 'Contacto (opcional)',
                          hintText: lost
                              ? 'Teléfono o correo'
                              : 'Ej. Lo entregué en Gobierno',
                          prefixIcon: const Icon(Icons.contact_phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LoadingButton(
                        label: vm.isEditing ? 'Guardar cambios' : 'Publicar reporte',
                        loading: vm.saving,
                        onPressed: _save,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No publiques datos sensibles como números de tarjeta o CURP.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
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

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.path,
    required this.category,
    required this.onPick,
    required this.onRemove,
  });

  final String? path;
  final ItemCategory category;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          child: InkWell(
            onTap: onPick,
            child: path == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, size: 40, color: colors.primary),
                      const SizedBox(height: 8),
                      const Text('Agregar foto (cámara o galería)'),
                    ],
                  )
                : Stack(fit: StackFit.expand, children: [
                    ReportImage(path: path, category: category, decodeWidth: 640),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Quitar foto',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onRemove,
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.point,
    required this.loading,
    required this.onLocate,
    required this.onClear,
  });

  final GeoPoint? point;
  final bool loading;
  final VoidCallback onLocate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = point;
    final subtitle = p == null
        ? 'Opcional: guarda el punto exacto con el GPS'
        : p.insideCampus
            ? 'Dentro del campus · ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'
            : 'A ${Formatters.distance(p.distanceToEscom)} de la ESCOM';
    return Card(
      child: ListTile(
        leading: loading
            ? const SizedBox.square(
                dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Icon(p == null ? Icons.location_searching_rounded : Icons.my_location_rounded),
        title: Text(p == null ? 'Ubicación GPS' : 'Ubicación guardada'),
        subtitle: Text(subtitle),
        trailing: p == null
            ? TextButton(onPressed: loading ? null : onLocate, child: const Text('Usar'))
            : IconButton(
                tooltip: 'Quitar ubicación',
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
      ),
    );
  }
}
