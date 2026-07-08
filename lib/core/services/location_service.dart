import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Demande la permission et retourne la position actuelle
 Future<Position?> getCurrentPosition() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  LocationPermission permission = await Geolocator.checkPermission();
  
  // Si denied, on redemande
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return null;
  }
  
  if (permission == LocationPermission.deniedForever) return null;

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15), // augmente le timeout
      ),
    );
  } catch (e) {
    // Fallback : dernière position connue
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

Future<String?> getLocationLabel(double lat, double lon) async {
  try {
    final placemarks = await placemarkFromCoordinates(lat, lon);
    if (placemarks.isEmpty) return null;
    final place = placemarks.first;
    
    // Ex: "Bandol, Rue du Port"
    final parts = [
      if (place.locality?.isNotEmpty == true) place.locality,
      if (place.thoroughfare?.isNotEmpty == true) place.thoroughfare,
    ];
    return parts.isNotEmpty ? parts.join(', ') : place.country;
  } catch (e) {
    return null;
  }
}

}

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
