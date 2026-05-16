import 'package:flutter/material.dart';

const terminalBackground = Color(0xFF0B0F14);
const terminalPanel = Color(0xFF111820);
const terminalPanelDark = Color(0xFF0D1218);
const terminalBorder = Color(0xFF263241);
const terminalAccent = Color(0xFF8AB4F8);
const terminalTextMuted = Color(0xFF8794A5);
const terminalTextSoft = Color(0xFFB6C0CC);

class TerminalCard extends StatelessWidget {
  const TerminalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: terminalPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: terminalBorder),
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF9AA7B6), fontSize: 15, height: 1.4),
        ),
      ],
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.label,
    this.color = terminalAccent,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF152235),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF385A86)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String displayNullable(num? value, {int decimals = 1}) {
  if (value == null) return '—';
  if (value is int) return value.toString();
  return value.toStringAsFixed(decimals);
}
