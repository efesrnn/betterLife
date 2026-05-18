// ============================================================
// Better Life — ServiceLocator
// ------------------------------------------------------------
// Tüm singleton servisleri tek noktadan başlatır. main.dart'tan
// uygulama startup'ında bir kez çağrılır.
//
//   await ServiceLocator.instance.init();
//
// SupabaseService zaten static instance üzerinden erişiliyor;
// GeminiService API key gerektirdiği için burada inject edilir.
// ============================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'gemini_service.dart';

class ServiceLocator {
  ServiceLocator._();
  static final ServiceLocator instance = ServiceLocator._();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// dotenv zaten main.dart'ta yüklendi varsayılır.
  /// `apiKeyOverride` test/CI için kullanılabilir.
  Future<void> init({String? apiKeyOverride}) async {
    if (_initialized) return;

    // dotenv.env okumaya çalışırken paket init edilmediyse hata atar;
    // try ile sarmalayıp güvenli okuruz.
    String? key = apiKeyOverride;
    if (key == null) {
      try {
        key = dotenv.env['GEMINI_API_KEY'];
      } catch (_) {
        key = null;
      }
    }

    GeminiService.instance.initialize(apiKey: key);

    _initialized = true;
  }
}
