import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'app_theme.dart';

class HomePage extends StatefulWidget {
  final String nombre;
  const HomePage({super.key, required this.nombre});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ── Mapa ──────────────────────────────────────────────
  GoogleMapController? _mapController;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  static const LatLng _parral = LatLng(26.9219, -105.6661);

  // ── Datos ─────────────────────────────────────────────
  List<dynamic> camiones = [];
  bool  _cargando = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarCamiones();
    _timer = Timer.periodic(
      const Duration(seconds: 5), (_) => _cargarCamiones(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────
  Color _hexAColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primaryLight;
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color _colorSemaforo(int pasajeros, int capacidad) {
    if (capacidad <= 0) return AppColors.semaforoLibre;
    final p = pasajeros / capacidad;
    if (p < 0.50) return AppColors.semaforoLibre;
    if (p < 0.85) return AppColors.semaforoModerado;
    return AppColors.semaforoSaturado;
  }

  String _textoSemaforo(int pasajeros, int capacidad) {
    if (capacidad <= 0) return 'Disponible';
    final p = pasajeros / capacidad;
    if (p < 0.50) return 'Disponible';
    if (p < 0.85) return 'Moderado';
    return 'Saturado';
  }

  IconData _iconoSemaforo(int pasajeros, int capacidad) {
    if (capacidad <= 0) return Icons.sentiment_very_satisfied;
    final p = pasajeros / capacidad;
    if (p < 0.50) return Icons.sentiment_very_satisfied;
    if (p < 0.85) return Icons.sentiment_neutral;
    return Icons.sentiment_very_dissatisfied;
  }

  // ── Carga de datos ────────────────────────────────────
  Future<void> _cargarCamiones() async {
    try {
      final response = await http.get(
        Uri.parse('https://fakebus-api-production.up.railway.app/camiones'),
      );
      if (response.statusCode != 200) {
        setState(() => _cargando = false);
        return;
      }

      final data = jsonDecode(response.body) as List;
      final Set<Marker>   markers   = {};
      final Set<Polyline> polylines = {};

      for (final c in data) {
        if (c['latitud'] == null || c['longitud'] == null) continue;

        final pasajeros  = int.tryParse(c['pasajeros_actuales'].toString()) ?? 0;
        final capacidad  = int.tryParse(c['capacidad_total'].toString())    ?? 40;
        final porcentaje = capacidad > 0 ? pasajeros / capacidad : 0.0;
        final estado     = _textoSemaforo(pasajeros, capacidad);

        final posicion = LatLng(
          double.parse(c['latitud'].toString()),
          double.parse(c['longitud'].toString()),
        );

        markers.add(Marker(
          markerId  : MarkerId(c['id_camion'].toString()),
          position  : posicion,
          infoWindow: InfoWindow(
            title  : c['modelo'],
            snippet: '$estado · $pasajeros/$capacidad pasajeros',
          ),
        ));

        final puntos = c['puntos_ruta'];
        if (puntos != null && (puntos as List).isNotEmpty) {
          polylines.add(Polyline(
            polylineId: PolylineId('ruta_${c['id_camion']}'),
            points    : puntos
                .map<LatLng>((p) => LatLng(
                      double.parse(p['latitud'].toString()),
                      double.parse(p['longitud'].toString()),
                    ))
                .toList(),
            color   : _hexAColor(c['color_hex']),
            width   : 5,
            patterns: [],
          ));
        }
      }

      setState(() {
        camiones  = data;
        _markers  = markers;
        _polylines = polylines;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _cargando = false);
    }
  }

  // ── UI ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── 1. MAPA (fondo completo) ──────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _parral,
              zoom  : 13,
            ),
            markers                : _markers,
            polylines              : _polylines,
            onMapCreated           : (c) => _mapController = c,
            myLocationEnabled      : true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled    : false,
          ),

          // ── 2. HEADER flotante ────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical  : AppSpacing.xs,
              ),
              child: Row(
                children: [
                  // Saludo
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical  : 10,
                      ),
                      decoration: BoxDecoration(
                        color       : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow   : [
                          BoxShadow(
                            color  : Colors.black.withOpacity(0.10),
                            blurRadius: 8,
                            offset : const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bus,
                              color: AppColors.primaryLight, size: 22),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('FakeBus',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize  : 15,
                                    color     : AppColors.primary,
                                  )),
                              Text(
                                'Hola, ${widget.nombre.split(' ')[0]}',
                                style: AppTextStyles.cardSubtitle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Botón refrescar
                  _FloatButton(
                    icon     : Icons.refresh,
                    onPressed: _cargarCamiones,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Botón centrar mapa
                  _FloatButton(
                    icon: Icons.my_location,
                    onPressed: () => _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_parral, 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. PANEL DESLIZABLE (abajo) ───────────────
          DraggableScrollableSheet(
            initialChildSize: 0.30,  // ocupa 30% al inicio
            minChildSize    : 0.12,  // mínimo colapsado
            maxChildSize    : 0.75,  // máximo expandido
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color       : AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color    : Colors.black26,
                      blurRadius: 12,
                      offset   : Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        width : 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color       : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // Título del panel
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _cargando
                                ? 'Cargando...'
                                : '${camiones.length} camiones activos',
                            style: AppTextStyles.cardTitle,
                          ),
                          if (_cargando)
                            const SizedBox(
                              width : 18,
                              height: 18,
                              child : CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Lista de tarjetas
                    Expanded(
                      child: camiones.isEmpty && !_cargando
                          ? const Center(
                              child: Text('No hay camiones disponibles'),
                            )
                          : ListView.builder(
                              controller : scrollController,
                              padding    : const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical  : AppSpacing.xs,
                              ),
                              itemCount  : camiones.length,
                              itemBuilder: (context, index) {
                                final c = camiones[index];
                                final pasajeros = int.tryParse(
                                        c['pasajeros_actuales'].toString()) ??
                                    0;
                                final capacidad = int.tryParse(
                                        c['capacidad_total'].toString()) ??
                                    40;
                                final color = _colorSemaforo(pasajeros, capacidad);
                                final porcentaje =
                                    capacidad > 0 ? pasajeros / capacidad : 0.0;

                                return _BusTarjeta(
                                  modelo    : c['modelo'] ?? 'Sin Modelo',
                                  placa     : c['placa']  ?? 'S/P',
                                  pasajeros : pasajeros,
                                  capacidad : capacidad,
                                  porcentaje: porcentaje,
                                  color     : color,
                                  texto     : _textoSemaforo(pasajeros, capacidad),
                                  icono     : _iconoSemaforo(pasajeros, capacidad),
                                  onTap     : () {
                                    // Al tocar una tarjeta, centra el mapa en ese camión
                                    if (c['latitud'] != null && c['longitud'] != null) {
                                      _mapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(
                                          LatLng(
                                            double.parse(c['latitud'].toString()),
                                            double.parse(c['longitud'].toString()),
                                          ),
                                          15,
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Botón flotante del header ──────────────────────────────
class _FloatButton extends StatelessWidget {
  const _FloatButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color       : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow   : [
          BoxShadow(
            color    : Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset   : const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon     : Icon(icon, color: AppColors.primary),
        onPressed: onPressed,
      ),
    );
  }
}

// ── Tarjeta de camión ──────────────────────────────────────
class _BusTarjeta extends StatelessWidget {
  const _BusTarjeta({
    required this.modelo,
    required this.placa,
    required this.pasajeros,
    required this.capacidad,
    required this.porcentaje,
    required this.color,
    required this.texto,
    required this.icono,
    required this.onTap,
  });

  final String   modelo;
  final String   placa;
  final int      pasajeros;
  final int      capacidad;
  final double   porcentaje;
  final Color    color;
  final String   texto;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side        : const BorderSide(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding   : const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color        : color.withOpacity(0.12),
                      borderRadius : BorderRadius.circular(AppRadius.input),
                    ),
                    child: Icon(Icons.directions_bus, color: color, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(modelo, style: AppTextStyles.cardTitle),
                        Text('Placa: $placa', style: AppTextStyles.cardSubtitle),
                      ],
                    ),
                  ),
                  Container(
                    padding   : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color       : color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(icono, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(texto, style: AppTextStyles.badgeLabel),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$pasajeros / $capacidad pasajeros',
                      style: AppTextStyles.cardDetail),
                  Text(
                    '${(porcentaje * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.cardDetail.copyWith(
                      color     : color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value          : porcentaje,
                  backgroundColor: AppColors.progressBackground,
                  valueColor     : AlwaysStoppedAnimation<Color>(color),
                  minHeight      : 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}