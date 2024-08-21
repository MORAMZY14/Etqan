import 'package:firebase_core/firebase_core.dart';

class FirebaseInitializer {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        name:"Etqan",
        options: const FirebaseOptions(
            apiKey: "AIzaSyA9xV4MuX4_HIkNCRWy2dNOgRRfDPa8cw0",
            authDomain: "etqan-center.firebaseapp.com",
            databaseURL: "https://etqan-center-default-rtdb.europe-west1.firebasedatabase.app",
            projectId: "etqan-center",
            storageBucket: "etqan-center.appspot.com",
            messagingSenderId: "277429609000",
            appId: "1:277429609000:web:bc2aa6591bdd1d44104b1d",
            measurementId: "G-72MJ3Y2X2G"
        ),
      );
      print('Firebase initialized');
    } else {
      print('Firebase already initialized');
    }
  }
}
