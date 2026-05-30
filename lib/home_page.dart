import 'map_page.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class HomePage extends StatefulWidget {
  final String nombre;
  const HomePage({super.key, required this.nombre});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> camiones = [];
  bool _cargando = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarCamiones();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _cargarCamiones());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarCamiones() async {
    try {
      final response = await http.get(Uri.parse('https://fakebus-api-production.up.railway.app/'));
      if (response.statusCode == 200) {
        setState(() {
          camiones = jsonDecode(response.body);
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  Color _colorSemaforo(int pasajeros, int capacidad) {
    double porcentaje = pasajeros / capacidad;
    if (porcentaje < 0.5) return Colors.green;
    if (porcentaje < 0.85) return Colors.orange;
    return Colors.red;
  }

  String _textoSemaforo(int pasajeros, int capacidad) {
    double porcentaje = pasajeros / capacidad;
    if (porcentaje < 0.5) return 'Disponible';
    if (porcentaje < 0.85) return 'Moderado';
    return 'Saturado';
  }

  IconData _iconoSemaforo(int pasajeros, int capacidad) {
    double porcentaje = pasajeros / capacidad;
    if (porcentaje < 0.5) return Icons.sentiment_very_satisfied;
    if (porcentaje < 0.85) return Icons.sentiment_neutral;
    return Icons.sentiment_very_dissatisfied;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FakeBus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Hola, ${widget.nombre.split(' ')[0]}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage())),
          ),
          
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarCamiones,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : camiones.isEmpty
              ? const Center(child: Text('No hay camiones disponibles'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: camiones.length,
                  itemBuilder: (context, index) {
                    final c = camiones[index];
                    final pasajeros = c['pasajeros_actuales'] as int;
                    final capacidad = c['capacidad_total'] as int;
                    final color = _colorSemaforo(pasajeros, capacidad);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.directions_bus, color: color, size: 32),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c['modelo'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      Text('Placa: ${c['placa']}', style: TextStyle(color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    children: [
                                      Icon(_iconoSemaforo(pasajeros, capacidad), color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text(_textoSemaforo(pasajeros, capacidad), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$pasajeros / $capacidad pasajeros', style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('${((pasajeros / capacidad) * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: pasajeros / capacidad,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}