import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Importa tus pantallas existentes:
import 'package:facturacion_app/screens/splash_screen.dart';
import 'package:facturacion_app/screens/login_screen.dart';
import 'package:facturacion_app/screens/establecimientos_screen.dart';
import 'package:facturacion_app/screens/facturacion_home_screen.dart';
import 'package:facturacion_app/screens/asignar_fecha_screen.dart';
import 'package:facturacion_app/screens/asignar_mes_screen.dart';
import 'package:facturacion_app/screens/select_establecimiento_screen.dart' as selectEst;
import 'package:facturacion_app/screens/admin_login_screen.dart';
import 'package:facturacion_app/screens/admin_dashboard_screen.dart';
import 'package:facturacion_app/screens/change_password_screen.dart';
import 'package:facturacion_app/screens/facturacion_profile_screen.dart';
import 'package:facturacion_app/screens/autorizaciones_screen.dart';
import 'package:facturacion_app/screens/observaciones_screen.dart';
import 'package:facturacion_app/screens/escribir_observaciones.dart';

/// Transiciones con Fade para una navegación suave
class FadeTransitionBuilder extends PageTransitionsBuilder {
  const FadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate();
  runApp(const FacturacionApp());
}

class FacturacionApp extends StatelessWidget {
  const FacturacionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Definición de colores según tu paleta
    const Color azulDia = Color(0xFF0073cb);
    const Color azulNoche = Color(0xFF00215e);
    const Color grisMetal = Color(0xFF53565a);

    final ThemeData miTema = ThemeData(
      primaryColor: azulDia,
      scaffoldBackgroundColor: azulNoche,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        color: azulDia,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStatePropertyAll(grisMetal),
          foregroundColor: MaterialStatePropertyAll(Colors.white),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeTransitionBuilder(),
          TargetPlatform.iOS: FadeTransitionBuilder(),
        },
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Facturación App - Scanner',
      theme: miTema,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LoginScreen(),
        '/establecimientos': (context) => const EstablecimientosScreen(),
        '/facturacion_home': (context) => const FacturacionHomeScreen(),
        '/asignar_fecha': (context) => const AsignarFechaScreen(),
        '/asignar_mes': (context) => const AsignarMesScreen(),
        '/select_establecimiento': (context) => const selectEst.SelectEstablecimientoScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/change_password': (context) => const ChangePasswordScreen(),
        '/facturacion_profile': (context) => const FacturacionProfileScreen(),
        '/autorizaciones': (context) => const AutorizacionesScreen(),
        '/observaciones': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ObservacionesScreen(establecimientoId: args['establecimientoId']);
        },
        // Ruta para la pantalla de Escribir Observaciones
        '/escribir_observaciones': (context) => const EscribirObservacionesScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
