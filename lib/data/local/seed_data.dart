import 'package:sqflite/sqflite.dart';

import '../../core/constants/escom.dart';
import '../models/report.dart';
import 'app_database.dart';

/// Datos de ejemplo para que la app no se vea vacía en la primera ejecución.
/// Los publica una cuenta de sistema que no puede iniciar sesión.
class SeedData {
  SeedData._();

  static const systemUserId = 'system-escom';

  static Future<void> ensure(AppDatabase database) async {
    final db = await database.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users WHERE id = ?', [systemUserId]),
    );
    if (count != null && count > 0) return;

    final now = DateTime.now();
    final batch = db.batch();
    batch.insert('users', {
      'id': systemUserId,
      'name': 'Coordinación ESCOM',
      'email': 'objetosperdidos@escom.ipn.mx',
      'provider': 'system',
      'created_at': now.millisecondsSinceEpoch,
    });

    final samples = <(ReportType, String, String, ItemCategory, String, int, String)>[
      (ReportType.found, 'Credencial IPN', 'Credencial de estudiante a nombre de "Ana L.", encontrada junto a las mesas.', ItemCategory.documents, 'Cafetería', 2, 'Entregada en Edificio de Gobierno, ventanilla 3'),
      (ReportType.found, 'Termo negro con stickers', 'Termo metálico negro con stickers de Linux y Python.', ItemCategory.bottles, 'Laboratorios de cómputo', 5, 'Se quedó con el técnico del laboratorio 2'),
      (ReportType.lost, 'Audífonos inalámbricos blancos', 'Estuche blanco, uno de los audífonos tiene una marca de plumón azul.', ItemCategory.electronics, 'Biblioteca', 26, 'objetosperdidos@escom.ipn.mx'),
      (ReportType.found, 'Llaves con llavero de Pikachu', 'Juego de 3 llaves con llavero amarillo.', ItemCategory.keys, 'Canchas', 30, 'Entregadas en Edificio de Gobierno'),
      (ReportType.lost, 'Calculadora Casio fx-991', 'Calculadora científica con nombre grabado en la tapa.', ItemCategory.supplies, 'Edificio 2', 50, 'objetosperdidos@escom.ipn.mx'),
      (ReportType.found, 'Sudadera guinda IPN', 'Sudadera talla M, olvidada en el salón 2105.', ItemCategory.clothing, 'Edificio 2', 72, 'Entregada en Edificio de Gobierno'),
    ];

    for (var i = 0; i < samples.length; i++) {
      final (type, title, description, category, location, hoursAgo, contact) = samples[i];
      final date = now.subtract(Duration(hours: hoursAgo));
      batch.insert(
        'reports',
        Report(
          id: 'seed-$i',
          userId: systemUserId,
          type: type,
          title: title,
          description: description,
          category: category,
          location: location,
          eventDate: date,
          status: ReportStatus.active,
          createdAt: date,
          updatedAt: date,
          contact: contact,
        ).toMap(),
      );
    }
    await batch.commit(noResult: true);
  }
}
