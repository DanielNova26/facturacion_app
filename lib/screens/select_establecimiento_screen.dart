import 'package:flutter/material.dart';

/// Función auxiliar para transformar un string a Title Case (solo para visualización)
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

class SelectEstablecimientoScreen extends StatelessWidget {
  const SelectEstablecimientoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lista de establecimientos (se pueden obtener de Firestore)
    final List<String> establecimientos = [
      "URIS",
      "MODELO",
      "MONIQUIRA",
      "PICOTA",
      "LANDAZABAL",
      "LETICIA",
      "CHIQUINQUIRA",
      "PONAL",
      "BACON",
      "UBATE",
      "CAQUEZA",
      "TOMAS CIPRIANO",
      "LA MESA",
      "GUATEQUE",
      "GACHETA",
    ];
    // Ordenar alfabéticamente (sin afectar la lógica interna)
    establecimientos.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Obtener el rol desde los argumentos (por ejemplo, 'facturacion' o 'establecimiento')
    final args = ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>?;
    String role = args?['role'] ?? 'facturacion';

    // Paleta de colores
    const Color azulNoche = Color(0xFF00215e);
    const Color azulDia = Color(0xFF0073cb);

    return Scaffold(
      backgroundColor: azulNoche,
      appBar: AppBar(
        backgroundColor: azulDia,
        title: const Text("Selecciona Establecimiento", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        itemCount: establecimientos.length,
        itemBuilder: (context, index) {
          final est = establecimientos[index];
          // Se muestra el establecimiento en Title Case para la UI.
          final displayName = toTitleCase(est);
          return Card(
            color: azulDia.withOpacity(0.8),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              title: Text(
                displayName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () {
                if (role.toLowerCase() == 'facturacion') {
                  Navigator.pushReplacementNamed(
                    context,
                    '/facturacion_profile',
                    // Se convierte el nombre a minúsculas para que coincida con la consulta en Firestore.
                    arguments: {'establecimiento': est.toLowerCase(), 'role': role},
                  );
                } else {
                  Navigator.pushReplacementNamed(
                    context,
                    '/establecimientos',
                    arguments: {'establecimiento': est.toLowerCase(), 'role': role},
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
