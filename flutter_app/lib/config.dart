import 'package:firebase_core/firebase_core.dart';

/// Set via --dart-define at build time. Never place service-account credentials here.
class AppConfig {
  static const apiBase = String.fromEnvironment('API_BASE_URL');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  static FirebaseOptions get firebase => const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
  );
}
