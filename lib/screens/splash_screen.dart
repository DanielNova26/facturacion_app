import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulamos un tiempo de carga de 2 segundos, luego navegamos al login
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Usamos el scaffoldBackgroundColor de miTema (azul noche)
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Texto con estilo
            const Text(
              "Iniciando app...",
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            // Indicador de carga
            const CircularProgressIndicator(
              // Podemos personalizar el color con la paleta
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
