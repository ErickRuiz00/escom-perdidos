import 'package:geolocator/geolocator.dart';

import '../../core/constants/escom.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  double get distanceToEscom =>
      haversineMeters(latitude, longitude, Escom.latitude, Escom.longitude);

  bool get insideCampus => distanceToEscom <= Escom.campusRadiusMeters;
}

/// Ubicación GPS opcional (RF3) para marcar dónde se perdió/encontró algo.
class LocationService {
  Future<GeoPoint> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PermissionException('Activa el GPS para usar tu ubicación.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const PermissionException('Se necesita permiso de ubicación.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PermissionException(
        'El permiso de ubicación está bloqueado. Actívalo en Ajustes.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      throw AppException('No se pudo obtener tu ubicación. Intenta al aire libre.',
          cause: e);
    }
  }
}
