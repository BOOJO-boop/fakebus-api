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
        
        // Verificación de rol para redirección
        String rol = data['usuario']['rol'] ?? 'usuario';

        if (rol == 'camionero') {
          String idAutobus = data['usuario']['id_autobus']?.toString() ?? '1';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DriverPage(idAutobus: idAutobus),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(nombre: data['usuario']['nombre']),
            ),
          );
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
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_bus, size: 100, color: AppColors.textOnDark),
              const SizedBox(height: AppSpacing.sm),
              const Text('FakeBus', style: AppTextStyles.appTitle),
              const SizedBox(height: AppSpacing.xs),
              const Text('Sistema de Aforo Inteligente', style: AppTextStyles.appSubtitle),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                controller: _correoController,
                hint: 'Correo',
                icon: Icons.email,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _passController,
                hint: 'Contraseña',
                icon: Icons.lock,
                obscure: true,
              ),
              const SizedBox(height: AppSpacing.md),

              AppPrimaryButton(
                label: 'Iniciar Sesión',
                onPressed: _login,
                loading: _cargando,
              ),
              const SizedBox(height: AppSpacing.sm),

              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegistroPage()),
                ),
                child: const Text('¿No tienes cuenta? Regístrate', style: AppTextStyles.linkOnDark),
              ),
            ],
          ),
        ),
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
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 80, color: AppColors.textOnDark),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _nombreController,
                hint: 'Nombre completo',
                icon: Icons.person,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _correoController,
                hint: 'Correo',
                icon: Icons.email,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _passController,
                hint: 'Contraseña',
                icon: Icons.lock,
                obscure: true,
              ),
              const SizedBox(height: AppSpacing.md),

              AppPrimaryButton(
                label: 'Crear Cuenta',
                onPressed: _registro,
                loading: _cargando,
              ),
            ],
          ),
        ),
      ),
    );
  }
}