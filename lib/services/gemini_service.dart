// ============================================================
// Better Life — GeminiService
// ------------------------------------------------------------
// Serbest metin alışkanlık/aktivite girdilerini Gemini ile
// değerlendirip yapılandırılmış JSON sonucu döndürür.
//
// Akış (UI):
//   1) SupabaseService.findHabitCategoryByName(input)  ← cache
//   2) varsa direkt döndür (Gemini çağrılmaz, ücretsiz)
//   3) yoksa GeminiService.evaluateHabit(input)
//   4) result.isValid && result.suggestedCategory varsa
//      kullanıcıya onay göster → SupabaseService.createHabitCategory(...)
//
// API key dotenv'den okunur; yoksa servis isAvailable=false döner ve
// caller'a "yapay zeka şu an kullanılamıyor" hatası verir.
// ============================================================

import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/models.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  GenerativeModel? _model;
  String? _apiKey;

  /// ServiceLocator init sırasında çağrılır. API key boşsa servis devre dışı.
  void initialize({required String? apiKey}) {
    _apiKey = (apiKey ?? '').trim();
    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'your_gemini_api_key_here') {
      _model = null;
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey!,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        responseMimeType: 'application/json',
      ),
    );
  }

  bool get isAvailable => _model != null;

  // ========================================================
  // HABIT EVALUATION
  // ========================================================

  Future<GeminiHabitResult> evaluateHabit(String userInput) async {
    if (!isAvailable) {
      return GeminiHabitResult.unavailable();
    }

    final input = userInput.trim();
    if (input.length < 2) {
      return GeminiHabitResult.invalid(
        rejectionTr: 'Girdi çok kısa.',
        rejectionEn: 'Input is too short.',
      );
    }

    final prompt = _buildHabitPrompt(input);
    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '';
      final json = _safeJsonDecode(raw);
      if (json == null) {
        return GeminiHabitResult.invalid(
          rejectionTr: 'Yanıt anlaşılamadı.',
          rejectionEn: 'Could not parse response.',
        );
      }
      return GeminiHabitResult.fromJson(json, rawText: raw);
    } catch (e) {
      return GeminiHabitResult.invalid(
        rejectionTr: 'AI servisine ulaşılamadı: $e',
        rejectionEn: 'Could not reach AI service: $e',
      );
    }
  }

  // ========================================================
  // ACTIVITY EVALUATION
  // ========================================================

  Future<GeminiActivityResult> evaluateActivity(String userInput) async {
    if (!isAvailable) {
      return GeminiActivityResult.unavailable();
    }
    final input = userInput.trim();
    if (input.length < 2) {
      return GeminiActivityResult.invalid(
        rejectionTr: 'Girdi çok kısa.',
        rejectionEn: 'Input is too short.',
      );
    }

    final prompt = _buildActivityPrompt(input);
    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '';
      final json = _safeJsonDecode(raw);
      if (json == null) {
        return GeminiActivityResult.invalid(
          rejectionTr: 'Yanıt anlaşılamadı.',
          rejectionEn: 'Could not parse response.',
        );
      }
      return GeminiActivityResult.fromJson(json, rawText: raw);
    } catch (e) {
      return GeminiActivityResult.invalid(
        rejectionTr: 'AI servisine ulaşılamadı: $e',
        rejectionEn: 'Could not reach AI service: $e',
      );
    }
  }

  // ========================================================
  // PROMPTS
  // ========================================================

  String _buildHabitPrompt(String userInput) => '''
You are evaluating whether the user input describes a HARMFUL HABIT that someone wants to QUIT.

User input: "$userInput"

Return ONLY JSON with these exact fields:
{
  "is_valid": boolean,
  "rejection_reason_tr": string,  // Turkish, only if is_valid=false
  "rejection_reason_en": string,  // English, only if is_valid=false
  "name_tr": string,              // canonical Turkish name (if valid)
  "name_en": string,              // canonical English name (if valid)
  "description_tr": string,
  "description_en": string,
  "icon_name": string,            // Material Icons name (e.g. "smoking_rooms")
  "color_hex": string,            // 7-char hex like "#EF4444"
  "base_daily_points": int,       // 1..15 (avoidance points/day)
  "health_impact": int,           // 1..10
  "social_impact": int,           // 1..10
  "financial_impact": int,        // 1..10
  "addiction_level": int          // 1..10
}

REJECT (is_valid=false) if input is:
- a positive/healthy activity (running, reading, meditation, etc.)
- a neutral/meaningless thing
- a criminal act
- a joke/nonsense
- not clearly a habit one would want to quit

Accept things like: smoking, vaping, alcohol, junk food, screen addiction,
gambling, doomscrolling, oversleeping, nail biting, procrastination,
caffeine overuse, sugar overuse, porn addiction, etc.
''';

  String _buildActivityPrompt(String userInput) => '''
You are evaluating whether the user input describes a POSITIVE ACTIVITY worth rewarding (fitness, mental, learning, social, wellness).

User input: "$userInput"

Return ONLY JSON with these exact fields:
{
  "is_valid": boolean,
  "rejection_reason_tr": string,
  "rejection_reason_en": string,
  "name_tr": string,
  "name_en": string,
  "description_tr": string,
  "description_en": string,
  "icon_name": string,
  "color_hex": string,            // hex like "#22C55E"
  "base_bonus_points": int,       // 1..5
  "health_benefit": int,          // 1..10
  "mental_benefit": int,          // 1..10
  "is_duration_based": boolean,
  "points_per_minute": number,    // 0..0.2
  "min_duration_minutes": int     // 0..120
}

REJECT (is_valid=false) if input is:
- a harmful habit one should quit
- passive/neutral (watching TV, scrolling)
- a chore (cleaning, paying bills)
- meaningless/joke input
''';

  // ========================================================
  // HELPERS
  // ========================================================

  Map<String, dynamic>? _safeJsonDecode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // Bazen Gemini ```json ... ``` fence ile sarar
    var s = trimmed;
    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '').replaceAll(RegExp(r'\n?```$'), '');
    }
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}

/// Üst düzey alias — UI'da `geminiService.evaluateHabit(...)` şeklinde
/// kullanılır.
final geminiService = GeminiService.instance;

// ============================================================
// RESULT TYPES
// ============================================================

class GeminiHabitResult {
  final bool isValid;
  final bool isUnavailable;
  final String? rejectionTr;
  final String? rejectionEn;
  final HabitCategory? suggestedCategory;
  final Map<String, dynamic>? rawJson;

  GeminiHabitResult._({
    required this.isValid,
    this.isUnavailable = false,
    this.rejectionTr,
    this.rejectionEn,
    this.suggestedCategory,
    this.rawJson,
  });

  factory GeminiHabitResult.unavailable() => GeminiHabitResult._(
        isValid: false,
        isUnavailable: true,
      );

  factory GeminiHabitResult.invalid({
    required String rejectionTr,
    required String rejectionEn,
  }) =>
      GeminiHabitResult._(
        isValid: false,
        rejectionTr: rejectionTr,
        rejectionEn: rejectionEn,
      );

  factory GeminiHabitResult.fromJson(Map<String, dynamic> json, {String? rawText}) {
    final valid = json['is_valid'] == true;
    if (!valid) {
      return GeminiHabitResult._(
        isValid: false,
        rejectionTr: json['rejection_reason_tr'] as String?,
        rejectionEn: json['rejection_reason_en'] as String?,
        rawJson: json,
      );
    }

    final nameTr = (json['name_tr'] as String?)?.trim();
    final nameEn = (json['name_en'] as String?)?.trim();
    final descTr = json['description_tr'] as String?;

    // Numerik alanları güvenli parse et + min/max clamp
    int _clampInt(dynamic v, int min, int max) {
      final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? min;
      return n.clamp(min, max).toInt();
    }

    final category = HabitCategory(
      name: (nameTr?.isNotEmpty == true ? nameTr! : (nameEn ?? 'Unnamed')),
      description: descTr,
      iconName: (json['icon_name'] as String?)?.trim().isNotEmpty == true
          ? json['icon_name'] as String
          : 'block',
      colorHex: _normalizeHex(json['color_hex'] as String?),
      baseDailyPoints: _clampInt(json['base_daily_points'], 1, 15),
      healthImpact: _clampInt(json['health_impact'], 1, 10),
      socialImpact: _clampInt(json['social_impact'], 1, 10),
      financialImpact: _clampInt(json['financial_impact'], 1, 10),
      addictionLevel: _clampInt(json['addiction_level'], 1, 10),
      geminiEvaluation: json,
      isValid: true,
    );
    return GeminiHabitResult._(
      isValid: true,
      suggestedCategory: category,
      rawJson: json,
    );
  }
}

class GeminiActivityResult {
  final bool isValid;
  final bool isUnavailable;
  final String? rejectionTr;
  final String? rejectionEn;
  final ActivityCategory? suggestedCategory;
  final Map<String, dynamic>? rawJson;

  GeminiActivityResult._({
    required this.isValid,
    this.isUnavailable = false,
    this.rejectionTr,
    this.rejectionEn,
    this.suggestedCategory,
    this.rawJson,
  });

  factory GeminiActivityResult.unavailable() => GeminiActivityResult._(
        isValid: false,
        isUnavailable: true,
      );

  factory GeminiActivityResult.invalid({
    required String rejectionTr,
    required String rejectionEn,
  }) =>
      GeminiActivityResult._(
        isValid: false,
        rejectionTr: rejectionTr,
        rejectionEn: rejectionEn,
      );

  factory GeminiActivityResult.fromJson(Map<String, dynamic> json, {String? rawText}) {
    final valid = json['is_valid'] == true;
    if (!valid) {
      return GeminiActivityResult._(
        isValid: false,
        rejectionTr: json['rejection_reason_tr'] as String?,
        rejectionEn: json['rejection_reason_en'] as String?,
        rawJson: json,
      );
    }

    int _clampInt(dynamic v, int min, int max) {
      final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? min;
      return n.clamp(min, max).toInt();
    }

    double _clampDouble(dynamic v, double min, double max) {
      final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? min;
      return n.clamp(min, max).toDouble();
    }

    final nameTr = (json['name_tr'] as String?)?.trim();
    final nameEn = (json['name_en'] as String?)?.trim();

    final category = ActivityCategory(
      name: (nameTr?.isNotEmpty == true ? nameTr! : (nameEn ?? 'Unnamed')),
      description: json['description_tr'] as String?,
      iconName: (json['icon_name'] as String?)?.trim().isNotEmpty == true
          ? json['icon_name'] as String
          : 'fitness_center',
      colorHex: _normalizeHex(json['color_hex'] as String?, fallback: '#22C55E'),
      baseBonusPoints: _clampInt(json['base_bonus_points'], 1, 5),
      healthBenefit: _clampInt(json['health_benefit'], 1, 10),
      mentalBenefit: _clampInt(json['mental_benefit'], 1, 10),
      isDurationBased: json['is_duration_based'] == true,
      pointsPerMinute: _clampDouble(json['points_per_minute'], 0, 0.2),
      minDurationMinutes: _clampInt(json['min_duration_minutes'], 0, 120),
      geminiEvaluation: json,
      isValid: true,
    );
    return GeminiActivityResult._(
      isValid: true,
      suggestedCategory: category,
      rawJson: json,
    );
  }
}

String _normalizeHex(String? raw, {String fallback = '#EF4444'}) {
  if (raw == null) return fallback;
  var s = raw.trim();
  if (s.isEmpty) return fallback;
  if (!s.startsWith('#')) s = '#$s';
  // 7 karakter (#RRGGBB) bekleniyor; aksi durumda fallback
  if (s.length != 7) return fallback;
  return s.toUpperCase();
}
