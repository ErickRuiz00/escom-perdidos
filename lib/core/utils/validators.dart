/// Validaciones de formularios. Devuelven `null` si el valor es válido o el
/// mensaje a mostrar debajo del campo.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _boleta = RegExp(r'^(\d{10}|[A-Z]{2}\d{8})$');
  static final _phone = RegExp(r'^\d{10}$');

  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  static String? name(String? value) {
    final error = required(value, field: 'El nombre');
    if (error != null) return error;
    if (value!.trim().length < 3) return 'Escribe al menos 3 caracteres';
    return null;
  }

  static String? email(String? value) {
    final error = required(value, field: 'El correo');
    if (error != null) return error;
    if (!_email.hasMatch(value!.trim())) return 'Correo no válido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es obligatoria';
    if (value.length < 8) return 'Mínimo 8 caracteres';
    if (!value.contains(RegExp(r'[A-Za-z]')) || !value.contains(RegExp(r'\d'))) {
      return 'Debe incluir letras y números';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Confirma la contraseña';
      if (value != original()) return 'Las contraseñas no coinciden';
      return null;
    };
  }

  /// Boleta IPN: 10 dígitos (p. ej. 2021630796) o 2 letras + 8 dígitos (PE12345678).
  /// Es opcional.
  static String? boleta(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_boleta.hasMatch(value.trim().toUpperCase())) {
      return 'Boleta no válida (10 dígitos)';
    }
    return null;
  }

  /// Teléfono opcional a 10 dígitos.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_phone.hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''))) {
      return 'Teléfono a 10 dígitos';
    }
    return null;
  }

  static String? title(String? value) {
    final error = required(value, field: 'El título');
    if (error != null) return error;
    final length = value!.trim().length;
    if (length < 4) return 'Describe el objeto con al menos 4 caracteres';
    if (length > 60) return 'Máximo 60 caracteres';
    return null;
  }

  static String? description(String? value) {
    final error = required(value, field: 'La descripción');
    if (error != null) return error;
    final length = value!.trim().length;
    if (length < 10) return 'Agrega más detalles (mínimo 10 caracteres)';
    if (length > 500) return 'Máximo 500 caracteres';
    return null;
  }

  static String? resetCode(String? value) {
    if (value == null || !RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'El código tiene 6 dígitos';
    }
    return null;
  }
}
