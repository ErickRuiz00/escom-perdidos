import 'package:flutter/material.dart';

/// Datos fijos del dominio: el campus de la ESCOM - IPN.
class Escom {
  Escom._();

  /// Coordenadas aproximadas del centro del campus (Zacatenco, CDMX).
  static const double latitude = 19.504507;
  static const double longitude = -99.146911;

  /// Radio (en metros) dentro del cual consideramos que el usuario está en la escuela.
  static const double campusRadiusMeters = 350;

  static const String timezone = 'America/Mexico_City';

  /// Lugares del campus donde suelen perderse o encontrarse objetos.
  static const List<String> locations = [
    'Edificio de Gobierno',
    'Edificio 1',
    'Edificio 2',
    'Edificio 3',
    'Edificio 4',
    'Biblioteca',
    'Cafetería',
    'Laboratorios de cómputo',
    'Auditorio',
    'Canchas',
    'Explanada',
    'Estacionamiento',
    'Baños',
    'Otro',
  ];
}

/// Categorías de objetos.
enum ItemCategory {
  electronics('Electrónica', Icons.devices_other_rounded),
  documents('Credenciales y documentos', Icons.badge_rounded),
  keys('Llaves', Icons.key_rounded),
  clothing('Ropa y accesorios', Icons.checkroom_rounded),
  supplies('Útiles y libros', Icons.menu_book_rounded),
  bottles('Termos y botellas', Icons.local_drink_rounded),
  bags('Mochilas y estuches', Icons.backpack_rounded),
  other('Otros', Icons.category_rounded);

  const ItemCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static ItemCategory fromName(String name) =>
      values.firstWhere((c) => c.name == name, orElse: () => other);
}

/// Un reporte puede ser de algo que se perdió o de algo que se encontró.
enum ReportType {
  lost('Perdido', Icons.search_rounded),
  found('Encontrado', Icons.volunteer_activism_rounded);

  const ReportType(this.label, this.icon);
  final String label;
  final IconData icon;

  static ReportType fromName(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => lost);
}

enum ReportStatus {
  active('Activo'),
  resolved('Resuelto');

  const ReportStatus(this.label);
  final String label;

  static ReportStatus fromName(String name) =>
      values.firstWhere((s) => s.name == name, orElse: () => active);
}
