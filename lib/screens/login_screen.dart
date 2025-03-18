import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    String username = _userController.text.trim();
    String password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Complete todos los campos")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Si el usuario es "facturacion", busca en "areas", de lo contrario en "establecimientos"
    final collectionName = (username.toLowerCase() == "facturacion") ? "areas" : "establecimientos";

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(username)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['password'] == password) {
          bool isTemporary = data['isTemporary'] ?? false;
          String role = data['role'] ?? "establecimiento";

          // Simula un pequeño retraso para mostrar el splash interno
          await Future.delayed(const Duration(seconds: 2));

          if (isTemporary) {
            Navigator.pushReplacementNamed(
              context,
              '/change_password',
              arguments: {'username': username, 'collection': collectionName},
            );
          } else {
            if (role.toLowerCase() == "facturacion") {
              Navigator.pushReplacementNamed(
                context,
                '/facturacion_home',
                arguments: {'role': role},
              );
            } else {
              Navigator.pushReplacementNamed(
                context,
                '/establecimientos',
                arguments: {'establecimiento': username, 'role': role},
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Contraseña incorrecta")));
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Usuario no encontrado")));
      }
    } catch (e) {
      print("Error en login: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Error al iniciar sesión")));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definición de colores según la paleta
    const Color azulNoche = Color(0xFF00215e);
    const Color azulDia = Color(0xFF0073cb);
    const Color grisMetal = Color(0xFF53565a);

    return Scaffold(
      backgroundColor: azulNoche,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo o avatar
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: Text(
                          "APP",
                          style: TextStyle(
                            color: azulDia,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Formulario contenido en un Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: grisMetal,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                'INICIAR SESIÓN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 32),
                              TextField(
                                controller: _userController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'USUARIO',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white54),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _passController,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'CONTRASEÑA',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white54),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: grisMetal,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _login,
                                  child: const Text("Iniciar Sesión"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/admin_login');
                        },
                        child: const Text(
                          "Iniciar sesión como Administrador",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Overlay de carga (Splash interno)
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        "Iniciando Sesion",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
