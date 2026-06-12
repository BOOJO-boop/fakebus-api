import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'home_page.dart';
import 'driver_page.dart';
import 'app_theme.dart';

void main() {
  runApp(const FakeBusApp());
}

class FakeBusApp extends StatelessWidget {
  const FakeBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FakeBus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginPage(),
    );
  }
}

// ===================== LOGIN =====================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _correoController = TextEditingController();
  final _passController   = TextEditingController();
  bool _cargando = false;

  // ── Colores ──────────────────────────────────────────
  static const _bgVerde     = Color(0xFF4a7c20);
  static const _cardVerde   = Color(0xFF2d5010);
  static const _verde       = Color(0xFF639922);
  static const _verdeDark   = Color(0xFF3B6D11);
  static const _blob1       = Color(0xFF3B6D11);
  static const _blob2       = Color(0xFF639922);
  static const _blob3       = Color(0xFF27500A);

  Future<void> _login() async {
    setState(() => _cargando = true);
    try {
      final response = await http.post(
        Uri.parse('https://fakebus-api-production.up.railway.app/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo'    : _correoController.text.trim(),
          'contrasena': _passController.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final usuario        = data['usuario'];
        final String rol     = usuario['rol']           ?? 'pasajero';
        final String nombre  = usuario['nombre']        ?? '';
        final String idAutobus = usuario['id_autobus']?.toString() ?? '0';

        if (rol == 'camionero') {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => DriverPage(idAutobus: idAutobus)));
        } else {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomePage(nombre: nombre)));
        }
      } else {
        _showSnack(data['error'], isError: true);
      }
    } catch (_) {
      _showSnack('Error de conexión', isError: true);
    }
    setState(() => _cargando = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFE24B4A) : _verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo verde
          Container(color: _bgVerde),

          // Blobs decorativos
          Positioned(
            top: -60, left: -60,
            child: _blob(200, _blob1, 0.5),
          ),
          Positioned(
            bottom: -40, right: -40,
            child: _blob(180, _blob2, 0.4),
          ),
          Positioned(
            bottom: 80, left: -60,
            child: _blob(150, _blob3, 0.4),
          ),

          // Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    _buildCard(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildCard() {
    return Column(
      children: [
        // Ícono flotante
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _cardVerde, width: 3),
          ),
          child: const Icon(Icons.directions_bus_rounded, size: 38, color: _verdeDark),
        ),
        const SizedBox(height: -36), // overlap con la card

        // Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          decoration: BoxDecoration(
            color: _cardVerde,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          child: Column(
            children: [
              const Text('FakeBus',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Sistema de Aforo Inteligente',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), letterSpacing: 0.3)),
              const SizedBox(height: 28),

              // Campo correo
              _buildField(
                controller: _correoController,
                hint: 'Correo electrónico',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 14),

              // Campo contraseña
              _buildField(
                controller: _passController,
                hint: 'Contraseña',
                icon: Icons.lock_outline_rounded,
                obscure: true,
              ),
              const SizedBox(height: 8),

              // Olvidaste contraseña
              Align(
                alignment: Alignment.centerRight,
                child: Text('¿Olvidaste tu contraseña?',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
              ),
              const SizedBox(height: 24),

              // Botón login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _cargando
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Iniciar sesión',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 20),

              // Crear cuenta
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.15), thickness: 0.5)),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RegistroPage())),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Crear cuenta',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.15), thickness: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide(color: _verde, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }
}

// ===================== REGISTRO =====================
class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passController   = TextEditingController();
  bool _cargando = false;

  static const _bgVerde   = Color(0xFF4a7c20);
  static const _cardVerde = Color(0xFF2d5010);
  static const _verde     = Color(0xFF639922);
  static const _verdeDark = Color(0xFF3B6D11);
  static const _blob1     = Color(0xFF3B6D11);
  static const _blob2     = Color(0xFF639922);
  static const _blob3     = Color(0xFF27500A);

  Future<void> _registro() async {
    setState(() => _cargando = true);
    try {
      final response = await http.post(
        Uri.parse('https://fakebus-api-production.up.railway.app/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre'    : _nombreController.text,
          'correo'    : _correoController.text,
          'contrasena': _passController.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        _showSnack('Cuenta creada exitosamente');
        Navigator.pop(context);
      } else {
        _showSnack(data['error'], isError: true);
      }
    } catch (_) {
      _showSnack('Error de conexión', isError: true);
    }
    setState(() => _cargando = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFE24B4A) : _verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: _bgVerde),
          Positioned(top: -60, left: -60,   child: _blob(200, _blob1, 0.5)),
          Positioned(bottom: -40, right: -40, child: _blob(180, _blob2, 0.4)),
          Positioned(bottom: 80, left: -60,  child: _blob(150, _blob3, 0.4)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    _buildCard(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildCard() {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _cardVerde, width: 3),
          ),
          child: const Icon(Icons.person_add_rounded, size: 36, color: _verdeDark),
        ),
        const SizedBox(height: -36),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          decoration: BoxDecoration(
            color: _cardVerde,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          child: Column(
            children: [
              const Text('Crear cuenta',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Únete a FakeBus',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
              const SizedBox(height: 28),

              _buildField(controller: _nombreController, hint: 'Nombre completo', icon: Icons.person_outline_rounded),
              const SizedBox(height: 14),
              _buildField(controller: _correoController, hint: 'Correo electrónico', icon: Icons.email_outlined),
              const SizedBox(height: 14),
              _buildField(controller: _passController, hint: 'Contraseña', icon: Icons.lock_outline_rounded, obscure: true),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _registro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _cargando
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Crear cuenta',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.15), thickness: 0.5)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Ya tengo cuenta',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.15), thickness: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: const BorderSide(color: _verde, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }
}