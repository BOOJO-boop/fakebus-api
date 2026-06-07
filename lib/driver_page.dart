import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class DriverPage extends StatefulWidget {
  final String idAutobus; 

  const DriverPage({Key? key, required this.idAutobus}) : super(key: key);

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  bool _isRouteActive = false;
  int _passengerCount = 0; 
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _passengerTimer;

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _passengerTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPassengers() async {
    try {
      final url = Uri.parse('https://fakebus-api-production.up.railway.app/pasajeros/${widget.idAutobus}');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _passengerCount = data['pasajeros_actuales'] ?? 0;
        });
      }
    } catch (e) {
      print("Error consultando pasajeros: $e");
    }
  }

  void _startPassengerPolling() {
    _passengerTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_isRouteActive) {
        _fetchPassengers();
      }
    });
  }

  Future<void> _updateRouteStatusInBackend(bool active) async {
    try {
      final url = Uri.parse('https://fakebus-api-production.up.railway.app/cambiar_estado_ruta');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_camion': int.parse(widget.idAutobus),
          'activo': active ? 1 : 0,
        }),
      );
    } catch (e) {
      print("Error actualizando estado de ruta: $e");
    }
  }

  Future<void> _toggleRoute() async {
    if (_isRouteActive) {
      _positionStreamSubscription?.cancel();
      _passengerTimer?.cancel();
      
      await _updateRouteStatusInBackend(false);
      
      setState(() {
        _isRouteActive = false;
        _passengerCount = 0;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta finalizada. El camión ya no es visible para los usuarios.')),
      );
    } else {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Necesitas aceptar los permisos de ubicación para iniciar la ruta.')),
          );
          return;
        }
      }

      await _updateRouteStatusInBackend(true);

      setState(() {
        _isRouteActive = true;
      });

      _fetchPassengers(); 
      _startPassengerPolling();

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, 
          distanceFilter: 10, 
        ),
      ).listen((Position position) {
        _sendGPSToRailway(position.latitude, position.longitude);
      });
    }
  }

  Future<void> _sendGPSToRailway(double lat, double lng) async {
    try {
      final url = Uri.parse('https://fakebus-api-production.up.railway.app/actualizar_ubicacion');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_camion': int.parse(widget.idAutobus),
          'latitud': lat,
          'longitud': lng,
        }),
      );
    } catch (e) {
      print("Error enviando GPS: $e");
    }
  }

  @override
  Widget build(幕ontext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Panel del Conductor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Pasajeros a bordo', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          '$_passengerCount',
                          style: TextStyle(
                            fontSize: 48, 
                            fontWeight: FontWeight.bold,
                            color: _isRouteActive ? Colors.indigo[900] : Colors.grey
                          ),
                        ),
                      ],
                    ),
                    Container(height: 50, width: 1, color: Colors.grey[300]),
                    Column(
                      children: [
                        const Text('Estado del Camión', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isRouteActive ? Colors.green[100] : Colors.red[100],
                            borderRadius: BorderRadius.circular(20)
                          ),
                          child: Text(
                            _isRouteActive ? 'EN RUTA' : 'APAGADO',
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: _isRouteActive ? Colors.green[700] : Colors.red[700]
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: _toggleRoute,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: _isRouteActive ? Colors.red[600] : Colors.green[600],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRouteActive ? Colors.red : Colors.green).withOpacity(0.4),
                      spreadRadius: 6,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRouteActive ? Icons.power_settings_new : Icons.play_arrow,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isRouteActive ? 'APAGAR RUTA' : 'INICIAR RUTA',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              _isRouteActive 
                ? 'Transmitiendo GPS y capacidad en tiempo real...' 
                : 'Presiona el botón verde para iniciar tu recorrido.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: _isRouteActive ? Colors.green[700] : Colors.grey[600]
              ),
            ),
          ],
        ),
      ),
    );
  }
}