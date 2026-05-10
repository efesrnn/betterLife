// ============================================================
// HabitQuest - Debug Test Screen
// Tüm backend fonksiyonlarını test etmek için geçici ekran.
// Projeye lib/screens/debug_screen.dart olarak koy.
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/habit_repository.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _client = Supabase.instance.client;
  late final HabitRepository _repo;

  // Auth Sample
  final _emailCtrl = TextEditingController(text: 'test@test.com');
  final _passCtrl = TextEditingController(text: 'test1234');
  final _usernameCtrl = TextEditingController(text: 'testuser');

  // Habit search
  final _habitInputCtrl = TextEditingController();

  // Daily log
  final _reportedValueCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();

  // State
  String _log = '';
  bool _loading = false;
  bool _isLoggedIn = false;
  String? _selectedUserHabitId;
  List<UserHabit> _activeHabits = [];
  List<Habit> _catalog = [];

  @override
  void initState() {
    super.initState();
    _repo = HabitRepository();
    _isLoggedIn = _client.auth.currentUser != null;
    if (_isLoggedIn) _refreshHabits();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _usernameCtrl.dispose();
    _habitInputCtrl.dispose();
    _reportedValueCtrl.dispose();
    _caloriesCtrl.dispose();
    super.dispose();
  }

  void _appendLog(String msg) {
    setState(() {
      _log = '${DateTime.now().toString().substring(11, 19)} $msg\n$_log';
    });
  }

  Future<void> _run(String label, Future<void> Function() fn) async {
    setState(() => _loading = true);
    _appendLog('▶ $label...');
    try {
      await fn();
      _appendLog('✅ $label done');
    } catch (e) {
      _appendLog('❌ $label FAILED: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _refreshHabits() async {
    try {
      _activeHabits = await _repo.getActiveHabits();
      _catalog = await _repo.getHabitCatalog();
      setState(() {});
    } catch (e) {
      _appendLog('⚠ Refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Debug Panel'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _run('Refresh', _refreshHabits),
            ),
        ],
      ),
      body: Column(
        children: [
          // Loading bar
          if (_loading) const LinearProgressIndicator(color: Colors.amber),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ============================
                // AUTH SECTION
                // ============================
                _sectionHeader('1. Auth', Icons.person),
                if (!_isLoggedIn) ...[
                  _inputField(_emailCtrl, 'Email'),
                  const SizedBox(height: 8),
                  _inputField(_passCtrl, 'Password', obscure: true),
                  const SizedBox(height: 8),
                  _inputField(_usernameCtrl, 'Username (for signup)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton('Sign Up', Colors.green, () {
                          _run('Sign Up', () async {
                            await _client.auth.signUp(
                              email: _emailCtrl.text,
                              password: _passCtrl.text,
                              data: {'username': _usernameCtrl.text},
                            );
                            setState(() => _isLoggedIn = _client.auth.currentUser != null);
                            if (_isLoggedIn) {
                              _appendLog('User ID: ${_client.auth.currentUser!.id}');
                              await _refreshHabits();
                            }
                          });
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionButton('Login', Colors.blue, () {
                          _run('Login', () async {
                            await _client.auth.signInWithPassword(
                              email: _emailCtrl.text,
                              password: _passCtrl.text,
                            );
                            setState(() => _isLoggedIn = _client.auth.currentUser != null);
                            if (_isLoggedIn) {
                              _appendLog('User ID: ${_client.auth.currentUser!.id}');
                              await _refreshHabits();
                            }
                          });
                        }),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Logged in: ${_client.auth.currentUser?.email}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _run('Logout', () async {
                            await _client.auth.signOut();
                            setState(() {
                              _isLoggedIn = false;
                              _activeHabits = [];
                            });
                          }),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                if (_isLoggedIn) ...[
                  // ============================
                  // HABIT SEARCH / CREATE
                  // ============================
                  _sectionHeader('2. Habit Search / Create', Icons.search),
                  _inputField(_habitInputCtrl, 'Habit (any language: "sigara", "video games", "Laufen"...)'),
                  const SizedBox(height: 8),
                  _actionButton('🔍 Search or Create Habit', Colors.purple, () {
                    _run('Habit Search', () async {
                      final result = await _repo.searchOrCreateHabit(
                        userInput: _habitInputCtrl.text,
                        locale: 'tr',
                      );
                      _appendLog('Action: ${result.action}');
                      _appendLog('Message Key: ${result.messageKey}');
                      if (result.habitId != null) {
                        _appendLog('Habit ID: ${result.habitId}');
                      }
                      if (result.suggestions != null) {
                        for (final s in result.suggestions!) {
                          _appendLog('  Suggestion: ${s.titleTr} (${s.titleEn}) — ${(s.similarity * 100).toStringAsFixed(1)}%');
                        }
                      }
                      if (result.habit != null) {
                        final h = result.habit!;
                        _appendLog('  Gemini: ${h['habit_metadata']?['title_en']} | base: ${h['scoring_engine']?['base_daily_points']}');
                      }
                      _appendLog('Gemini called: ${result.geminiCalled}');
                    });
                  }),

                  const SizedBox(height: 24),

                  // ============================
                  // HABIT CATALOG
                  // ============================
                  _sectionHeader('3. Habit Catalog (${_catalog.length})', Icons.list_alt),
                  if (_catalog.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No habits in catalog. Run search first or check seed data.'),
                    )
                  else
                    ..._catalog.map((h) => _catalogTile(h)),

                  const SizedBox(height: 24),

                  // ============================
                  // ACTIVE HABITS
                  // ============================
                  _sectionHeader('4. Active Habits (${_activeHabits.length})', Icons.fitness_center),
                  if (_activeHabits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No active habits. Add one from the catalog above.'),
                    )
                  else
                    ..._activeHabits.map((uh) => _activeHabitTile(uh)),

                  const SizedBox(height: 24),

                  // ============================
                  // DAILY LOG
                  // ============================
                  _sectionHeader('5. Submit Daily Log', Icons.edit_note),
                  if (_activeHabits.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedUserHabitId,
                      decoration: _inputDecoration('Select habit'),
                      items: _activeHabits.map((uh) {
                        return DropdownMenuItem(
                          value: uh.id,
                          child: Text('${uh.habit?.icon ?? "🎯"} ${uh.title("tr")} (streak: ${uh.currentStreak})'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedUserHabitId = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _inputField(_reportedValueCtrl, 'Value (e.g. 5)', numeric: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _inputField(_caloriesCtrl, 'Calories (optional)', numeric: true)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _actionButton('📝 Submit Log', Colors.teal, () {
                      if (_selectedUserHabitId == null) {
                        _appendLog('⚠ Select a habit first');
                        return;
                      }
                      _run('Submit Log', () async {
                        final result = await _repo.submitDailyLog(
                          userHabitId: _selectedUserHabitId!,
                          reportedValue: double.tryParse(_reportedValueCtrl.text) ?? 0,
                          caloriesBurned: _caloriesCtrl.text.isNotEmpty
                              ? double.tryParse(_caloriesCtrl.text)
                              : null,
                        );
                        _appendLog('Total Points: ${result.totalPoints}');
                        _appendLog('Base: ${result.basePoints} | Streak: +${result.streakBonus} | Effort: +${result.effortBonus} | Penalty: -${result.penalty}');
                        _appendLog('Success: ${result.isSuccess} | New Streak: ${result.newStreak}');
                        if (result.comboStreak != null) {
                          final cs = result.comboStreak!;
                          _appendLog('Combo: awarded=${cs.comboAwarded}, active=${cs.activeStreakCount}, bonus=${cs.comboBonusPoints}');
                        }
                        await _refreshHabits();
                      });
                    }),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Add a habit first to submit logs.'),
                    ),

                  const SizedBox(height: 24),

                  // ============================
                  // DASHBOARD
                  // ============================
                  _sectionHeader('6. Dashboard', Icons.dashboard),
                  _actionButton('📊 Load Dashboard', Colors.indigo, () {
                    _run('Dashboard', () async {
                      final d = await _repo.getDashboard();
                      _appendLog('Username: ${d.username}');
                      _appendLog('Total Score: ${d.totalScore} | Weekly: ${d.weeklyScore}');
                      _appendLog('Active Habits: ${d.activeHabits.length}');
                      for (final h in d.activeHabits) {
                        _appendLog('  ${h.icon} ${h.habitTitleTr}: streak ${h.currentStreak}, score ${h.habitTotalScore}, logged today: ${h.loggedToday}');
                      }
                      _appendLog('Combo: ${d.comboStreak.activeStreakCount} active, bonus ${d.comboStreak.potentialBonus}, next in ${d.comboStreak.daysUntilNextBonus} days');
                    });
                  }),

                  const SizedBox(height: 24),

                  // ============================
                  // COMBO CHECK
                  // ============================
                  _sectionHeader('7. Combo Streak', Icons.local_fire_department),
                  _actionButton('🔥 Check Combo Bonus', Colors.orange, () {
                    _run('Combo Check', () async {
                      final result = await _repo.checkComboBonus();
                      _appendLog('Awarded: ${result.comboAwarded}');
                      _appendLog('Active Streaks: ${result.activeStreakCount}');
                      if (result.comboAwarded) {
                        _appendLog('Bonus: +${result.comboBonusPoints}');
                      } else {
                        _appendLog('Reason: ${result.reason}');
                        if (result.daysUntilNext != null) {
                          _appendLog('Next bonus in: ${result.daysUntilNext} days');
                        }
                      }
                    });
                  }),

                  const SizedBox(height: 24),

                  // ============================
                  // LEADERBOARD
                  // ============================
                  _sectionHeader('8. Leaderboard', Icons.leaderboard),
                  _actionButton('🏆 Load Leaderboard', Colors.amber[800]!, () {
                    _run('Leaderboard', () async {
                      final entries = await _repo.getFriendLeaderboard();
                      if (entries.isEmpty) {
                        _appendLog('No friends yet. Add friends to see leaderboard.');
                      }
                      for (final e in entries) {
                        _appendLog('#${e.rank} ${e.username}: ${e.totalScore} pts (${e.activeHabits} habits)');
                      }
                    });
                  }),

                  const SizedBox(height: 24),

                  // ============================
                  // DEDUP (12h batch — manual trigger)
                  // ============================
                  _sectionHeader('9. Manual Deduplication (12h batch)', Icons.merge_type),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'Normally runs every 12 hours automatically.\nThis button triggers it immediately for testing.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _actionButton('⚡ Run Deduplication NOW', Colors.red, () {
                    _run('Deduplication', () async {
                      final response = await _client.functions.invoke(
                        'deduplicate-habits',
                        body: {},
                      );
                      if (response.status == 200) {
                        final data = response.data as Map<String, dynamic>;
                        _appendLog('Status: ${data['status']}');
                        _appendLog('Unclassified: ${data['total_unclassified']}');
                        _appendLog('Canonicals: ${data['total_canonicals']}');
                        _appendLog('Merged: ${data['merged']} | Promoted: ${data['promoted']}');
                        if (data['details'] != null) {
                          for (final d in data['details']) {
                            _appendLog('  ${d['action']}: ${d['id']?.toString().substring(0, 8)}... → ${d['reason']}');
                          }
                        }
                      } else {
                        _appendLog('Error: ${response.data}');
                      }
                      await _refreshHabits();
                    });
                  }),

                  const SizedBox(height: 24),

                  // ============================
                  // SEED EMBEDDINGS
                  // ============================
                  _sectionHeader('10. Generate Seed Embeddings', Icons.data_array),
                  _actionButton('🌱 Generate Embeddings (one-time)', Colors.cyan, () {
                    _run('Seed Embeddings', () async {
                      final response = await _client.functions.invoke(
                        'generate-seed-embeddings',
                        body: {},
                      );
                      if (response.status == 200) {
                        final data = response.data as Map<String, dynamic>;
                        _appendLog('Processed: ${data['processed']}');
                        _appendLog('Skipped: ${data['skipped']}');
                        _appendLog('Total habits: ${data['total_habits']}');
                      } else {
                        _appendLog('Error: ${response.data}');
                      }
                    });
                  }),

                  const SizedBox(height: 24),

                  // ============================
                  // RAW SQL QUERIES
                  // ============================
                  _sectionHeader('11. Quick DB Checks', Icons.storage),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _smallButton('Habits count', () async {
                        final data = await _client.from('habits').select('id').eq('is_valid', true);
                        _appendLog('Total valid habits: ${(data as List).length}');
                      }),
                      _smallButton('Canonical count', () async {
                        final data = await _client.from('habits').select('id').eq('is_canonical', true).eq('is_classified', true);
                        _appendLog('Canonical habits: ${(data as List).length}');
                      }),
                      _smallButton('Unclassified', () async {
                        final data = await _client.from('habits').select('id, slug, title_en, source_locale').eq('is_classified', false);
                        _appendLog('Unclassified: ${(data as List).length}');
                        for (final h in data) {
                          _appendLog('  ${h['slug']} (${h['source_locale']}): ${h['title_en']}');
                        }
                      }),
                      _smallButton('Aliases', () async {
                        final data = await _client.from('habits').select('id, slug, title_en, canonical_id').eq('is_canonical', false);
                        _appendLog('Aliases: ${(data as List).length}');
                        for (final h in data) {
                          _appendLog('  ${h['slug']} → canonical: ${h['canonical_id']?.toString().substring(0, 8)}...');
                        }
                      }),
                      _smallButton('Embeddings', () async {
                        final data = await _client.from('habit_embeddings').select('id, locale, input_text');
                        _appendLog('Embeddings: ${(data as List).length}');
                        for (final e in data) {
                          final preview = (e['input_text'] as String).length > 40
                              ? '${(e['input_text'] as String).substring(0, 40)}...'
                              : e['input_text'];
                          _appendLog('  [${e['locale']}] $preview');
                        }
                      }),
                      _smallButton('Combo logs', () async {
                        final data = await _client.from('combo_streak_logs').select().order('combo_date', ascending: false).limit(5);
                        _appendLog('Recent combo logs: ${(data as List).length}');
                        for (final c in data) {
                          _appendLog('  ${c['combo_date']}: ${c['active_streak_count']} streaks → +${c['combo_bonus_points']} pts');
                        }
                      }),
                      _smallButton('Daily logs today', () async {
                        final today = DateTime.now().toIso8601String().substring(0, 10);
                        final data = await _client.from('daily_logs').select().eq('log_date', today);
                        _appendLog('Logs today: ${(data as List).length}');
                        for (final l in data) {
                          _appendLog('  habit: ${l['user_habit_id'].toString().substring(0, 8)}... val=${l['reported_value']} pts=${l['total_points']} success=${l['is_success']}');
                        }
                      }),
                      _smallButton('My profile', () async {
                        final userId = _client.auth.currentUser!.id;
                        final data = await _client.from('profiles').select().eq('id', userId).single();
                        _appendLog('Username: ${data['username']}');
                        _appendLog('Total: ${data['total_score']} | Weekly: ${data['weekly_score']} | Level: ${data['level']}');
                      }),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // ============================
                // LOG OUTPUT
                // ============================
                _sectionHeader('Console', Icons.terminal),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Clear'),
                      onPressed: () => setState(() => _log = ''),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                      onPressed: () {
                        // Clipboard would need import
                      },
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _log.isEmpty ? 'Waiting for actions...' : _log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: _log.isEmpty ? Colors.grey : Colors.green[300],
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================
  // HELPER: Catalog tile with "Add" button
  // ============================
  Widget _catalogTile(Habit h) {
    final alreadyAdded = _activeHabits.any((uh) => uh.habitId == h.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Text(h.icon ?? '🎯', style: const TextStyle(fontSize: 24)),
        title: Text('${h.titleTr}  (${h.titleEn})', style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          '${h.targetDirection} | base: ${h.baseDailyPoints} × ${h.difficultyWeight} | ${h.categoryTag}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: alreadyAdded
            ? const Icon(Icons.check, color: Colors.green, size: 20)
            : IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => _showAddHabitDialog(h),
        ),
      ),
    );
  }

  // ============================
  // HELPER: Active habit tile
  // ============================
  Widget _activeHabitTile(UserHabit uh) {
    final isSelected = _selectedUserHabitId == uh.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isSelected ? Colors.teal.withValues(alpha: 0.1) : null,
      child: ListTile(
        dense: true,
        leading: Text(uh.habit?.icon ?? '🎯', style: const TextStyle(fontSize: 24)),
        title: Text(uh.title('tr'), style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          'Streak: ${uh.currentStreak}d | Target: ${uh.currentDailyTarget} | Score: ${uh.habitTotalScore} | ${uh.programType.value}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Radio<String>(
          value: uh.id,
          groupValue: _selectedUserHabitId,
          onChanged: (v) => setState(() => _selectedUserHabitId = v),
        ),
        onTap: () => setState(() => _selectedUserHabitId = uh.id),
      ),
    );
  }

  // ============================
  // DIALOG: Add habit with program selection
  // ============================
  void _showAddHabitDialog(Habit h) {
    ProgramType selectedProgram = h.targetDirection == 'DECREASE'
        ? ProgramType.gradualDecrease
        : ProgramType.gradualIncrease;

    final startCtrl = TextEditingController(
      text: h.baseDailyPoints > 0 ? '${(h as dynamic).baseDailyPoints}' : '',
    );
    final targetCtrl = TextEditingController();
    final stepCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add: ${h.icon} ${h.titleTr}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ProgramType>(
                  value: selectedProgram,
                  decoration: _inputDecoration('Program Type'),
                  items: ProgramType.values.map((p) {
                    return DropdownMenuItem(value: p, child: Text(p.value));
                  }).toList(),
                  onChanged: (v) => setDialogState(() => selectedProgram = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: startCtrl,
                  decoration: _inputDecoration('Start Value (e.g. 20 cigarettes/day)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetCtrl,
                  decoration: _inputDecoration('Target Value (e.g. 0)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stepCtrl,
                  decoration: _inputDecoration('Step Amount per phase (optional)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _run('Add Habit', () async {
                  await _repo.addUserHabit(
                    habitId: h.id,
                    programType: selectedProgram,
                    startValue: double.tryParse(startCtrl.text),
                    targetValue: double.tryParse(targetCtrl.text),
                    phaseStepAmount: stepCtrl.text.isNotEmpty
                        ? double.tryParse(stepCtrl.text)
                        : null,
                  );
                  await _refreshHabits();
                  _appendLog('Added ${h.titleTr} with ${selectedProgram.value}');
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // UI COMPONENTS
  // ============================

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label,
      {bool obscure = false, bool numeric = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: _inputDecoration(label),
      style: const TextStyle(fontSize: 14),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _smallButton(String label, Future<void> Function() onPressed) {
    return OutlinedButton(
      onPressed: _loading ? null : () => _run(label, onPressed),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: const TextStyle(fontSize: 11),
      ),
      child: Text(label),
    );
  }
}