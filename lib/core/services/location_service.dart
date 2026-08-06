import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum LocationFailureType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  positionUnavailable,
}

class LocationFailure implements Exception {
  final LocationFailureType type;

  const LocationFailure(this.type);

  @override
  String toString() => 'LocationFailure($type)';
}

class LocationService {
  Future<Position?> getCurrentPosition() async {
    try {
      return await getCurrentPositionOrThrow();
    } on LocationFailure {
      return null;
    }
  }

  Future<Position> getCurrentPositionOrThrow() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(LocationFailureType.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(LocationFailureType.permissionDenied);
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(LocationFailureType.permissionDeniedForever);
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) return lastKnownPosition;

      throw const LocationFailure(LocationFailureType.positionUnavailable);
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<String?> getLocationLabel(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;

      final parts = [
        if (place.locality?.isNotEmpty == true) place.locality,
        if (place.thoroughfare?.isNotEmpty == true) place.thoroughfare,
      ];
      return parts.isNotEmpty ? parts.join(', ') : place.country;
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
