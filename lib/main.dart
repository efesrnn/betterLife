// lib/main.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_options.dart';
import 'services/service_locator.dart';
import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) easy_localization init (assets/translations okumadan önce gerekli)
  await EasyLocalization.ensureInitialized();

  // 2) .env dosyasını yükle. .env yoksa uygulama yine de açılsın diye fail-safe.
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env yoksa sessizce geç — GeminiService devre dışı kalır,
    // built-in alışkanlıklar (cigarettes, alcohol, vb.) yine çalışır.
  }

  // 3) Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // 4) ServiceLocator — GeminiService gibi API key isteyen servisleri init eder.
  await ServiceLocator.instance.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
        Locale('es'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: const MyApp(),
    ),
  );
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

      // easy_localization delegate'leri
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // YENİ: Başlangıç ekranımızı tasarladığımız ekran yapıyoruz
      home: const AuthGate(),
    );
  }
}
