import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:archive/archive.dart';
// Si usas Flutter >= 3.7, puedes usar badges de Flutter directamente.
// De lo contrario, instala e importa el paquete 'badges' (Badge se usa en el AppBar).

/// Función para transformar un string a Title Case (solo para visualización).
String toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

/// Calcula el siguiente mes a partir de un string con formato "Mes_AAAA".
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

class EstablecimientosScreen extends StatefulWidget {
  const EstablecimientosScreen({Key? key}) : super(key: key);

  @override
  _EstablecimientosScreenState createState() => _EstablecimientosScreenState();
}

class _EstablecimientosScreenState extends State<EstablecimientosScreen> {
  late String establecimiento;
  late String role;
  bool _initialized = false;

  /// Se leerá el mes desde Firestore
  String currentMes = "Cargando...";

  /// Observaciones del establecimiento (subcolección 'observaciones')
  List<Map<String, dynamic>> observaciones = [];

  /// Lista de documentos a gestionar.
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

  /// Documentos que se pueden ignorar.
  final Set<String> ignorableDocs = {
    "Informe Técnico",
    "Inventario",
    "Proyectos Productivos",
    "Documentación HSE",
  };

  /// Mapas para almacenar estados y rutas.
  final Map<String, bool> uploadedStatus = {};
  final Map<String, bool> isUploading = {};
  final Map<String, List<String>> scannedDocumentPages = {};
  final Map<String, String> mergedDocumentPaths = {};
  final Map<String, String> firebaseDownloadUrls = {};
  final Map<String, bool> ignoredDocs = {};

  /// Variables para la cuenta regresiva.
  DateTime? deadline;
  String countdownText = "";
  Color countdownColor = Colors.green;
  Timer? countdownTimer;

  /// Colores de referencia.
  final Color azulNoche = const Color(0xFF00215e);
  final Color grisLuminoso = const Color(0xFFb1b3b3);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>;
      establecimiento = args['establecimiento'] ?? 'establecimiento';
      role = args['role'] ?? 'establecimiento';

      // Inicializar cada documento en los mapas.
      for (var doc in documents) {
        uploadedStatus[doc] = false;
        isUploading[doc] = false;
        scannedDocumentPages[doc] = [];
        mergedDocumentPaths[doc] = "";
        firebaseDownloadUrls[doc] = "";
        ignoredDocs[doc] = false;
      }
      _initialized = true;
      _fetchEstablishmentData();
    }
  }

  /// Obtiene los datos del establecimiento (mes actual, fecha límite, observaciones, docs ignorados, etc.)
  Future<void> _fetchEstablishmentData() async {
    try {
      final establecimientoRef = FirebaseFirestore.instance
          .collection('establecimientos')
          .doc(establecimiento.toLowerCase());

      final docSnapshot = await establecimientoRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;

        setState(() => currentMes = data['mes']?.toString() ?? "No asignado");

        // Cargar observaciones
        final observacionesQuery = await establecimientoRef
            .collection('observaciones')
            .orderBy('fecha', descending: true)
            .get();

        setState(() {
          observaciones = observacionesQuery.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        });

        // Fecha límite
        if (data.containsKey('fecha_limite')) {
          setState(() {
            deadline = (data['fecha_limite'] as Timestamp).toDate();
          });
          _startCountdownTimer();
        }

        // Documentos ignorados
        if (data.containsKey('ignoredDocs')) {
          final ignoredMap = data['ignoredDocs'] as Map<String, dynamic>;
          for (String docName in documents) {
            ignoredDocs[docName] = ignoredMap[docName] ?? false;
          }
        }
      } else {
        setState(() {
          currentMes = "No asignado";
          observaciones = [];
        });
      }

      // Al final, intenta cargar los archivos ya subidos.
      _fetchUploadedFiles();
    } catch (e) {
      print("Error al cargar datos de establecimiento: $e");
      showDialog(
        context: context,
        builder: (BuildContext contextDialog) {
          return AlertDialog(
            title: const Text("Error al cargar datos"),
            content: Text("Ocurrió un problema:\n$e"),
            actions: [
              TextButton(
                child: const Text("Cerrar"),
                onPressed: () => Navigator.of(contextDialog).pop(),
              )
            ],
          );
        },
      );
    }
  }

  /// Carga la lista de archivos subidos desde Firebase Storage y rellena `firebaseDownloadUrls`.
  Future<void> _fetchUploadedFiles() async {
    try {
      final baseRef = firebase_storage.FirebaseStorage.instance
          .ref('uploads/${establecimiento.toLowerCase()}/$currentMes');
      final result = await baseRef.listAll();

      for (var doc in documents) {
        final keyName = doc.replaceAll(" ", "_");
        final matchingItems = result.items.where((item) => item.name.startsWith(keyName));
        if (matchingItems.isNotEmpty) {
          final item = matchingItems.first;
          final downloadUrl = await item.getDownloadURL();
          setState(() {
            firebaseDownloadUrls[doc] = downloadUrl;
            uploadedStatus[doc] = true;
          });
        }
      }
    } catch (e) {
      print("Error fetching uploaded files: $e");
      // Podrías mostrar un diálogo o snackbar si deseas
    }
  }

  /// Inicia la cuenta regresiva que se actualiza cada segundo.
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
          if (days >= 3) {
            countdownColor = Colors.green;
          } else if (days >= 1) {
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

  /// Retorna un `Stream` de la subcolección `observaciones` si necesitas usarlo en tiempo real.
  /// (En este código se hace un fetch puntual, pero aquí está si deseas).
  Stream<List<Map<String, dynamic>>> _getObservacionesStream() {
    return FirebaseFirestore.instance
        .collection('establecimientos')
        .doc(establecimiento.toLowerCase())
        .collection('observaciones')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Navega a la pantalla de observaciones (suponiendo tienes creada esa ruta).
  void _verObservaciones() {
    Navigator.pushNamed(
      context,
      '/observaciones',
      arguments: {'establecimientoId': establecimiento.toLowerCase()},
    );
  }

  /// Comprueba si todos los documentos están completos (subidos o ignorados).
  bool allUploaded() {
    return documents.every((doc) => uploadedStatus[doc]! || (ignoredDocs[doc] ?? false));
  }

  /// Solicita al administrador el cambio al siguiente mes guardando una "autorización" en Firestore.
  void _solicitarSiguienteMes() async {
    try {
      String nextMes = computeNextMonth(currentMes);
      await FirebaseFirestore.instance.collection('autorizaciones').add({
        'establecimiento': establecimiento.toLowerCase(),
        'currentMes': currentMes,
        'nextMes': nextMes,
        'estado': 'pendiente',
        'fecha': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notificación enviada")),
      );
    } catch (e) {
      print("Error creando solicitud: $e");
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Error"),
          content: Text("No se pudo crear la solicitud. Detalle:\n$e"),
          actions: [
            TextButton(
              child: const Text("Cerrar"),
              onPressed: () => Navigator.of(ctx).pop(),
            )
          ],
        ),
      );
    }
  }

  /// Abre el documento usando la URL de descarga, si existe.
  Future<void> _viewDocument(String doc) async {
    final urlString = firebaseDownloadUrls[doc] ?? "";
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

  /// Escanea y agrega una nueva página al documento.
  Future<void> _scanDocument(String doc) async {
    try {
      final scannedResult = await FlutterDocScanner().getScannedDocumentAsPdf(page: 1);
      if (scannedResult is Map && scannedResult.containsKey("pdfUri")) {
        final pdfUri = scannedResult["pdfUri"].toString();
        final uri = Uri.parse(pdfUri);
        final pdfPath = uri.path;
        final originalFile = File(pdfPath);

        if (await originalFile.exists()) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final newPath = '${appDocDir.path}/${doc.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final newFile = await originalFile.copy(newPath);

          setState(() {
            scannedDocumentPages[doc]!.add(newFile.path);
            uploadedStatus[doc] = scannedDocumentPages[doc]!.isNotEmpty;
            mergedDocumentPaths[doc] = "";
            firebaseDownloadUrls[doc] = "";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Página agregada a '$doc'. Total: ${scannedDocumentPages[doc]!.length}")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("El archivo escaneado no existe.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al escanear el documento.")),
        );
      }
    } on PlatformException catch (e) {
      print("Error al escanear documento: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al escanear: $e")),
      );
    }
  }

  /// Une las páginas escaneadas en un solo PDF y lo sube a Firebase Storage.
  Future<void> _mergeDocument(String doc) async {
    final pages = scannedDocumentPages[doc];
    if (pages == null || pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No hay páginas escaneadas para '$doc'")),
      );
      return;
    }
    try {
      PdfDocument mergedDocument = PdfDocument();
      for (String path in pages) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          PdfDocument scannedDoc = PdfDocument(inputBytes: bytes);

          // Copiamos cada página
          for (int i = 0; i < scannedDoc.pages.count; i++) {
            var scannedPage = scannedDoc.pages[i];
            var template = scannedPage.createTemplate();
            var scannedSize = scannedPage.size;
            var newPage = mergedDocument.pages.add();
            var pageSize = newPage.getClientSize();

            double scale = (pageSize.width / scannedSize.width) < (pageSize.height / scannedSize.height)
                ? pageSize.width / scannedSize.width
                : pageSize.height / scannedSize.height;

            double destWidth = scannedSize.width * scale;
            double destHeight = scannedSize.height * scale;
            double offsetX = (pageSize.width - destWidth) / 2;
            double offsetY = (pageSize.height - destHeight) / 2;

            newPage.graphics.drawPdfTemplate(
              template,
              Offset(offsetX, offsetY),
              Size(destWidth, destHeight),
            );
          }
          scannedDoc.dispose();
        }
      }
      final mergedBytes = await mergedDocument.save();
      mergedDocument.dispose();

      // Guardamos localmente
      final appDocDir = await getApplicationDocumentsDirectory();
      final mergedPdfPath = '${appDocDir.path}/${doc.replaceAll(" ", "_")}_${establecimiento}_$currentMes.pdf';
      final mergedFile = File(mergedPdfPath);
      await mergedFile.writeAsBytes(mergedBytes);

      setState(() {
        mergedDocumentPaths[doc] = mergedPdfPath;
        isUploading[doc] = true;
      });

      // Subimos a Firebase
      final downloadUrl = await _uploadMergedDocument(doc);
      setState(() {
        firebaseDownloadUrls[doc] = downloadUrl;
        isUploading[doc] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF unificado para '$doc' subido correctamente.")),
      );
    } catch (e) {
      print("Error al unir los PDFs para '$doc': $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al unir los PDFs: $e")),
      );
    }
  }

  /// Sube el PDF unificado a Firebase Storage y retorna la URL de descarga.
  Future<String> _uploadMergedDocument(String doc) async {
    final mergedPdfPath = mergedDocumentPaths[doc];
    if (mergedPdfPath == null || mergedPdfPath.isEmpty) {
      throw Exception("No hay PDF unificado para '$doc'");
    }
    final file = File(mergedPdfPath);

    try {
      final fileName = '${doc.replaceAll(" ", "_")}_${establecimiento}_$currentMes.pdf';
      final destination = 'uploads/${establecimiento.toLowerCase()}/$currentMes/$fileName';

      final snapshot = await firebase_storage.FirebaseStorage.instance
          .ref(destination)
          .putFile(
        file,
        firebase_storage.SettableMetadata(contentType: 'application/pdf'),
      );

      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error subiendo archivo: $e");
      rethrow;
    }
  }

  /// Ignorar o revertir la ignorancia de un documento.
  void _ignoreDocument(String doc) {
    if (!(ignoredDocs[doc] ?? false)) {
      // Si no está ignorado, pedir confirmación para ignorar
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text("Confirmar"),
            content: const Text("¿Desea ignorar este documento?"),
            actions: [
              TextButton(
                child: const Text("Cancelar"),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: const Text("Confirmar"),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  setState(() {
                    ignoredDocs[doc] = true;
                  });
                  _updateIgnoredDocsInFirestore();
                },
              ),
            ],
          );
        },
      );
    } else {
      // Si ya está ignorado, ofrecer revertir
      _revertIgnoreDocument(doc);
    }
  }

  /// Ofrece revertir la acción de ignorado.
  void _revertIgnoreDocument(String doc) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Revertir Acción"),
          content: const Text("¿Desea permitir subir el documento nuevamente?"),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text("Confirmar"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  ignoredDocs[doc] = false;
                });
                _updateIgnoredDocsInFirestore();
              },
            ),
          ],
        );
      },
    );
  }

  /// Actualiza en Firestore el campo 'ignoredDocs' con el estado actual.
  Future<void> _updateIgnoredDocsInFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('establecimientos')
          .doc(establecimiento.toLowerCase())
          .update({'ignoredDocs': ignoredDocs});
    } catch (e) {
      print("Error updating ignoredDocs in Firestore: $e");
    }
  }

  /// Reinicia el estado de un documento (para volverlo a escanear).
  void _rescanDocument(String doc) {
    setState(() {
      scannedDocumentPages[doc] = [];
      mergedDocumentPaths[doc] = "";
      firebaseDownloadUrls[doc] = "";
      uploadedStatus[doc] = false;
      ignoredDocs[doc] = false;
    });
    // Si subiste ZIP de todo, podría interesarte borrarlo:
    // final zipFileName = '${establecimiento.toLowerCase()}_$currentMes.zip';
    // final zipPathInStorage = 'uploads/${establecimiento.toLowerCase()}/$currentMes/$zipFileName';
    // firebase_storage.FirebaseStorage.instance.ref(zipPathInStorage).delete().catchError((error) {
    //   print("Error deleting ZIP file: $error");
    // });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Documento '$doc' reiniciado.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = documents.length;
    final completed = documents.where((doc) => uploadedStatus[doc]! || (ignoredDocs[doc] ?? false)).length;
    final progress = total > 0 ? completed / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "${toTitleCase(establecimiento)} - ${role.toUpperCase()}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: azulNoche,
        actions: [
          // Badge con la cuenta de observaciones
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('establecimientos')
                .doc(establecimiento.toLowerCase())
                .collection('observaciones')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Icon(Icons.error);
              if (!snapshot.hasData) return const Icon(Icons.message);

              final count = snapshot.data!.docs.length;
              // El Badge de Flutter 3.7+ se usa así (Badge.count si lo tienes disponible).
              // O con un paquete de badges, algo como:
              // return Badge(
              //   badgeContent: Text(count.toString()),
              //   child: IconButton( ... )
              // );
              return Badge(
                label: Text(count.toString()),
                child: IconButton(
                  icon: const Icon(Icons.message, color: Colors.white),
                  onPressed: _verObservaciones,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: "Cerrar Sesión",
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext contextDialog) {
                  return AlertDialog(
                    title: const Text("Confirmar"),
                    content: const Text("¿Desea cerrar sesión?"),
                    actions: [
                      TextButton(
                        child: const Text("Cancelar"),
                        onPressed: () => Navigator.of(contextDialog).pop(),
                      ),
                      TextButton(
                        child: const Text("Confirmar"),
                        onPressed: () {
                          Navigator.of(contextDialog).pop();
                          Navigator.pushReplacementNamed(context, '/');
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Sección de progreso y cuenta regresiva.
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
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
                  final doc = documents[index];
                  final pageCount = scannedDocumentPages[doc]?.length ?? 0;
                  final firebaseUrl = firebaseDownloadUrls[doc] ?? "";
                  final isMerged = firebaseUrl.isNotEmpty || (mergedDocumentPaths[doc]?.isNotEmpty ?? false);

                  // Determinamos el color de la tarjeta.
                  Color? cardColor;
                  if (ignoredDocs[doc] == true) {
                    cardColor = grisLuminoso;
                  } else if (firebaseUrl.isNotEmpty) {
                    cardColor = Colors.green[300];
                  } else if (isUploading[doc] == true) {
                    cardColor = Colors.orange[300];
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
                            if (ignoredDocs[doc] == true)
                            // Documento ignorado
                              Column(
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
                                  const Text(
                                    "NO REQUERIDO",
                                    style: TextStyle(fontSize: 12, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _revertIgnoreDocument(doc),
                                    child: const Text("Revertir"),
                                  ),
                                ],
                              )
                            else
                            // Documento pendiente, subido o en proceso
                              Column(
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
                                  Text(
                                    "Páginas: $pageCount",
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  if (!isMerged) ...[
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueGrey,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _scanDocument(doc),
                                      child: Text(
                                        pageCount > 0 ? "Agregar Página" : "Escanear Documento",
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (pageCount > 0)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueGrey,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _mergeDocument(doc),
                                        child: const Text("Unir PDF"),
                                      ),
                                  ] else ...[
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueGrey,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _viewDocument(doc),
                                      child: const Text("Ver Documento"),
                                    ),
                                    const SizedBox(height: 5),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueGrey,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _rescanDocument(doc),
                                      child: const Text("Re Escanear"),
                                    ),
                                  ],
                                  if (ignorableDocs.contains(doc)) ...[
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueGrey,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _ignoreDocument(doc),
                                      child: const Text("Ignorar"),
                                    ),
                                  ],
                                ],
                              ),
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
      bottomNavigationBar: Container(
        color: azulNoche,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Mes: ${currentMes.replaceAll("_", " ")}",
              style: const TextStyle(color: Colors.white),
            ),
            if (allUploaded())
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
                onPressed: _solicitarSiguienteMes,
                child: const Text("Siguiente Mes"),
              )
            else
              const Text("Faltan documentos", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

