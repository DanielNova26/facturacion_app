import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  void _changePassword(String username, String collection) async {
    String newPassword = _newPassController.text.trim();
    String confirmPassword = _confirmPassController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Las contraseñas no coinciden")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(username)
          .update({
        'password': newPassword,
        'isTemporary': false,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contraseña actualizada")),
      );
      // Tras actualizar, volvemos al login:
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      print("Error al actualizar la contraseña: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al actualizar la contraseña")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Paleta de colores
    const Color azulNoche = Color(0xFF00215e);
    const Color azulDia = Color(0xFF0073cb);
    const Color grisMetal = Color(0xFF53565a);

    final args =
    ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>;
    String username = args['username'] ?? '';
    String collection = args['collection'] ?? 'establecimientos';

    return Scaffold(
      backgroundColor: azulNoche,
      appBar: AppBar(
        backgroundColor: azulDia,
        title: const Text(
          "Cambiar Contraseña",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              color: grisMetal,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      "Ingrese su nueva contraseña",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _newPassController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Nueva Contraseña",
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPassController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Confirmar Contraseña",
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: grisMetal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _changePassword(username, collection),
                      child: const Text("Actualizar Contraseña"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
