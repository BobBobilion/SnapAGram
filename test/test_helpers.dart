import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapagram/firebase_options.dart';

class MockFirebaseCoreHostApi implements FirebaseCoreHostApi {
  @override
  Future<void> initializeApp(
      String appName, FirebaseOptions options) async {}

  @override
  Future<List<FirebaseApp>> getApps() async {
    return [];
  }

  @override
  Future<FirebaseApp?> app(String name) async {
    return null;
  }
}

void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Mock FirebaseCoreHostApi
  FirebaseCoreHostApi.instance = MockFirebaseCoreHostApi();
  Firebase.apps.clear();
}

Future<void> setupFirebase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Mock Firebase initialization
  setupFirebaseCoreMocks();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}