import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Función para mostrar en Title Case sin afectar la lógica interna
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

class FacturacionHomeScreen extends StatefulWidget {
  const FacturacionHomeScreen({Key? key}) : super(key: key);

  @override
  _FacturacionHomeScreenState createState() => _FacturacionHomeScreenState();
}

class _FacturacionHomeScreenState extends State<FacturacionHomeScreen> {
  // Documentos requeridos
  final List<String> requiredDocs = [
    "Cuadro de Raciones",
    "Servicio del Agua",
    "Servicio del Gas",
    "Servicio de Energía",
    "Informe Técnico",
    "Inventario",
    "Proyectos Productivos",
    "Contractuales",
    "Documentación HSE",
    "Paz y Salvo",
    "Nominas",
    "Seguridad Social",
  ];

  // Lista de meses disponibles
  List<String> availableMonths = [];
  String? selectedMonth;

  // Future que retorna la lista de establecimientos con su progreso
  Future<List<Map<String, dynamic>>>? establishmentsFuture;

  @override
  void initState() {
    super.initState();
    // Primero obtenemos los meses disponibles
    _fetchAvailableMonths().then((_) {
      // Seleccionamos el primero (o el que desees) si hay alguno
      if (availableMonths.isNotEmpty) {
        selectedMonth = availableMonths.first;
      }
      // Cargamos la lista de establecimientos con su progreso
      establishmentsFuture = _fetchEstablishmentsProgress();
      setState(() {});
    });
  }

  /// Obtiene todos los meses disponibles en `uploads/<establecimiento>/<mes>`
  Future<void> _fetchAvailableMonths() async {
    try {
      final rootResult = await firebase_storage.FirebaseStorage.instance.ref('uploads').listAll();
      final Set<String> monthsSet = {};
      for (var estPrefix in rootResult.prefixes) {
        final subResult = await estPrefix.listAll();
        for (var monthPrefix in subResult.prefixes) {
          monthsSet.add(monthPrefix.name);
        }
      }
      availableMonths = monthsSet.toList()..sort();
    } catch (e) {
      print("Error fetching available months: $e");
    }
  }

  /// Para cada establecimiento en `uploads`, calculamos el progreso considerando:
  /// - Los documentos ignorados se tratan como no requeridos.
  /// - Se cuenta como completado solo si el documento (no ignorado) está subido.
  Future<List<Map<String, dynamic>>> _fetchEstablishmentsProgress() async {
    List<Map<String, dynamic>> results = [];
    if (selectedMonth == null || selectedMonth!.isEmpty) return results;

    try {
      // Obtenemos la lista de establecimientos (subcarpetas en `uploads`)
      final rootResult = await firebase_storage.FirebaseStorage.instance.ref('uploads').listAll();
      List<String> estNames = rootResult.prefixes.map((p) => p.name).toList();
      estNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      for (String estName in estNames) {
        Map<String, bool> ignoredDocsMap = await _fetchIgnoredDocsForEstablishment(estName);
        int ignoredCount = 0;
        int requiredEffective = 0;
        int uploadedCount = 0;

        try {
          final estMonthRef = firebase_storage.FirebaseStorage.instance
              .ref('uploads/${estName.toLowerCase()}/$selectedMonth');
          final monthResult = await estMonthRef.listAll();

          for (String doc in requiredDocs) {
            bool isIgnored = ignoredDocsMap[doc] ?? false;
            if (isIgnored) {
              ignoredCount++;
            } else {
              requiredEffective++;
              String keyName = doc.replaceAll(" ", "_");
              var matching = monthResult.items.where((item) => item.name.startsWith(keyName));
              if (matching.isNotEmpty) {
                uploadedCount++;
              }
            }
          }
        } catch (e) {
          print("Error al listar mes para $estName: $e");
        }

        double progress = requiredEffective > 0 ? uploadedCount / requiredEffective : 1.0;

        results.add({
          'name': estName,
          'displayName': toTitleCase(estName),
          'uploaded': uploadedCount,
          'requiredEffective': requiredEffective,
          'progress': progress,
          'ignored': ignoredCount,
        });
      }
    } catch (e) {
      print("Error listing establishments: $e");
    }
    return results;
  }

  /// Obtiene el mapa de documentos ignorados para un establecimiento
  Future<Map<String, bool>> _fetchIgnoredDocsForEstablishment(String estName) async {
    Map<String, bool> result = {};
    try {
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('establecimientos')
          .doc(estName)
          .get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        if (data.containsKey('ignoredDocs')) {
          final Map<String, dynamic> ignoredMap = data['ignoredDocs'];
          for (String doc in ignoredMap.keys) {
            result[doc] = ignoredMap[doc] == true;
          }
        }
      }
    } catch (e) {
      print("Error fetching ignoredDocs for $estName: $e");
    }
    return result;
  }

  /// Cambia el mes seleccionado y recarga la lista
  void _onMonthChanged(String? newMonth) {
    setState(() {
      selectedMonth = newMonth;
      establishmentsFuture = _fetchEstablishmentsProgress();
    });
  }

  /// Drawer con fondo y texto en colores correctos
  Widget _buildDrawer(BuildContext context) {
    const Color azulNoche = Color(0xFF00215e);
    const Color azulDia = Color(0xFF0073cb);

    return Drawer(
      backgroundColor: azulNoche,
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: azulDia),
              accountName: const Text("Usuario Facturación", style: TextStyle(fontSize: 18, color: Colors.white)),
              accountEmail: const Text(""),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text("F", style: TextStyle(fontSize: 30, color: azulDia)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.white),
              title: const Text("Inicio", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/facturacion_home');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store, color: Colors.white),
              title: const Text("Seleccionar Establecimiento", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/select_establecimiento', arguments: {'role': 'facturacion'});
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.white),
              title: const Text("Asignar Fecha Límite", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/asignar_fecha');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.white),
              title: const Text("Asignar Mes de Archivos", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/asignar_mes');
              },
            ),
            // Nuevo botón para Escribir Observaciones
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text("Escribir Observaciones", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/escribir_observaciones');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check, color: Colors.white),
              title: const Text("Autorización Siguiente Mes", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/autorizaciones');
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.white),
              title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color azulNoche = Color(0xFF00215e);
    const Color azulDia = Color(0xFF0073cb);

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: azulDia,
        title: const Text("Menú Facturación", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: azulNoche,
      body: Column(
        children: [
          // Filtro de Meses
          if (availableMonths.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: selectedMonth,
                decoration: const InputDecoration(
                  labelText: "Seleccionar Mes",
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
                dropdownColor: azulNoche,
                style: const TextStyle(color: Colors.white),
                items: availableMonths.map((mes) {
                  return DropdownMenuItem<String>(
                    value: mes,
                    child: Text(mes, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: _onMonthChanged,
              ),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No hay meses disponibles", style: TextStyle(color: Colors.white)),
            ),
          ],
          // Lista de todos los establecimientos sin navegación a profile
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: establishmentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No se encontraron establecimientos.", style: TextStyle(color: Colors.white)));
                } else {
                  final establishments = snapshot.data!;
                  return ListView.builder(
                    itemCount: establishments.length,
                    itemBuilder: (context, index) {
                      final est = establishments[index];
                      final String displayName = est['displayName'] ?? '';
                      final int uploaded = est['uploaded'] ?? 0;
                      final int requiredEffective = est['requiredEffective'] ?? 0;
                      final double progress = est['progress'] ?? 0.0;
                      final int ignoredCount = est['ignored'] ?? 0;

                      return Card(
                        color: const Color(0xFF53565a),
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          // Se elimina la navegación: el onTap se deja vacío
                          onTap: () {},
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Documentos: $uploaded de $requiredEffective completados",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (ignoredCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text("Documentos ignorados: $ignoredCount",
                                      style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                                ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: Colors.red[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
