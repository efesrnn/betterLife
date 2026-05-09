// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_options.dart';
import 'habit_selection_screen.dart'; // YENİ: Dosyamızı buraya dahil ettik
import 'auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Better Life',
      debugShowCheckedModeBanner: false, // Sağ üstteki "DEBUG" yazısını kaldırır
      theme: ThemeData(
        fontFamily: 'Comic Sans MS', // Tasarımın el çizimi hissiyatını artırmak için eklenebilir (opsiyonel)
        scaffoldBackgroundColor: Colors.white,
      ),
      // YENİ: Başlangıç ekranımızı tasarladığımız ekran yapıyoruz
      home: const AuthScreen(),
    );
  }
}