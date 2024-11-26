import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const GoogleMapsRouteApp());
}

class GoogleMapsRouteApp extends StatelessWidget {
  const GoogleMapsRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Route App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  // Initial camera position (centered on Mexico City)
  static const LatLng _initialPosition = LatLng(19.4326, -99.1332);

  // Current location marker
  LatLng? _currentLocation;

  // Destination marker
  LatLng? _destinationMarker;

  // Set of markers
  final Set<Marker> _markers = {};

  // Set of polylines (route)
  final Set<Polyline> _polylines = {};

  // Dio client for network requests
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);

        // Add current location marker
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: _currentLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Mi Ubicación'),
          ),
        );

        // Move camera to current location
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 15),
        );
      });
    } catch (e) {
      print("Error obteniendo la ubicación: $e");
    }
  }

  // Draw route between two points
  Future<void> _drawRoute() async {
    if (_currentLocation == null || _destinationMarker == null) return;

    try {
      // Construir la URL para la solicitud de direcciones de Google Maps
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${_currentLocation!.latitude},${_currentLocation!.longitude}'
          '&destination=${_destinationMarker!.latitude},${_destinationMarker!.longitude}'
          '&key=AIzaSyAiJofFoIKKglajZx-J0TKd7ppIKHjxfBA';

      // Realizar la solicitud con Dio
      final Response response = await _dio.get(url);

      // Verificar si la respuesta es exitosa
      if (response.statusCode == 200) {
        // Decodificar la respuesta
        final Map<String, dynamic> data = response.data;

        // Verificar si hay rutas disponibles
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          // Obtener los puntos de la ruta
          final List<LatLng> routePoints =
              _decodePolyline(data['routes'][0]['overview_polyline']['points']);

          setState(() {
            _polylines.clear(); // Limpiar rutas previas
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });
        } else {
          _showErrorSnackbar('No se encontró una ruta');
        }
      } else {
        _showErrorSnackbar('Error al obtener la ruta');
      }
    } catch (e) {
      _showErrorSnackbar('Error de conexión: $e');
    }
  }

  // Método para decodificar el polyline
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int result = 1;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += b << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      result = 1;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += b << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 100000.0, lng / 100000.0));
    }

    return points;
  }

  // Método para mostrar mensajes de error
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta en Google Maps'),
      ),
      body: GoogleMap(
        onMapCreated: (controller) {
          mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 10,
        ),
        markers: _markers,
        polylines: _polylines,
        onTap: (LatLng location) {
          // Add destination marker when tapping on the map
          setState(() {
            // Remove previous destination marker if exists
            _markers.removeWhere(
                (marker) => marker.markerId.value == 'destination');

            // Add new destination marker
            _markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: location,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: const InfoWindow(title: 'Destino'),
              ),
            );

            _destinationMarker = location;
          });

          // Draw route when destination is set
          _drawRoute();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        tooltip: 'Mi Ubicación',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
