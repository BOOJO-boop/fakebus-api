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
  Set<Polyline> _polylines = {}; // 1. AGREGADO: Para pintar las líneas en el mapa
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

  // 2. AGREGADO: Función auxiliar para convertir el String de Railway (#4CAF50) a objeto Color
  Color _convertirHexAColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.green; // Color por defecto por seguridad
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _cargarCamiones() async {
    try {
      final response = await http.get(Uri.parse('https://fakebus-api-production.up.railway.app/camiones'));
      if (response.statusCode == 200) {
        final camiones = jsonDecode(response.body);
        Set<Marker> markers = {};
        Set<Polyline> polylines = {}; // Variable temporal para las líneas

        for (var c in camiones) {
          if (c['latitud'] != null && 
              c['longitud'] != null && 
              c['latitud'].toString() != 'null' &&
              c['longitud'].toString() != 'null') {
            
            final pasajeros = c['pasajeros_actuales'] as int;
            final capacidad = c['capacidad_total'] as int;
            final porcentaje = pasajeros / capacidad;
            final estado = porcentaje < 0.5 ? 'Disponible' : porcentaje < 0.85 ? 'Moderado' : 'Saturado';

            final posicionCamion = LatLng(
              double.parse(c['latitud'].toString()),
              double.parse(c['longitud'].toString()),
            );

            // Marcador original que ya tenías
            markers.add(Marker(
              markerId: MarkerId(c['id_camion'].toString()),
              position: posicionCamion,
              infoWindow: InfoWindow(
                title: c['modelo'],
                snippet: '$estado - $pasajeros/$capacidad pasajeros',
              ),
            ));

            // 3. AGREGADO: Si el camión trae coordenadas, trazamos su línea con su color correspondiente
            // Nota: Para pintar la ruta completa uniendo puntos, FastAPI te enviará una lista en 'puntos_ruta'.
            // Si tu API aún no maneja la lista, esto traza una línea base de seguridad.
            if (c['puntos_ruta'] != null) {
              List<LatLng> puntos = [];
              for (var p in c['puntos_ruta']) {
                puntos.add(LatLng(double.parse(p['latitud'].toString()), double.parse(p['longitud'].toString())));
              }
              polylines.add(Polyline(
                polylineId: PolylineId('linea_${c['id_camion']}'),
                points: puntos,
                color: _convertirHexAColor(c['color_hex']),
                width: 5,
              ));
            } else {
              // Si no hay lista de puntos de ruta guardada, une el centro de parral con el camión usando su color
              polylines.add(Polyline(
                polylineId: PolylineId('linea_directa_${c['id_camion']}'),
                points: [_parral, posicionCamion],
                color: _convertirHexAColor(c['color_hex']),
                width: 4,
              ));
            }
          }
        }
        
        // Actualizamos de forma segura el estado de marcadores y líneas juntos
        setState(() {
          _markers = markers;
          _polylines = polylines; 
        });
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
        polylines: _polylines, // MODIFICADO: Se añade la propiedad para que pinte las líneas calculadas arriba
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}