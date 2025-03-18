import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Función para mostrar el nombre con mayúscula inicial en la UI
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<List<Map<String, dynamic>>> _establecimientosFuture;

  @override
  void initState() {
    super.initState();
    _establecimientosFuture = _fetchEstablecimientos();
  }

  Future<List<Map<String, dynamic>>> _fetchEstablecimientos() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('establecimientos').get();
    List<Map<String, dynamic>> estList = snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      // Usamos 'nombre' si existe; de lo contrario, el id
      data['nombre'] = data['nombre'] ?? doc.id;
      return data;
    }).toList();
    // Ordenamos la lista alfabéticamente (sin afectar la lógica interna)
    estList.sort((a, b) => a['nombre'].toString().toLowerCase().compareTo(b['nombre'].toString().toLowerCase()));
    return estList;
  }

  String _generateTemporaryPassword({int length = 8}) {
    const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _resetPassword(String establecimientoId) async {
    String newTempPassword = _generateTemporaryPassword();
    try {
      await FirebaseFirestore.instance
          .collection('establecimientos')
          .doc(establecimientoId)
          .update({
        'password': newTempPassword,
        'isTemporary': true,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Contraseña restablecida: $newTempPassword"),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _establecimientosFuture = _fetchEstablecimientos();
      });
    } catch (e) {
      print("Error restableciendo contraseña: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al restablecer la contraseña: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00215e),
      appBar: AppBar(
        title: const Text(
          "Panel de Administración",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0073cb),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _establecimientosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay establecimientos.", style: TextStyle(color: Colors.white)));
          } else {
            List<Map<String, dynamic>> establecimientos = snapshot.data!;
            return ListView.builder(
              itemCount: establecimientos.length,
              itemBuilder: (context, index) {
                var est = establecimientos[index];
                String id = est['id'];
                String nombre = toTitleCase(est['nombre'] ?? id);
                String currentPassword = est['password'] ?? "";
                bool isTemporary = est['isTemporary'] ?? false;
                return Card(
                  color: const Color(0xFF53565a),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    title: Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      "Contraseña: $currentPassword" + (isTemporary ? " (Temporal)" : ""),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF53565a),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _resetPassword(id),
                      child: const Text("Resetear Contraseña"),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
