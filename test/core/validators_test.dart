import 'package:escom_perdidos/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('correo', () {
    expect(Validators.email('alumno@alumno.ipn.mx'), isNull);
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('sin-arroba'), isNotNull);
  });

  test('contraseña requiere 8 caracteres con letras y números', () {
    expect(Validators.password('Escom2026'), isNull);
    expect(Validators.password('corta1'), isNotNull);
    expect(Validators.password('soloLetras'), isNotNull);
    expect(Validators.password('12345678'), isNotNull);
  });

  test('confirmación de contraseña', () {
    final validator = Validators.confirmPassword(() => 'Escom2026');
    expect(validator('Escom2026'), isNull);
    expect(validator('Escom2027'), isNotNull);
  });

  test('boleta es opcional pero debe tener formato IPN', () {
    expect(Validators.boleta(''), isNull);
    expect(Validators.boleta('2021630796'), isNull);
    expect(Validators.boleta('pe12345678'), isNull);
    expect(Validators.boleta('123'), isNotNull);
  });

  test('título y descripción del reporte', () {
    expect(Validators.title('Termo'), isNull);
    expect(Validators.title('abc'), isNotNull);
    expect(Validators.title('x' * 61), isNotNull);
    expect(Validators.description('Termo negro con stickers'), isNull);
    expect(Validators.description('corto'), isNotNull);
  });

  test('código de recuperación de 6 dígitos', () {
    expect(Validators.resetCode('123456'), isNull);
    expect(Validators.resetCode('12345'), isNotNull);
    expect(Validators.resetCode('abcdef'), isNotNull);
  });
}
