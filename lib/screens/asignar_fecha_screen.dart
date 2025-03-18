import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Función auxiliar para transformar un string a Title Case (solo para visualización)
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

class AsignarFechaScreen extends StatefulWidget {
  const AsignarFechaScreen({Key? key}) : super(key: key);

  @override
  _AsignarFechaScreenState createState() => _AsignarFechaScreenState();
}

class _AsignarFechaScreenState extends State<AsignarFechaScreen> {
  String? selectedEstablishment;
  List<String> establishments = ["Todos"];
  DateTime? selectedDate;

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
        establishments = ["Todos", ...estList];
        selectedEstablishment = establishments.first;
      });
    } catch (e) {
      print("Error fetching establishments: $e");
    }
  }

  Future<void> _selectDate() async {
    DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: ColorScheme.light(
              primary: azulDia,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: azulDia),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _assignDeadline() async {
    if (selectedDate == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      if (selectedEstablishment == "Todos") {
        final establecimientos = await firestore.collection('establecimientos').get();
        for (final docSnap in establecimientos.docs) {
          final ref = docSnap.reference;
          batch.update(ref, {'fecha_limite': selectedDate});
        }
      } else {
        final establecimientoRef = firestore
            .collection('establecimientos')
            .doc(selectedEstablishment!.toLowerCase());
        batch.update(establecimientoRef, {'fecha_limite': selectedDate});
      }
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fecha asignada correctamente")),
      );
    } catch (e) {
      print("Error: $e");
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
        title: const Text("Asignar Fecha Límite", style: TextStyle(color: Colors.white)),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedDate != null
                            ? "Fecha seleccionada: ${selectedDate!.toLocal()}".split(' ')[0]
                            : "No se ha seleccionado fecha",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulDia,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectDate,
                      child: const Text("Seleccionar Fecha"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulDia,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _assignDeadline,
                  child: const Text("Asignar Fecha"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
