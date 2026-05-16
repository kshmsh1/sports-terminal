import 'package:flutter/material.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLAYER COMPARISON',
            style: TextStyle(color: Color(0xFF8AB4F8), fontSize: 12, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10),
          Text(
            'Comparison engine pending data connection',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 12),
          Text(
            'This module will compare players, teams, seasons, and game-level production once historical datasets are connected. Until then, it stays structurally ready without inventing values.',
            style: TextStyle(color: Color(0xFFB6C0CC), fontSize: 15, height: 1.45),
          ),
        ],
      ),
    );
  }
}
