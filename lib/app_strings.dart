// ============================================================
// app_strings.dart
//
// Tüm kullanıcıya gösterilen UI metinleri buradan gelir.
// Her üye, easy_localization çeviri anahtarını .tr() ile çevirir.
// Çeviriler: assets/translations/tr.json ve en.json
//
// Kullanım:  Text(AppStrings.login)
// Parametreli:  AppStrings.requestSentTo('alp')
//
// NOT: Üyeler artık 'const' değil 'get' (runtime), çünkü çeviri
// çalışma zamanında seçili dile göre yapılır. Bu yüzden bu metinleri
// 'const' widget'lar içinde KULLANMAYIN.
// ============================================================

import 'package:easy_localization/easy_localization.dart';

class AppStrings {
  AppStrings._();

  // ── Genel ───────────────────────────────────────────────
  static String get appName => 'general.app_name'.tr();
  static String get save => 'general.save'.tr();
  static String get cancel => 'general.cancel'.tr();
  static String get remove => 'general.remove'.tr();

  // ── Auth ────────────────────────────────────────────────
  static String get welcomeBack => 'auth.welcome_back'.tr();
  static String get startJourney => 'auth.start_journey'.tr();
  static String get login => 'auth.login'.tr();
  static String get signUp => 'auth.sign_up'.tr();
  static String get email => 'auth.email'.tr();
  static String get password => 'auth.password'.tr();
  static String get noAccount => 'auth.no_account'.tr();
  static String get haveAccount => 'auth.have_account'.tr();
  static String get enterEmailPassword => 'auth.enter_email_password'.tr();
  static String get tooManyAttempts => 'auth.too_many_attempts'.tr();
  static String get unexpectedError => 'auth.unexpected_error'.tr();

  // ── Email verification ──────────────────────────────────
  static String get verifyEmailTitle => 'verify.title'.tr();
  static String get verifyEmailSubtitle => 'verify.subtitle'.tr();
  static String get verifyEmailHint => 'verify.hint'.tr();
  static String get resendEmail => 'verify.resend'.tr();
  static String resendIn(int s) =>
      'verify.resend_in'.tr(namedArgs: {'s': '$s'});
  static String verificationResentTo(String email) =>
      'verify.resent_to'.tr(namedArgs: {'email': email});
  static String failedToResend(Object e) =>
      'verify.failed_to_resend'.tr(namedArgs: {'error': '$e'});
  static String get wrongEmailGoBack => 'verify.wrong_email'.tr();

  // ── Onboarding: habit selection ─────────────────────────
  static String get chooseHabit => 'habit_select.choose'.tr();
  static String get otherHabitHint => 'habit_select.other_hint'.tr();

  // ── Onboarding: goal selection ──────────────────────────
  static String get whatsYourGoal => 'goal_select.title'.tr();
  static String get goalQuitOnce => 'goal_select.quit_once'.tr();
  static String get goalQuitStepByStep => 'goal_select.quit_step'.tr();
  static String get goalReduceBy => 'goal_select.reduce_by'.tr();
  static String get goalReduceStepByStep => 'goal_select.reduce_step'.tr();
  static String get percentageHint => 'goal_select.percentage'.tr();

  // ── Onboarding: username ────────────────────────────────
  static String get whatShouldWeCallYou => 'username.title'.tr();
  static String get enterUsername => 'username.enter'.tr();
  static String get usernameMinChars => 'username.min_chars'.tr();

  // ── Home ────────────────────────────────────────────────
  static String habitTodaySuffix(String habit) =>
      'home.habit_today'.tr(namedArgs: {'habit': habit});
  static String get cigarettesToday => 'home.cigarettes_today'.tr();
  static String get totalSaved => 'home.total_saved'.tr();
  static String dailyTarget(String amount) =>
      'home.daily_target'.tr(namedArgs: {'amount': amount});
  static String smokedOfBaseline(int count, int baseline) =>
      'home.smoked_of'.tr(namedArgs: {'count': '$count', 'baseline': '$baseline'});
  static String remainingCount(int n) =>
      'home.remaining'.tr(namedArgs: {'n': '$n'});
  static String get exceeded => 'home.exceeded'.tr();
  static String daysStreak(int n) =>
      'drawer.days_streak'.tr(namedArgs: {'n': '$n'});

  // ── Home (yeni tasarım) ─────────────────────────────────
  static String get cleanTime => 'home.clean_time'.tr();
  static String get savedShort => 'home.saved_short'.tr();
  static String get lungsShort => 'home.lungs_short'.tr();
  static String get ifContinued => 'home.if_continued'.tr();
  static String get nextLabel => 'home.next_label'.tr();
  static String get streakLabel => 'home.streak_label'.tr();
  static String get lifeContribution => 'home.life_contribution'.tr();
  static String get keepGoing => 'home.keep_going'.tr();
  static String get daysClean => 'home.days_clean'.tr();
  static String get relapseBtn => 'home.relapse_btn'.tr();
  static String get todayTarget => 'home.today_target'.tr();
  static String get logTodayLabel => 'home.log_today'.tr();
  static String get loggedTodayMsg => 'home.logged_today'.tr();
  static String get calendarTitle => 'home.calendar_title'.tr();

  // ── Check-in dialog ─────────────────────────────────────
  static String get dailyCheckIn => 'checkin.title'.tr();
  static String slipUpQuestion(String habit) =>
      'checkin.slip_up'.tr(namedArgs: {'habit': habit});
  static String get smokedQuestion => 'checkin.smoked'.tr();
  static String get stayedStrong => 'checkin.stayed_strong'.tr();

  // ── Settings / cigarette info ───────────────────────────
  static String get cigaretteInfo => 'cigarette.info'.tr();
  static String get priceCheck => 'cigarette.price_check'.tr();
  static String get priceCheckBody => 'cigarette.price_check_body'.tr();
  static String get packPrice => 'cigarette.pack_price'.tr();
  static String get cigsPerPack => 'cigarette.cigs_per_pack'.tr();
  static String get dailyCigs => 'cigarette.daily_cigs'.tr();
  static String get saveSettings => 'cigarette.save_settings'.tr();

  static String get settings => 'settings.title'.tr();
  static String get appearance => 'settings.appearance'.tr();
  static String get accountInfo => 'settings.account_info'.tr();
  static String get emailAddress => 'settings.email_address'.tr();
  static String get changeUsername => 'settings.change_username'.tr();
  static String get newUsername => 'settings.new_username'.tr();
  static String get saveUsername => 'settings.save_username'.tr();
  static String get changePassword => 'settings.change_password'.tr();
  static String get newPassword => 'settings.new_password'.tr();
  static String get saveNewPassword => 'settings.save_new_password'.tr();
  static String get theme => 'settings.theme'.tr();
  static String get darkMode => 'settings.dark_mode'.tr();
  static String get lightMode => 'settings.light_mode'.tr();
  static String get usernameMin3 => 'settings.username_min3'.tr();
  static String get usernameTaken => 'settings.username_taken'.tr();
  static String get usernameUpdated => 'settings.username_updated'.tr();
  static String get passwordMin6 => 'settings.password_min6'.tr();
  static String get passwordUpdated => 'settings.password_updated'.tr();
  static String errorWith(Object e) =>
      'settings.error'.tr(namedArgs: {'error': '$e'});

  // ── Language (dil seçici) ───────────────────────────────
  static String get language => 'settings.language'.tr();
  static String get languageLabel => 'settings.language_label'.tr();
  static String get turkish => 'settings.turkish'.tr();
  static String get english => 'settings.english'.tr();

  // ── Navigation ──────────────────────────────────────────
  static String get home => 'nav.home'.tr();

  // ── Drawer ──────────────────────────────────────────────
  static String get defaultUser => 'drawer.default_user'.tr();
  static String get logout => 'drawer.logout'.tr();
  static String get uploadingPhoto => 'drawer.uploading_photo'.tr();
  static String get photoUpdated => 'drawer.photo_updated'.tr();
  static String errorUploading(Object e) =>
      'drawer.error_uploading'.tr(namedArgs: {'error': '$e'});

  // ── Lungs ───────────────────────────────────────────────
  static String get lungs => 'lungs.tab'.tr();
  static String get lungHealth => 'lungs.lung_health'.tr();
  static String get recoveryMilestones => 'lungs.recovery_milestones'.tr();
  static String get health => 'lungs.health'.tr();
  static String get recoveryProgress => 'lungs.recovery_progress'.tr();

  // ── Friends / Leaderboard ───────────────────────────────
  static String get friends => 'friends.tab'.tr();
  static String get leaderboard => 'friends.leaderboard'.tr();
  static String get findFriend => 'friends.find_friend'.tr();
  static String get noFriendsYet => 'friends.no_friends_yet'.tr();
  static String get addSomeoneToStart => 'friends.add_someone'.tr();
  static String get removeFriend => 'friends.remove_friend'.tr();
  static String removeFriendConfirm(String username) =>
      'friends.remove_confirm'.tr(namedArgs: {'username': username});
  static String quittingHabit(String habit) =>
      'friends.quitting'.tr(namedArgs: {'habit': habit});
  static String get quittingDefault => 'friends.quitting_default'.tr();
  static String savedAmount(String amount) =>
      'friends.saved'.tr(namedArgs: {'amount': amount});
  static String get you => 'friends.you'.tr();
  static String dayStreakShort(int n) =>
      'friends.day_streak'.tr(namedArgs: {'n': '$n'});

  static String get friendRequests => 'friends.requests'.tr();
  static String get noPendingRequests => 'friends.no_pending'.tr();
  static String get discoverPeople => 'friends.discover'.tr();
  static String get noOtherUsers => 'friends.no_other_users'.tr();
  static String requestSentTo(String username) =>
      'friends.request_sent_to'.tr(namedArgs: {'username': username});
  static String friendAcceptedRequest(String name) =>
      'friends.accepted_request'.tr(namedArgs: {'name': name});
  static String get someone => 'friends.someone'.tr();
  static String get unknown => 'friends.unknown'.tr();

  // ── Enum çevirileri (program / kategori / risk) ─────────
  // Gemini bazen listede olmayan değerler döndürür (örn. ADDICTION_RECOVERY).
  // Çeviri bulunamazsa ham anahtar yerine okunabilir metne düşeriz.
  static String _humanize(String v) => v
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
  static String _trOr(String key, String raw) {
    final t = key.tr();
    return t == key ? _humanize(raw) : t;
  }

  static String programType(String value) => _trOr('program_types.$value', value);
  static String category(String tag) => _trOr('categories.$tag', tag);
  static String riskLevel(String level) => _trOr('risk_levels.$level', level);

  // ── Habits ekranı ───────────────────────────────────────
  static String get habitsTab => 'habits.tab'.tr();
  static String get myHabits => 'habits.my_habits'.tr();
  static String get addHabit => 'habits.add'.tr();
  static String get browseCatalog => 'habits.catalog'.tr();
  static String get habitsEmptyTitle => 'habits.empty_title'.tr();
  static String get habitsEmptySub => 'habits.empty_sub'.tr();
  static String get habitNameHint => 'habits.name_hint'.tr();
  static String get evaluate => 'habits.evaluate'.tr();
  static String get evaluating => 'habits.evaluating'.tr();
  static String get habitInvalid => 'habits.invalid'.tr();
  static String get habitExactFound => 'habits.exact_found'.tr();
  static String get habitNewCreated => 'habits.new_created'.tr();
  static String get habitMaybeFound => 'habits.maybe_found'.tr();
  static String get chooseProgram => 'habits.choose_program'.tr();
  static String get addToMyHabits => 'habits.add_button'.tr();
  static String get habitAdded => 'habits.added'.tr();
  static String habitDayStreak(int n) =>
      'habits.day_streak'.tr(namedArgs: {'n': '$n'});
  static String get catalogTitle => 'habits.catalog_title'.tr();
  static String get noCatalog => 'habits.no_catalog'.tr();
  static String get lungHealthMenu => 'habits.lung_health'.tr();
  static String get removeHabit => 'habits.remove'.tr();
  static String removeHabitConfirm(String habit) =>
      'habits.remove_confirm'.tr(namedArgs: {'habit': habit});
  static String get paused => 'habits.paused'.tr();
  static String get matchLabel => 'habits.similarity'.tr();

  // ── Habit ekleme: plan/giriş alanları ───────────────────
  static String get planTitle => 'add.details_title'.tr();
  static String get startAmount => 'add.start_amount'.tr();
  static String get targetAmount => 'add.target_amount'.tr();
  static String get unitCostLabel => 'add.unit_cost'.tr();
  static String get durationLabel => 'add.duration'.tr();
  static String get weeksLabel => 'add.weeks'.tr();
  static String get monthsLabel => 'add.months'.tr();
  static String schedulePreview(String from, String to, String unit, int n) =>
      'add.schedule_preview'.tr(namedArgs: {
        'from': from,
        'to': to,
        'unit': unit,
        'n': '$n',
      });
  static String get pickFromCatalog => 'add.pick_from_catalog'.tr();
  static String get orCreateAi => 'add.or_create_ai'.tr();
  static String get searchHint => 'add.search_hint'.tr();
  static String get createAnyway => 'add.create_anyway'.tr();
  static String get noCatalogMatch => 'add.no_catalog_match'.tr();
  static String get aiSuggestTitle => 'add.ai_suggest_title'.tr();
  static String evaluateInput(String q) =>
      'add.evaluate_input'.tr(namedArgs: {'q': q});
  static String programDesc(String value) =>
      _trOr('program_desc.$value', value);

  // ── Habit detay ─────────────────────────────────────────
  static String get detailTitle => 'detail.title'.tr();
  static String get detailImpact => 'detail.impact'.tr();
  static String get detailHealth => 'detail.health'.tr();
  static String get detailMental => 'detail.mental'.tr();
  static String get detailFinancial => 'detail.financial'.tr();
  static String get detailTime => 'detail.time'.tr();
  static String get detailSocial => 'detail.social'.tr();
  static String get detailScoring => 'detail.scoring'.tr();
  static String get detailBasePoints => 'detail.base_points'.tr();
  static String get detailDifficulty => 'detail.difficulty'.tr();
  static String get detailStreak => 'detail.streak'.tr();
  static String get detailLongest => 'detail.longest'.tr();
  static String get detailRisk => 'detail.risk'.tr();
  static String get detailCategory => 'detail.category'.tr();
  static String get detailProgram => 'detail.program'.tr();
  static String get detailTarget => 'detail.target'.tr();
  static String get detailStarted => 'detail.started'.tr();
  static String get detailDescription => 'detail.description'.tr();
  static String get detailAiNotes => 'detail.ai_notes'.tr();
  static String get detailEditPlan => 'detail.edit_plan'.tr();
  static String get detailUpdated => 'detail.updated'.tr();

  // ── Check-in hatırlatma ─────────────────────────────────
  static String checkinReminderBody(int n) =>
      'checkin.reminder_body'.tr(namedArgs: {'n': '$n'});
  static String get checkinGoLog => 'checkin.go_log'.tr();

  // ── Admin ───────────────────────────────────────────────
  static String get adminTitle => 'admin.title'.tr();
  static String get adminMergeNow => 'admin.merge_now'.tr();
  static String get adminMergeDesc => 'admin.merge_desc'.tr();
  static String get adminMergeRunning => 'admin.merge_running'.tr();
  static String adminMergeDone(int merged, int promoted) =>
      'admin.merge_done'.tr(
          namedArgs: {'merged': '$merged', 'promoted': '$promoted'});
  static String adminMergeFailed(Object e) =>
      'admin.merge_failed'.tr(namedArgs: {'error': e.toString()});

  // ── Profil / aktivite akışı ─────────────────────────────
  static String get profileHabits => 'profile.habits'.tr();
  static String get profileActivity => 'profile.activity'.tr();
  static String get profileNoActivity => 'profile.no_activity'.tr();
  static String get profileNoHabits => 'profile.no_habits'.tr();
  static String activityStarted(String habit) =>
      'activity.started'.tr(namedArgs: {'habit': habit});
  static String activityLogged(String habit, String value, String unit) =>
      'activity.logged'
          .tr(namedArgs: {'habit': habit, 'value': value, 'unit': unit});
  static String activityLoggedClean(String habit) =>
      'activity.logged_clean'.tr(namedArgs: {'habit': habit});
  static String activityMilestone(String habit, int n) =>
      'activity.milestone'.tr(namedArgs: {'habit': habit, 'n': '$n'});

  // ── Skor ────────────────────────────────────────────────
  static String get scorePts => 'score.points'.tr();
  static String get scoreThisMonth => 'score.this_month'.tr();
  static String get scoreTotal => 'score.total'.tr();

  // ── Puan kırılımı (şeffaflık) ───────────────────────────
  static String get bdTitle => 'breakdown.title'.tr();
  static String get bdFormula => 'breakdown.formula'.tr();
  static String get bdBase => 'breakdown.base'.tr();
  static String get bdDifficulty => 'breakdown.difficulty'.tr();
  static String get bdStreakMult => 'breakdown.streak_mult'.tr();
  static String get bdDays => 'breakdown.days'.tr();
  static String get bdStreakBonus => 'breakdown.streak_bonus'.tr();
  static String get bdMilestoneBonus => 'breakdown.milestone_bonus'.tr();
  static String get bdPenalty => 'breakdown.penalty'.tr();
  static String get bdTotal => 'breakdown.total'.tr();
}
