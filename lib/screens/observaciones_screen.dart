import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ObservacionesScreen extends StatefulWidget {
  final String establecimientoId; // 1. Añadir parámetro requerido

  const ObservacionesScreen({super.key, required this.establecimientoId});

  @override
  _ObservacionesScreenState createState() => _ObservacionesScreenState();
}

class _ObservacionesScreenState extends State<ObservacionesScreen> {
  final Color azulNoche = const Color(0xFF00215e);
  final Color grisMetal = const Color(0xFF53565a);

  // 2. Añadir método para formatear fecha
  String _formatFecha(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Observaciones'),
        backgroundColor: azulNoche,
      ),
      backgroundColor: azulNoche,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('establecimientos')
            .doc(widget.establecimientoId) // 3. Usar el parámetro recibido
            .collection('observaciones')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                color: grisMetal,
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(
                    data['texto'] ?? 'Sin texto',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _formatFecha(data['fecha'] as Timestamp),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}