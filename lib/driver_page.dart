import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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

  void _startPassengerPolling() {
    _passengerTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_isRouteActive) {
        print("Consultando cantidad de pasajeros para el camión: ${widget.idAutobus}");
      }
    });
  }

  Future<void> _toggleRoute() async {
    if (_isRouteActive) {
      _positionStreamSubscription?.cancel();
      _passengerTimer?.cancel();
      
      setState(() {
        _isRouteActive = false;
        _passengerCount = 0;
      });
      
      print("Ruta apagada en la base de datos.");
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

      setState(() {
        _isRouteActive = true;
      });

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

  void _sendGPSToRailway(double lat, double lng) {
    print("Enviando coordenadas a Railway -> Camión: ${widget.idAutobus}, Lat: $lat, Lng: $lng");
  }

  @override
  Widget build(BuildContext context) {
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