import '../../core/constants/escom.dart';

/// Reporte de un objeto perdido o encontrado dentro de la ESCOM.
class Report {
  const Report({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.eventDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.contact,
    this.authorName,
  });

  final String id;
  final String userId;
  final ReportType type;
  final String title;
  final String description;
  final ItemCategory category;

  /// Lugar del campus (ver [Escom.locations]).
  final String location;

  /// Cuándo se perdió / encontró el objeto.
  final DateTime eventDate;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoPath;
  final double? latitude;
  final double? longitude;

  /// Medio de contacto público (teléfono, correo o "entregado en Gobierno").
  final String? contact;

  /// Nombre del autor (se obtiene con un JOIN, no se guarda en la tabla).
  final String? authorName;

  bool get hasLocation => latitude != null && longitude != null;
  bool get isActive => status == ReportStatus.active;

  Report copyWith({
    ReportType? type,
    String? title,
    String? description,
    ItemCategory? category,
    String? location,
    DateTime? eventDate,
    ReportStatus? status,
    DateTime? updatedAt,
    String? photoPath,
    double? latitude,
    double? longitude,
    String? contact,
    bool clearPhoto = false,
    bool clearCoordinates = false,
  }) {
    return Report(
      id: id,
      userId: userId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      eventDate: eventDate ?? this.eventDate,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      contact: contact ?? this.contact,
      authorName: authorName,
    );
  }

  factory Report.fromMap(Map<String, Object?> map) {
    return Report(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: ReportType.fromName(map['type'] as String),
      title: map['title'] as String,
      description: map['description'] as String,
      category: ItemCategory.fromName(map['category'] as String),
      location: map['location'] as String,
      eventDate: DateTime.fromMillisecondsSinceEpoch(map['event_date'] as int),
      status: ReportStatus.fromName(map['status'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      photoPath: map['photo_path'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      contact: map['contact'] as String?,
      authorName: map['author_name'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'title': title.trim(),
        'description': description.trim(),
        'category': category.name,
        'location': location,
        'event_date': eventDate.millisecondsSinceEpoch,
        'status': status.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'photo_path': photoPath,
        'latitude': latitude,
        'longitude': longitude,
        'contact': contact?.trim(),
      };
}
