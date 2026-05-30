import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Timer? _timer;

  static const LatLng _parral = LatLng(26.9314, -105.6668);

  @override
  void initState() {
    super.initState();
    _cargarCamiones();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _cargarCamiones());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _cargarCamiones() async {
    try {
      final response = await http.get(Uri.parse('https://fakebus-api-production.up.railway.app'));
      if (response.statusCode == 200) {
        final camiones = jsonDecode(response.body);
        Set<Marker> markers = {};
        for (var c in camiones) {
          if (c['latitud'] != null && 
              c['longitud'] != null && 
              c['latitud'].toString() != 'null' &&
              c['longitud'].toString() != 'null') {
            final pasajeros = c['pasajeros_actuales'] as int;
            final capacidad = c['capacidad_total'] as int;
            final porcentaje = pasajeros / capacidad;
            final estado = porcentaje < 0.5 ? 'Disponible' : porcentaje < 0.85 ? 'Moderado' : 'Saturado';

            markers.add(Marker(
              markerId: MarkerId(c['id_camion'].toString()),
              position: LatLng(
                double.parse(c['latitud'].toString()),
                double.parse(c['longitud'].toString()),
              ),
              infoWindow: InfoWindow(
                title: c['modelo'],
                snippet: '$estado - $pasajeros/$capacidad pasajeros',
              ),
            ));
          }
        }
        setState(() => _markers = markers);
      }
    } catch (e) {
      debugPrint('Error cargando camiones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text('Mapa de Camiones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: _parral, zoom: 13),
        markers: _markers,
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}