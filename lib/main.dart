import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Needed for Hive.initFlutter
import 'package:path_provider/path_provider.dart';
import 'package:strada/view/auth/signin_screen/signin_screen.dart';
import 'package:strada/view/splash/splash_screen.dart';

import 'firebase_options.dart';
import 'model/product_model/product_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Optional: Disable Firestore cache
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize Hive
  if (kIsWeb) {
    await Hive.initFlutter(); // Web-safe Hive init
  } else {
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path); // Mobile/Desktop
  }

  // Register adapter and open boxes
  Hive.registerAdapter(ProductAdapter());
  await Hive.openBox<Product>('productsBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Strada',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: SplashScreen(),
      ),
    );
  }
}
