import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCWZEKZ26LX5c2Rwr_7uR5kULanEkxzFZI',
    appId: '1:707857386973:web:f13fed4f6e68699efb7a34',
    messagingSenderId: '707857386973',
    projectId: 'recygo-d207f',
    authDomain: 'recygo-d207f.firebaseapp.com',
    storageBucket: 'recygo-d207f.firebasestorage.app',
  );
}
