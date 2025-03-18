import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:url_launcher/url_launcher.dart';

/// Función auxiliar para transformar un string a Title Case (solo para visualización)
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

class FacturacionProfileScreen extends StatefulWidget {
  const FacturacionProfileScreen({Key? key}) : super(key: key);

  @override
  _FacturacionProfileScreenState createState() =>
      _FacturacionProfileScreenState();
}

class _FacturacionProfileScreenState extends State<FacturacionProfileScreen> {
  late String establecimiento;
  late String role;
  bool _initialized = false;

  // Se reemplaza el mes fijo por variables de estado para manejar el filtro
  List<String> availableMonths = [];
  String? selectedMonth;

  // Lista de documentos requeridos.
  final List<String> documents = [
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

  // Estados locales:
  final Map<String, String> firebaseDownloadUrls = {}; // URL de cada doc
  final Map<String, bool> uploadedStatus = {}; // Si está subido
  final Map<String, bool> ignoredDocs = {}; // Si está ignorado

  // Paleta de colores.
  final Color azulNoche = const Color(0xFF00215e);
  final Color azulDia = const Color(0xFF0073cb);
  final Color grisMetal = const Color(0xFF53565a);
  final Color grisLuminoso = const Color(0xFFb1b3b3); // Para documentos ignorados

  // Variables para la cuenta regresiva.
  DateTime? deadline;
  String countdownText = "";
  Color countdownColor = Colors.green;
  Timer? countdownTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final Map args =
      ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>;
      // Se espera que se pase en minúsculas para Firebase, pero se muestra en TitleCase para la UI.
      establecimiento = args['establecimiento'] ?? 'establecimiento';
      role = args['role'] ?? 'facturacion';

      // Inicializa cada documento.
      for (var doc in documents) {
        firebaseDownloadUrls[doc] = "";
        uploadedStatus[doc] = false;
        ignoredDocs[doc] = false;
      }
      _fetchAvailableMonths().then((_) {
        // Selecciona el primer mes disponible si existe.
        if (availableMonths.isNotEmpty) {
          setState(() {
            selectedMonth = availableMonths.first;
          });
          _fetchUploadedFiles();
        }
      });
      _fetchDeadlineAndIgnored();
      _initialized = true;
    }
  }

  /// Obtiene todos los meses disponibles en `uploads/<establecimiento>/<mes>`
  Future<void> _fetchAvailableMonths() async {
    try {
      final ref = firebase_storage.FirebaseStorage.instance
          .ref('uploads/${establecimiento.toLowerCase()}');
      final result = await ref.listAll();
      final Set<String> monthsSet = {};
      for (var monthPrefix in result.prefixes) {
        monthsSet.add(monthPrefix.name);
      }
      setState(() {
        availableMonths = monthsSet.toList()..sort();
      });
    } catch (e) {
      print("Error fetching available months: $e");
    }
  }

  /// Obtiene la fecha límite y el mapa 'ignoredDocs' desde Firestore.
  Future<void> _fetchDeadlineAndIgnored() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('establecimientos')
          .doc(establecimiento)
          .get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('fecha_limite')) {
          setState(() {
            deadline = (data['fecha_limite'] as Timestamp).toDate();
          });
          _startCountdownTimer();
        }
        if (data.containsKey('ignoredDocs')) {
          Map<String, dynamic> ignoredMap = data['ignoredDocs'];
          for (String doc in documents) {
            ignoredDocs[doc] = ignoredMap[doc] ?? false;
          }
        }
      }
    } catch (e) {
      print("Error fetching deadline/ignoredDocs: $e");
    }
  }

  /// Inicia la cuenta regresiva.
  void _startCountdownTimer() {
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (deadline == null) return;
      final diff = deadline!.difference(DateTime.now());
      if (diff.isNegative) {
        setState(() {
          countdownText = "Vencido";
          countdownColor = Colors.red;
        });
        timer.cancel();
      } else {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        final minutes = diff.inMinutes % 60;
        final seconds = diff.inSeconds % 60;
        setState(() {
          countdownText =
          "$days días, ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
          if (diff.inDays >= 3) {
            countdownColor = Colors.green;
          } else if (diff.inDays >= 1) {
            countdownColor = Colors.orange;
          } else {
            countdownColor = Colors.red;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  /// Recupera las URLs de descarga de Firebase Storage para cada documento, usando el mes seleccionado.
  Future<void> _fetchUploadedFiles() async {
    if (selectedMonth == null || selectedMonth!.isEmpty) return;
    try {
      final baseRef = firebase_storage.FirebaseStorage.instance.ref(
          'uploads/${establecimiento.toLowerCase()}/$selectedMonth');
      final firebase_storage.ListResult result = await baseRef.listAll();

      for (var doc in documents) {
        String keyName = doc.replaceAll(" ", "_");
        final matchingItems =
        result.items.where((item) => item.name.startsWith(keyName));
        if (matchingItems.isNotEmpty) {
          final item = matchingItems.first;
          final downloadUrl = await item.getDownloadURL();
          setState(() {
            firebaseDownloadUrls[doc] = downloadUrl;
            uploadedStatus[doc] = true;
          });
          print("Archivo para $doc recuperado: $downloadUrl");
        } else {
          setState(() {
            firebaseDownloadUrls[doc] = "";
            uploadedStatus[doc] = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching uploaded files: $e");
    }
  }

  /// Maneja el cambio del mes en el filtro. Se actualiza el estado y se recargan los archivos.
  void _onMonthChanged(String? newMonth) {
    if (newMonth == null) return;
    setState(() {
      selectedMonth = newMonth;
      // Reinicia los estados de cada documento
      for (var doc in documents) {
        firebaseDownloadUrls[doc] = "";
        uploadedStatus[doc] = false;
      }
    });
    _fetchUploadedFiles();
  }

  /// Verifica si todos los documentos están completos (subidos o ignorados)
  bool allUploaded() {
    return documents.every((doc) =>
    uploadedStatus[doc]! || (ignoredDocs[doc] ?? false));
  }

  /// Descarga el documento usando su URL.
  Future<void> _viewDocument(String doc) async {
    String urlString = firebaseDownloadUrls[doc] ?? "";
    if (urlString.isNotEmpty) {
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir el documento.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se ha subido el documento para '$doc'.")),
      );
    }
  }

  /// Función para borrar un documento (botón "Borrar"), con confirmación.
  Future<void> _deleteDocument(String doc) async {
    if (ignoredDocs[doc] == true || firebaseDownloadUrls[doc]!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Este documento no puede borrarse.")),
      );
      return;
    }
    String keyName = doc.replaceAll(" ", "_");
    String fileName = '${keyName}_${establecimiento}_$selectedMonth.pdf';
    String destination =
        'uploads/${establecimiento.toLowerCase()}/$selectedMonth/$fileName';
    bool confirm = false;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Confirmar Borrado"),
          content: Text("¿Está seguro de borrar el documento '$doc'?"),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text("Confirmar"),
              onPressed: () {
                confirm = true;
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );

    if (!confirm) return;

    try {
      await firebase_storage.FirebaseStorage.instance
          .ref(destination)
          .delete();
      setState(() {
        firebaseDownloadUrls[doc] = "";
        uploadedStatus[doc] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Documento '$doc' borrado correctamente.")),
      );
    } on firebase_storage.FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        setState(() {
          firebaseDownloadUrls[doc] = "";
          uploadedStatus[doc] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "El documento '$doc' no existía en Storage; se actualizó el estado local.")),
        );
      } else {
        print("Error borrando documento: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al borrar el documento: $e")),
        );
      }
    } catch (e) {
      print("Error borrando documento: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al borrar el documento: $e")),
      );
    }
  }

  /// Descarga el ZIP con todos los documentos del mes.
  Future<void> _downloadZip() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generando ZIP del mes...")),
    );
    try {
      String zipFileName =
          '${establecimiento.toLowerCase()}_$selectedMonth.zip';
      String zipPathInStorage =
          'uploads/${establecimiento.toLowerCase()}/$selectedMonth/$zipFileName';
      firebase_storage.Reference zipRef =
      firebase_storage.FirebaseStorage.instance.ref(zipPathInStorage);
      String downloadUrl;
      try {
        await zipRef.getMetadata();
        downloadUrl = await zipRef.getDownloadURL();
        print("ZIP ya existe. URL: $downloadUrl");
      } catch (e) {
        final folderRef = firebase_storage.FirebaseStorage.instance.ref(
            'uploads/${establecimiento.toLowerCase()}/$selectedMonth');
        final firebase_storage.ListResult result = await folderRef.listAll();
        final Archive archive = Archive();
        for (final item in result.items) {
          final data = await item.getData();
          if (data != null) {
            archive.addFile(ArchiveFile(item.name, data.length, data));
          }
        }
        final zipData = ZipEncoder().encode(archive);
        if (zipData != null) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final localZipPath = '${appDocDir.path}/$zipFileName';
          final zipFile = File(localZipPath);
          await zipFile.writeAsBytes(zipData);
          final snapshot = await zipRef.putFile(
            zipFile,
            firebase_storage.SettableMetadata(contentType: 'application/zip'),
          );
          downloadUrl = await snapshot.ref.getDownloadURL();
          print("ZIP generado y subido. URL: $downloadUrl");
        } else {
          throw Exception("Error al generar ZIP.");
        }
      }
      final Uri url = Uri.parse(downloadUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir el ZIP.")),
        );
      }
    } catch (e) {
      print("Error al descargar ZIP: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al descargar el ZIP: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int total = documents.length;
    int completed = documents
        .where((doc) => uploadedStatus[doc]! || (ignoredDocs[doc] ?? false))
        .length;
    double progress = total > 0 ? completed / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "${toTitleCase(establecimiento)} - ${role.toUpperCase()}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: azulNoche,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Sección de progreso y cuenta regresiva (opcional).
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Documentación: $completed de $total completados",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.red[200],
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 12),
                  if (deadline != null)
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          "Tiempo restante: $countdownText",
                          style: TextStyle(color: countdownColor, fontSize: 16),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Grilla de documentos.
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  String doc = documents[index];
                  bool isIgnored = ignoredDocs[doc] ?? false;
                  bool isUploaded = uploadedStatus[doc]!;

                  Color? cardColor;
                  if (isIgnored) {
                    cardColor = grisLuminoso;
                  } else if (isUploaded) {
                    cardColor = Colors.green[300];
                  } else {
                    cardColor = Colors.red[300];
                  }

                  return Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              doc,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (isIgnored) ...[
                              const Text(
                                "Documento ignorado",
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ] else if (isUploaded) ...[
                              const Text(
                                "Documento subido",
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _viewDocument(doc),
                                child: const Text("Descargar Documento"),
                              ),
                              const SizedBox(height: 5),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _deleteDocument(doc),
                                child: const Text("Borrar"),
                              ),
                            ] else ...[
                              const Text(
                                "Sin documento",
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Filtro de meses en el bottomNavigationBar
      bottomNavigationBar: Container(
        color: azulNoche,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DropdownButton<String>(
              value: selectedMonth,
              dropdownColor: azulNoche,
              style: const TextStyle(color: Colors.white),
              underline: Container(
                height: 1,
                color: Colors.white70,
              ),
              items: availableMonths.map((mes) {
                return DropdownMenuItem<String>(
                  value: mes,
                  child: Text(mes, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: _onMonthChanged,
            ),
            if (allUploaded())
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
                onPressed: _downloadZip,
                child: const Text("Descargar ZIP"),
              )
            else
              const Text("Faltan documentos",
                  style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
