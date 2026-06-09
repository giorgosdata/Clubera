import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/notifications/notifications_service.dart';
import 'core/providers/app_provider.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Init notifications (async, not awaited so it doesn't block app start).
  NotificationsService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const CluperaApp(),
    ),
  );
}
