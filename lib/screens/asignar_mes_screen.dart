import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Función para mostrar en Title Case sin afectar la lógica interna.
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

class AsignarMesScreen extends StatefulWidget {
  const AsignarMesScreen({Key? key}) : super(key: key);

  @override
  _AsignarMesScreenState createState() => _AsignarMesScreenState();
}

class _AsignarMesScreenState extends State<AsignarMesScreen> {
  /// Aquí almacenamos la lista de establecimientos como un
  /// Map { 'id': docIdEnFirestore, 'display': TitleCase }
  List<Map<String, String>> establishments = [];

  /// Opción "Todos"
  final Map<String, String> todosMap = {'id': 'todos', 'display': 'Todos'};

  String? selectedEstablishmentId; // Este será el valor real (doc.id o 'todos')

  String? selectedMonth;
  String? selectedYear;

  final List<String> months = [
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
  ];
  final List<String> years = [];

  @override
  void initState() {
    super.initState();
    _initializeYears();
    _fetchEstablishments();
  }

  /// Inicializa la lista de años
  void _initializeYears() {
    int currentYear = DateTime.now().year;
    for (int i = 0; i < 6; i++) {
      years.add((currentYear + i).toString());
    }
    years.sort();
    selectedYear = years.first;
  }

  /// Obtiene los establecimientos desde Firestore y crea un Map
  /// { 'id': doc.id, 'display': toTitleCase(doc.id) }
  /// Luego los ordena alfabéticamente por 'display'
  Future<void> _fetchEstablishments() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('establecimientos')
          .get();
      List<Map<String, String>> tempList = [];

      for (var doc in snapshot.docs) {
        String docId = doc.id; // minúsculas en Firestore
        String displayName = toTitleCase(docId); // Para UI
        tempList.add({'id': docId, 'display': displayName});
      }

      // Ordenamos la lista alfabéticamente por 'display'
      tempList.sort((a, b) => a['display']!.toLowerCase().compareTo(b['display']!.toLowerCase()));

      // Insertamos la opción "Todos" al inicio
      tempList.insert(0, todosMap);

      setState(() {
        establishments = tempList;
        selectedEstablishmentId = establishments.first['id']; // 'todos' por defecto
      });
    } catch (e) {
      print("Error fetching establishments: $e");
    }
  }

  /// Asigna el mes <selectedMonth>_<selectedYear> al establecimiento seleccionado
  /// o a todos si se eligió 'todos'.
  Future<void> _assignMes() async {
    if (selectedMonth == null || selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seleccione mes y año")),
      );
      return;
    }
    String newMes = "${selectedMonth}_$selectedYear";

    try {
      if (selectedEstablishmentId == 'todos') {
        // Actualiza todos los establecimientos
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('establecimientos')
            .get();
        for (var doc in snapshot.docs) {
          await FirebaseFirestore.instance
              .collection('establecimientos')
              .doc(doc.id)
              .update({'mes': newMes});
        }
      } else {
        // Actualiza solo el establecimiento seleccionado (id real en Firebase)
        await FirebaseFirestore.instance
            .collection('establecimientos')
            .doc(selectedEstablishmentId) // minúsculas en Firestore
            .update({'mes': newMes});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mes asignado correctamente")),
      );
    } catch (e) {
      print("Error assigning mes: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al asignar el mes")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Paleta de colores
    const Color azulNoche = Color(0xFF00215e); // Fondo
    const Color azulDia   = Color(0xFF0073cb); // Encabezado
    const Color grisMetal = Color(0xFF53565a); // Card

    return Scaffold(
      backgroundColor: azulNoche,
      appBar: AppBar(
        backgroundColor: azulDia,
        title: const Text("Asignar Mes y Año", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: grisMetal,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Establecimiento
                  DropdownButtonFormField<String>(
                    value: selectedEstablishmentId,
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
                    style: const TextStyle(color: Colors.white),
                    items: establishments.map((map) {
                      // map['id'] => doc.id real
                      // map['display'] => TitleCase
                      return DropdownMenuItem<String>(
                        value: map['id'], // Valor real (para Firestore)
                        child: Text(map['display']!, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedEstablishmentId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Mes
                  DropdownButtonFormField<String>(
                    value: selectedMonth,
                    decoration: const InputDecoration(
                      labelText: "Seleccionar Mes",
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    dropdownColor: grisMetal,
                    style: const TextStyle(color: Colors.white),
                    items: months.map((mes) {
                      return DropdownMenuItem<String>(
                        value: mes,
                        child: Text(mes, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMonth = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Año
                  DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(
                      labelText: "Seleccionar Año",
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    dropdownColor: grisMetal,
                    style: const TextStyle(color: Colors.white),
                    items: years.map((year) {
                      return DropdownMenuItem<String>(
                        value: year,
                        child: Text(year, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedYear = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulDia,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _assignMes,
                    child: const Text("Asignar Mes"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
