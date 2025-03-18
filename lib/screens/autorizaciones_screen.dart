import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Función para transformar a TitleCase (solo para UI)
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

/// Calcula el siguiente mes a partir de un string "Mes_AAAA".
String computeNextMonth(String currentMes) {
  final parts = currentMes.split('_');
  if (parts.length != 2) return currentMes;
  final monthStr = parts[0].toLowerCase();
  int year = int.tryParse(parts[1]) ?? 2025;

  final months = {
    'enero': 1,
    'febrero': 2,
    'marzo': 3,
    'abril': 4,
    'mayo': 5,
    'junio': 6,
    'julio': 7,
    'agosto': 8,
    'septiembre': 9,
    'octubre': 10,
    'noviembre': 11,
    'diciembre': 12,
  };
  final reverseMonths = {
    1: 'Enero',
    2: 'Febrero',
    3: 'Marzo',
    4: 'Abril',
    5: 'Mayo',
    6: 'Junio',
    7: 'Julio',
    8: 'Agosto',
    9: 'Septiembre',
    10: 'Octubre',
    11: 'Noviembre',
    12: 'Diciembre',
  };

  final currentMonthInt = months[monthStr] ?? 3;
  int nextMonthInt;
  int nextYear = year;
  if (currentMonthInt == 12) {
    nextMonthInt = 1;
    nextYear = year + 1;
  } else {
    nextMonthInt = currentMonthInt + 1;
  }
  return '${reverseMonths[nextMonthInt]}_$nextYear';
}

class AutorizacionesScreen extends StatefulWidget {
  const AutorizacionesScreen({Key? key}) : super(key: key);

  @override
  _AutorizacionesScreenState createState() => _AutorizacionesScreenState();
}

class _AutorizacionesScreenState extends State<AutorizacionesScreen> {
  @override
  Widget build(BuildContext context) {
    const Color azulNoche = Color(0xFF00215e);
    const Color azulDia = Color(0xFF0073cb);

    return Scaffold(
      backgroundColor: azulNoche,
      appBar: AppBar(
        backgroundColor: azulDia,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Autorizaciones Pendientes", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('autorizaciones')
            .where('estado', isEqualTo: 'pendiente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Error al cargar solicitudes", style: TextStyle(color: Colors.white)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No hay solicitudes", style: TextStyle(color: Colors.white)),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String establecimiento = data['establecimiento'] ?? 'desconocido';
              final String currentMes = data['currentMes'] ?? 'N/A';
              final String nextMes = data['nextMes'] ?? computeNextMonth(currentMes);

              return Card(
                color: const Color(0xFF53565a), // gris metal
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "El establecimiento ${toTitleCase(establecimiento)} "
                            "solicita cambiar del mes $currentMes al siguiente mes ($nextMes).",
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => _permitir(doc),
                            child: const Text("Permitir"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => _denegar(doc),
                            child: const Text("Denegar"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _permitir(QueryDocumentSnapshot docSnap) async {
    final data = docSnap.data() as Map<String, dynamic>;
    final establecimiento = data['establecimiento'] ?? '';
    final currentMes = data['currentMes'] ?? '';
    final nextMes = data['nextMes'] ?? computeNextMonth(currentMes);

    try {
      // Actualiza el doc en establecimientos
      await FirebaseFirestore.instance
          .collection('establecimientos')
          .doc(establecimiento.toLowerCase())
          .update({'mes': nextMes});

      // Cambia el estado de la solicitud a "aprobado"
      await docSnap.reference.update({'estado': 'aprobado'});

      // Muestra un diálogo de éxito
      showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text("Solicitud Aprobada"),
            content: Text("Se actualizó el mes a $nextMes para ${toTitleCase(establecimiento)}."),
            actions: [
              TextButton(
                child: const Text("Ok"),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Error: doc no existe o algo similar
      showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text("Error al autorizar"),
            content: Text("No se pudo autorizar la solicitud:\n$e"),
            actions: [
              TextButton(
                child: const Text("Cerrar"),
                onPressed: () => Navigator.of(ctx).pop(),
              )
            ],
          );
        },
      );
    }
  }

  Future<void> _denegar(QueryDocumentSnapshot docSnap) async {
    try {
      // Cambia el estado de la solicitud a "denegado"
      await docSnap.reference.update({'estado': 'denegado'});

      // Muestra un diálogo
      showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text("Solicitud Denegada"),
            content: const Text("La solicitud ha sido denegada y se mantiene el mes actual."),
            actions: [
              TextButton(
                child: const Text("Ok"),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        },
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text("Error al denegar"),
            content: Text("No se pudo denegar la solicitud:\n$e"),
            actions: [
              TextButton(
                child: const Text("Cerrar"),
                onPressed: () => Navigator.of(ctx).pop(),
              )
            ],
          );
        },
      );
    }
  }
}
