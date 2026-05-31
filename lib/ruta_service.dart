import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RutaService {
  // Cambia esto por la URL real de tu FastAPI desplegado o tu IP local de pruebas
  final String baseUrl = "https://fakebus-api-production.up.railway.app";

  Future<Map<String, dynamic>> obtenerInformacionRuta(int idRuta) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/camiones/$idRuta'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Convertimos el JSON de coordenadas en objetos LatLng que entiende Google Maps
        List<LatLng> puntos = [];
        for (var coord in data['coordenadas']) {
          puntos.add(LatLng(coord['latitud'], coord['longitud']));
        }

        return {
          "nombre": data['modelo'],
          "color": data['color_hex'],
          "coordenadas": puntos
        };
      } else {
        throw Exception("Error al cargar la ruta");
      }
    } catch (e) {
      print("Error de conexión: $e");
      return {};
    }
  }
}