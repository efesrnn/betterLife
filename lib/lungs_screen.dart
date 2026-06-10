import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_strings.dart';

class _Milestone {
  final double requiredScore;
  final String title;
  final String timeLabel;
  const _Milestone(this.requiredScore, this.title, this.timeLabel);
}

const _milestones = [
  _Milestone(11.5, 'Blood pressure normalizing',  '20 min'),
  _Milestone(13.0, 'Carbon monoxide clearing',     '8 hours'),
  _Milestone(15.0, 'Nerve endings recovering',     '48 hours'),
  _Milestone(20.0, 'Circulation improving',        '2 weeks'),
  _Milestone(30.0, 'Lung function improving',      '1 month'),
  _Milestone(45.0, 'Lung capacity growing',        '3 months'),
  _Milestone(60.0, 'Cilia regenerating',           '9 months'),
  _Milestone(80.0, 'Heart disease risk halved',    '1 year'),
  _Milestone(95.0, 'Lung cancer risk reducing',    '5 years'),
];

// -----------------------------------------------------------------------------

class LungsScreen extends StatefulWidget {
  final double lungScore;
  const LungsScreen({super.key, required this.lungScore});

  @override
  State<LungsScreen> createState() => _LungsScreenState();
}

class _LungsScreenState extends State<LungsScreen> {
  bool _showMilestones = false;

  @override
  Widget build(BuildContext context) {
    final score = widget.lungScore.clamp(0.0, 100.0);
    final completed =
        _milestones.where((m) => score >= m.requiredScore).length;

    return Container(
      color: context.appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baslik satiri
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _showMilestones
                      ? AppStrings.recoveryMilestones
                      : AppStrings.lungHealth,
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                // Kucuk halkaya dokununca gorunum degisir
                GestureDetector(
                  onTap: () =>
                      setState(() => _showMilestones = !_showMilestones),
                  child: _SmallProgressRing(score: score),
                ),
              ],
            ),
          ),

          // Icerik
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showMilestones
                  ? _MilestoneListView(
                      key: const ValueKey('milestones'),
                      score: score,
                      completed: completed,
                    )
                  : _MainLungsView(
                      key: const ValueKey('main'),
                      score: score,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Sag ustteki tiklanabilir kucuk ilerleme halkasi

class _SmallProgressRing extends StatelessWidget {
  final double score;
  const _SmallProgressRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final normalized = score / 100.0;
    final color =
        Color.lerp(Colors.redAccent, context.appAccent, normalized)!;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.appCard,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: normalized,
              strokeWidth: 4.5,
              backgroundColor: context.appBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
            Text(
              '${score.toInt()}%',
              style: TextStyle(
                color: context.appText,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ana gorunum: buyuk gosterge ve iki bilgi karti

class _MainLungsView extends StatelessWidget {
  final double score;
  const _MainLungsView({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final normalized = score / 100.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Buyuk dairesel gosterge
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: normalized),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (ctx, value, child) {
                final gaugeColor =
                    Color.lerp(Colors.redAccent, context.appAccent, value)!;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 14,
                        backgroundColor: context.appBorder,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(gaugeColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(value * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: gaugeColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.health,
                          style: TextStyle(
                            color: context.appSub,
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Durum karti
          _statusCard(context, normalized),
          const SizedBox(height: 12),

          // Iyilesme sureci karti
          _infoCard(
            context,
            icon: Icons.timeline_rounded,
            title: AppStrings.recoveryProgress,
            body: normalized < 0.3
                ? 'Every smoke free hour matters. Your body has already begun repairing itself.'
                : normalized < 0.7
                    ? 'You\'re making real progress. Lung capacity is improving with each clean day.'
                    : 'Outstanding recovery. Your lungs are functioning close to non-smoker levels.',
          ),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context, double normalized) {
    final IconData icon;
    final Color iconColor;
    final String title;
    final String body;

    if (normalized < 0.3) {
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.redAccent;
      title = 'Critical';
      body =
          'Cilia cells are paralyzed. High carbon monoxide levels. Lungs are suffocating.';
    } else if (normalized < 0.7) {
      icon = Icons.trending_up_rounded;
      iconColor = Colors.orangeAccent;
      title = 'Recovering';
      body =
          'Cilia regeneration has started. Mucus is clearing out. Oxygen levels rising.';
    } else {
      icon = Icons.check_circle_rounded;
      iconColor = context.appAccent;
      title = 'Healthy';
      body =
          'Lungs are heavily oxygenated. Tissue color returning to natural healthy pink.';
    }

    return _infoCard(context,
        icon: icon, iconColor: iconColor, title: title, body: body);
  }

  Widget _infoCard(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required String body,
  }) {
    final color = iconColor ?? context.appAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Kilometre tasi listesi

class _MilestoneListView extends StatelessWidget {
  final double score;
  final int completed;
  const _MilestoneListView(
      {super.key, required this.score, required this.completed});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: _milestones.length,
      itemBuilder: (context, index) {
        final m = _milestones[index];
        final progress = (score / m.requiredScore).clamp(0.0, 1.0);
        final pct = (progress * 100).round();
        final color =
            Color.lerp(Colors.redAccent, context.appAccent, progress)!;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              // Kucuk dairesel ilerleme
              SizedBox(
                width: 58,
                height: 58,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  builder: (ctx, value, child) {
                    final c = Color.lerp(
                        Colors.redAccent, context.appAccent, value)!;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 5,
                          backgroundColor: context.appBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(c),
                          strokeCap: StrokeCap.round,
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            color: context.appText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(m.timeLabel,
                        style: TextStyle(
                            color: context.appSub,
                            fontSize: 13)),
                  ],
                ),
              ),
              if (progress >= 1.0)
                Icon(Icons.check_circle_rounded, color: color, size: 22),
            ],
          ),
        );
      },
    );
  }
}