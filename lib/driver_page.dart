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

  // ── Colores ──────────────────────────────────────────
  static const _bg         = Color(0xFFF7F9F5);
  static const _white       = Color(0xFFFFFFFF);
  static const _border      = Color(0xFFDDE8D4);
  static const _green900    = Color(0xFF1A2E0F);
  static const _green800    = Color(0xFF27500A);
  static const _green700    = Color(0xFF3B6D11);
  static const _green500    = Color(0xFF639922);
  static const _green300    = Color(0xFF97C459);
  static const _green100    = Color(0xFFEAF3DE);
  static const _greenBadge  = Color(0xFFC0DD97);

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _passengerTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPassengers() async {
    try {
      final url = Uri.parse(
          'https://fakebus-api-production.up.railway.app/pasajeros/${widget.idAutobus}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _passengerCount = data['pasajeros_actuales'] ?? 0);
      }
    } catch (e) {
      debugPrint("Error consultando pasajeros: $e");
    }
  }

  void _startPassengerPolling() {
    _passengerTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_isRouteActive) _fetchPassengers();
    });
  }

  Future<void> _updateRouteStatusInBackend(bool active) async {
    try {
      await http.post(
        Uri.parse('https://fakebus-api-production.up.railway.app/cambiar_estado_ruta'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_camion': int.parse(widget.idAutobus),
          'activo': active ? 1 : 0,
        }),
      );
    } catch (e) {
      debugPrint("Error actualizando estado de ruta: $e");
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
      _showSnack('Ruta finalizada. El camión ya no es visible para los usuarios.');
    } else {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Necesitas aceptar los permisos de ubicación.');
          return;
        }
      }
      await _updateRouteStatusInBackend(true);
      setState(() => _isRouteActive = true);
      _fetchPassengers();
      _startPassengerPolling();
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) => _sendGPSToRailway(pos.latitude, pos.longitude));
    }
  }

  Future<void> _sendGPSToRailway(double lat, double lng) async {
    try {
      await http.post(
        Uri.parse('https://fakebus-api-production.up.railway.app/actualizar_ubicacion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_camion': int.parse(widget.idAutobus),
          'latitud': lat,
          'longitud': lng,
        }),
      );
    } catch (e) {
      debugPrint("Error enviando GPS: $e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _green700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 4),
            _buildStatsRow(),
            const SizedBox(height: 32),
            _buildBigButton(),
            const SizedBox(height: 32),
            const Divider(color: _border, thickness: 0.5),
            const SizedBox(height: 16),
            _buildFooterText(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(color: _border, height: 0.5),
      ),
      title: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
              color: _green500, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Panel del conductor',
            style: TextStyle(
              color: _green900,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _green100,
            border: Border.all(color: _greenBadge, width: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '🚌  Camión #${widget.idAutobus}',
            style: const TextStyle(
              color: _green700,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildPassengerCard()),
        const SizedBox(width: 12),
        Expanded(child: _buildStatusCard()),
      ],
    );
  }

  Widget _buildPassengerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        border: Border.all(color: _border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PASAJEROS',
            style: TextStyle(
              fontSize: 12,
              color: _green500,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_passengerCount',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              color: _isRouteActive ? _green900 : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'a bordo',
            style: TextStyle(fontSize: 11, color: _green300),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        border: Border.all(color: _border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTADO',
            style: TextStyle(
              fontSize: 12,
              color: _green500,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isRouteActive ? _green100 : const Color(0xFFFCEBEB),
              border: Border.all(
                color: _isRouteActive ? _greenBadge : const Color(0xFFF09595),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: _isRouteActive ? _green500 : const Color(0xFFE24B4A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isRouteActive ? 'En ruta' : 'Apagado',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _isRouteActive ? _green800 : const Color(0xFFA32D2D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigButton() {
    return GestureDetector(
      onTap: _toggleRoute,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          color: _isRouteActive ? const Color(0xFFFCEBEB) : _green100,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isRouteActive ? const Color(0xFFF09595) : _green300,
            width: 2.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRouteActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 56,
              color: _isRouteActive ? const Color(0xFFA32D2D) : _green700,
            ),
            const SizedBox(height: 8),
            Text(
              _isRouteActive ? 'APAGAR RUTA' : 'INICIAR RUTA',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
                color: _isRouteActive ? const Color(0xFF791F1F) : _green800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterText() {
    return Text(
      _isRouteActive
          ? 'Transmitiendo GPS y capacidad en tiempo real...'
          : 'Presiona el botón verde para iniciar tu recorrido.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: _isRouteActive ? _green500 : Colors.grey,
      ),
    );
  }
}