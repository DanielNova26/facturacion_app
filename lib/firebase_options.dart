// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC_Ck2thtxo_aJ6Zh5rRVk8toVNqBvg1lM',
    appId: '1:1076885236991:web:051f70e7f61c37c9e7f0ca',
    messagingSenderId: '1076885236991',
    projectId: 'facturacionapp-b85c9',
    storageBucket: 'facturacionapp-b85c9.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC_Ck2thtxo_aJ6Zh5rRVk8toVNqBvg1lM',
    appId: '1:1076885236991:web:051f70e7f61c37c9e7f0ca',
    messagingSenderId: '1076885236991',
    projectId: 'facturacionapp-b85c9',
    authDomain: 'facturacionapp-b85c9.firebaseapp.com',
    storageBucket: 'facturacionapp-b85c9.firebasestorage.app',
    measurementId: 'G-RDZ27J5WSG',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyARFJ_BYckrrf5aY_AMuoF2hAaezfZS0Ug',
    appId: '1:1076885236991:ios:19a4ff1de47df947e7f0ca',
    messagingSenderId: '1076885236991',
    projectId: 'facturacionapp-b85c9',
    storageBucket: 'facturacionapp-b85c9.firebasestorage.app',
    iosBundleId: 'com.example.facturacionApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyARFJ_BYckrrf5aY_AMuoF2hAaezfZS0Ug',
    appId: '1:1076885236991:ios:19a4ff1de47df947e7f0ca',
    messagingSenderId: '1076885236991',
    projectId: 'facturacionapp-b85c9',
    storageBucket: 'facturacionapp-b85c9.firebasestorage.app',
    iosBundleId: 'com.example.facturacionApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC_Ck2thtxo_aJ6Zh5rRVk8toVNqBvg1lM',
    appId: '1:1076885236991:web:bfdc5477f3133eeae7f0ca',
    messagingSenderId: '1076885236991',
    projectId: 'facturacionapp-b85c9',
    authDomain: 'facturacionapp-b85c9.firebaseapp.com',
    storageBucket: 'facturacionapp-b85c9.firebasestorage.app',
    measurementId: 'G-X4BFGHT41Q',
  );
}
