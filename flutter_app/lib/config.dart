import 'package:firebase_core/firebase_core.dart';

/// Set via --dart-define at build time (with production public defaults). Never place service-account credentials here.
class AppConfig {
  static const apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tasklog-api.vercel.app',
  );
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyAeKzeuwjLr0GfC1dyS-mYnGlWCYnQnOPQ',
  );
  static const appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:53646772905:web:684fea482d7b552030f7b8',
  );
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '53646772905',
  );
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'tasklog-dcb8b',
  );
  static const authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'tasklog-dcb8b.firebaseapp.com',
  );

  static FirebaseOptions get firebase => const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
      );
}
