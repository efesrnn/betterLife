import 'package:flutter/material.dart';

class LungsScreen extends StatelessWidget {
  final double lungScore;

  const LungsScreen({super.key, required this.lungScore});

  @override
  Widget build(BuildContext context) {
    double displayScore = lungScore;
    if (displayScore < 0) displayScore = 0.0;
    if (displayScore > 100) displayScore = 100.0;

    double normalizedScore = displayScore / 100.0;
    Color lungColor = Color.lerp(Colors.grey.shade800, const Color(0xFFFFB6C1), normalizedScore)!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'LUNG HEALTH',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            const SizedBox(height: 40),
            Icon(
              Icons.monitor_heart,
              size: 200,
              color: lungColor,
            ),
            const SizedBox(height: 40),
            Text(
              '%${displayScore.toStringAsFixed(1)}',
              style: TextStyle(fontSize: 55, fontWeight: FontWeight.w900, color: lungColor),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Text(
                normalizedScore < 0.3
                    ? 'Cilia cells are paralyzed. High carbon monoxide levels. Lungs are suffocating.'
                    : normalizedScore < 0.7
                    ? 'Cilia regeneration has started. Mucus is clearing out. Oxygen levels rising.'
                    : 'Lungs are heavily oxygenated. Tissue color returning to natural healthy pink.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}