import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCqC_0SJe8fnSyZGS-QGN92Ee7hAvHAC48',
    appId: '1:418723985397:web:4505fbd46991c2211652bc',
    messagingSenderId: '418723985397',
    projectId: 'snapagram-ac74f',
    authDomain: 'snapagram-ac74f.firebaseapp.com',
    storageBucket: 'snapagram-ac74f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqC_0SJe8fnSyZGS-QGN92Ee7hAvHAC48',
    appId: '1:418723985397:web:4505fbd46991c2211652bc',
    messagingSenderId: '418723985397',
    projectId: 'snapagram-ac74f',
    storageBucket: 'snapagram-ac74f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCqC_0SJe8fnSyZGS-QGN92Ee7hAvHAC48',
    appId: '1:418723985397:web:4505fbd46991c2211652bc',
    messagingSenderId: '418723985397',
    projectId: 'snapagram-ac74f',
    storageBucket: 'snapagram-ac74f.firebasestorage.app',
    iosBundleId: 'com.example.snapagram',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCqC_0SJe8fnSyZGS-QGN92Ee7hAvHAC48',
    appId: '1:418723985397:web:4505fbd46991c2211652bc',
    messagingSenderId: '418723985397',
    projectId: 'snapagram-ac74f',
    storageBucket: 'snapagram-ac74f.firebasestorage.app',
    iosBundleId: 'com.example.snapagram',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCqC_0SJe8fnSyZGS-QGN92Ee7hAvHAC48',
    appId: '1:418723985397:web:4505fbd46991c2211652bc',
    messagingSenderId: '418723985397',
    projectId: 'snapagram-ac74f',
    storageBucket: 'snapagram-ac74f.firebasestorage.app',
  );
} 