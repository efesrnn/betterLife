import 'package:flutter/material.dart';

const Color _bg = Color(0xFF0F172A);
const Color _card = Color(0xFF1E293B);
const Color _border = Color(0xFF334155);
const Color _sub = Color(0xFF94A3B8);

class LungsScreen extends StatelessWidget {
  final double lungScore;

  const LungsScreen({super.key, required this.lungScore});

  @override
  Widget build(BuildContext context) {
    double displayScore = lungScore.clamp(0.0, 100.0);
    double normalizedScore = displayScore / 100.0;

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const Text(
              'LUNG HEALTH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 48),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: normalizedScore),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                final Color gaugeColor = Color.lerp(
                  const Color(0xFF64748B),
                  const Color(0xFFFF6B9D),
                  value,
                )!;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 18,
                        backgroundColor: _card,
                        valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
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
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'HEALTH',
                          style: TextStyle(
                            color: _sub,
                            fontSize: 11,
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
            const SizedBox(height: 48),
            _statusCard(normalizedScore),
            const SizedBox(height: 16),
            _infoCard(
              icon: Icons.timeline_rounded,
              iconColor: const Color(0xFF818CF8),
              title: 'Recovery Progress',
              body: normalizedScore < 0.3
                  ? 'Every smoke free hour matters. Your body has already begun repairing itself.'
                  : normalizedScore < 0.7
                  ? 'You\'re making real progress. Lung capacity is improving with each clean day.'
                  : 'Outstanding recovery. Your lungs are functioning close to non-smoker levels.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(double normalizedScore) {
    final IconData icon;
    final Color iconColor;
    final String title;
    final String body;

    if (normalizedScore < 0.3) {
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.redAccent;
      title = 'Critical';
      body = 'Cilia cells are paralyzed. High carbon monoxide levels. Lungs are suffocating.';
    } else if (normalizedScore < 0.7) {
      icon = Icons.trending_up_rounded;
      iconColor = Colors.orangeAccent;
      title = 'Recovering';
      body = 'Cilia regeneration has started. Mucus is clearing out. Oxygen levels rising.';
    } else {
      icon = Icons.check_circle_rounded;
      iconColor = const Color(0xFF34D399);
      title = 'Healthy';
      body = 'Lungs are heavily oxygenated. Tissue color returning to natural healthy pink.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: iconColor.withAlpha(60), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: iconColor, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: iconColor, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(color: _sub, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}