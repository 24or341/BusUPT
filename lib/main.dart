import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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
  static const LatLng _initialPosition = LatLng(-18.00643, -70.22721);

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

  // Loading state
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Get current location
  // Reemplaza la función _getCurrentLocation para asignar coordenadas directamente
Future<void> _getCurrentLocation() async {
  try {
    // Coordenadas especificadas directamente (por ejemplo: Ciudad de México)
    _currentLocation = LatLng(-18.00643, -70.22721); // Latitud y Longitud deseadas

    setState(() {
      // Agregar marcador de la ubicación inicial
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Mi Ubicación'),
        ),
      );

      // Mover la cámara a la ubicación inicial
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      );
    });
  } catch (e) {
    print("Error configurando la ubicación inicial: $e");
  }
}


  // Draw route between two points
 Future<void> _drawRoute() async {
  if (_currentLocation == null || _destinationMarker == null) {
    _showErrorSnackbar('Por favor, selecciona un destino en el mapa.');
    return;
  }

  setState(() {
    _isLoadingRoute = true;
  });

  try {
    final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_currentLocation!.latitude},${_currentLocation!.longitude}'
        '&destination=${_destinationMarker!.latitude},${_destinationMarker!.longitude}'
        '&mode=driving'
        '&key=AIzaSyAiJofFoIKKglajZx-J0TKd7ppIKHjxfBA';

    final Response response = await _dio.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = response.data;

      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final List<LatLng> routePoints =
            _decodePolyline(data['routes'][0]['overview_polyline']['points']);

        setState(() {
          _polylines.clear(); // Clear existing routes
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: Colors.blue,
              width: 5,
            ),
          );
        });

        // Adjust camera to route
        _adjustCameraToRoute(routePoints);
      } else {
        _showErrorSnackbar('No se encontró una ruta válida.');
      }
    } else {
      _showErrorSnackbar('Error al obtener la ruta del servidor.');
    }
  } catch (e) {
    _showErrorSnackbar('Error de conexión: $e');
  } finally {
    setState(() {
      _isLoadingRoute = false;
    });
  }
}


  // Decode polyline to LatLng points
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

  // Adjust camera to show the entire route
  void _adjustCameraToRoute(List<LatLng> points) {
    if (points.isNotEmpty) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
          points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
          points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
        ),
      );

      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  // Show error snackbar
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
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
            },
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 10,
            ),
            markers: _markers,
            polylines: _polylines,
            onTap: (LatLng location) {
              setState(() {
                _markers.removeWhere(
                    (marker) => marker.markerId.value == 'destination');
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

              _drawRoute();
            },
          ),
          if (_isLoadingRoute)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        tooltip: 'Mi Ubicación',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
