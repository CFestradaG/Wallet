import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase options are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCIJY8XLlb5Bhsc1hd4pnB14qq6luQ-W9I',
    appId: '1:862971153777:android:2b3f32e77981d69fabbad0',
    messagingSenderId: '862971153777',
    projectId: 'fintrack-gt',
    storageBucket: 'fintrack-gt.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAiFV7SkWlVeVZ2xGwPMpc8oq6MfRYbNMM',
    appId: '1:862971153777:web:fc1ecc508e7da70dabbad0',
    authDomain: 'fintrack-gt.firebaseapp.com',
    messagingSenderId: '862971153777',
    projectId: 'fintrack-gt',
    storageBucket: 'fintrack-gt.firebasestorage.app',
  );
}
