import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RutaService {
  // Tu servidor en Railway
  final String baseUrl = "https://fakebus-api-production.up.railway.app";

  Future<Map<String, dynamic>> obtenerInformacionRuta(int idRuta) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/camiones/$idRuta'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 1. Extraemos los puntos "crudos" (líneas rectas) de la base de datos
        List<LatLng> puntosCrudos = [];
        for (var coord in data['coordenadas']) {
          puntosCrudos.add(LatLng(coord['latitud'], coord['longitud']));
        }

        // 2. Pasamos esos puntos por la API gratuita de OSRM para pegarlos a las calles
        List<LatLng> puntosSuavizados = await _obtenerPolilineaSuavizada(puntosCrudos);

        return {
          "nombre": data['modelo'],
          "color": data['color_hex'],
          "coordenadas": puntosSuavizados // <-- Devolvemos la ruta ya perfecta
        };
      } else {
        throw Exception("Error al cargar la ruta");
      }
    } catch (e) {
      print("Error de conexión: $e");
      return {};
    }
  }

  // --- FUNCIÓN INTERNA PARA OSRM ---
  Future<List<LatLng>> _obtenerPolilineaSuavizada(List<LatLng> puntosParadas) async {
    // Si hay menos de 2 puntos, no se puede hacer una ruta
    if (puntosParadas.length < 2) return puntosParadas;

    // Convertimos los puntos al formato de OSRM: longitud,latitud separadas por ;
    String coordenadas = puntosParadas.map((p) => '${p.longitude},${p.latitude}').join(';');
    
    // Petición a la API gratuita de rutas vehiculares
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/$coordenadas?geometries=geojson&overview=full');
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
          
          // OSRM devuelve [longitud, latitud]. Google Maps usa [latitud, longitud].
          return coordinates.map((c) => LatLng(c[1], c[0])).toList();
        }
      }
    } catch (e) {
      print("Error conectando a OSRM: $e");
    }
    
    // Si OSRM llega a fallar o no hay internet, devuelve los puntos rectos originales
    return puntosParadas; 
  }
}