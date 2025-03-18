import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Función auxiliar para transformar un string a Title Case (solo para visualización)
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

class EscribirObservacionesScreen extends StatefulWidget {
  const EscribirObservacionesScreen({Key? key}) : super(key: key);

  @override
  _EscribirObservacionesScreenState createState() => _EscribirObservacionesScreenState();
}

class _EscribirObservacionesScreenState extends State<EscribirObservacionesScreen> {
  String? selectedEstablishment;
  List<String> establishments = ["Seleccionar"];
  final TextEditingController _observationController = TextEditingController();

  final Color azulNoche = const Color(0xFF00215e);
  final Color azulDia = const Color(0xFF0073cb);
  final Color grisMetal = const Color(0xFF53565a);

  @override
  void initState() {
    super.initState();
    _fetchEstablishments();
  }

  Future<void> _fetchEstablishments() async {
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('establecimientos').get();
      List<String> estList = [];
      for (var doc in snapshot.docs) {
        estList.add(toTitleCase(doc.id));
      }
      estList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        establishments = estList;
        if (establishments.isNotEmpty) {
          selectedEstablishment = establishments.first;
        }
      });
    } catch (e) {
      print("Error fetching establishments: $e");
    }
  }

  Future<void> _submitObservation() async {
    String observationText = _observationController.text.trim();
    if (observationText.isEmpty || selectedEstablishment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debe seleccionar un establecimiento y escribir una observación.")),
      );
      return;
    }

    try {
      final establecimientoRef = FirebaseFirestore.instance
          .collection('establecimientos')
          .doc(selectedEstablishment!.toLowerCase());

      // Obtener el mes actual o asignar un valor por defecto
      final docSnap = await establecimientoRef.get();
      String currentMes = 'No_Asignado';
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>?;
        currentMes = data?['mes'] ?? 'No_Asignado';
      }

      await establecimientoRef.collection('observaciones').add({
        'mes': currentMes,
        'texto': observationText,
        'fecha': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Observación enviada correctamente.")),
      );
      _observationController.clear();
    } catch (e) {
      print("Error submitting observation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: azulNoche,
      appBar: AppBar(
        backgroundColor: azulDia,
        title: const Text("Escribir Observaciones", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: grisMetal,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedEstablishment,
                  decoration: const InputDecoration(
                    labelText: "Seleccionar Establecimiento",
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  dropdownColor: grisMetal,
                  items: establishments.map((est) {
                    return DropdownMenuItem<String>(
                      value: est,
                      child: Text(est, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedEstablishment = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _observationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Observación",
                    labelStyle: TextStyle(color: Colors.white),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulDia,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _submitObservation,
                  child: const Text("Enviar Observación"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
