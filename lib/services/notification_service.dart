// Push bildirim servisi (Firebase Cloud Messaging).
// Uygulama acilisinda init() bir kez cagrilir. Servis;
// - bildirim iznini ister,
// - cihazin FCM token'ini alir ve Supabase'deki device_tokens tablosuna yazar,
// - on planda gelen mesajlari yerel bildirim olarak gosterir,
// - token yenilenirse kaydi gunceller.
// Sunucudan bildirim gondermek icin docs/NOTIFICATION_SETUP.md dosyasina bak.

import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Uygulama arka plandayken veya kapaliyken gelen mesajlar icin calisir.
// "notification" alani olan mesajlari sistem zaten tepside gosterdigi icin
// burada ekstra bir sey yapmiyoruz. Veri islemek gerekirse buraya eklenir.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka plan handler'i kendi isolate'inde calisir, Firebase'i tekrar baslatmak gerekir.
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Manifest'teki default_notification_channel_id ile ayni olmali.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'better_life_general',
    'Genel Bildirimler',
    description: 'Hatirlatmalar ve genel duyurular',
    importance: Importance.high,
  );

  /// main() icinde Supabase kurulduktan sonra cagrilir.
  Future<void> init() async {
    if (_initialized) return;
    try {
      // Android'de yapilandirma google-services.json dosyasindan okunur.
      await Firebase.initializeApp();
    } catch (e) {
      // Firebase kurulamazsa uygulama bildirimsiz calismaya devam eder.
      debugPrint('Firebase baslatilamadi: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Bildirim izni (Android 13+ ve iOS bunu zorunlu tutar).
    await FirebaseMessaging.instance.requestPermission();

    // Yerel bildirim eklentisi: on planda gelen mesajlari gostermek icin.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(settings: initSettings);
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Uygulama acikken gelen mesajlar tepsiye dusmez, kendimiz gosteriyoruz.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Token degisirse sunucudaki kaydi tazele.
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _saveToken(token);
    });

    // Kullanici giris yaptiginda token'i kaydet.
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.initialSession) {
        syncToken();
      }
    });

    _initialized = true;

    // Acilista oturum zaten aciksa token'i hemen kaydet.
    await syncToken();
  }

  /// Cihazin guncel FCM token'ini alip veritabanina yazar.
  Future<void> syncToken() async {
    if (!_initialized) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('FCM token alinamadi: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      debugPrint('FCM token kaydedilemedi: $e');
    }
  }

  /// Cikis yapmadan once cagrilir; bu cihaza artik bildirim gitmesin.
  Future<void> removeToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Supabase.instance.client
            .from('device_tokens')
            .delete()
            .eq('token', token);
      }
    } catch (e) {
      debugPrint('FCM token silinemedi: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
