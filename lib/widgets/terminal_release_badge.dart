import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';

enum TerminalReleaseState { certified, live, stale, partial, unavailable, development }

class TerminalReleaseBadge extends StatelessWidget {
  const TerminalReleaseBadge({
    super.key,
    required this.releaseId,
    required this.state,
    this.sourceClass = '',
    this.observedAtIso = '',
    this.coverage = '',
    this.onOpenAudit,
  });

  final String releaseId;
  final TerminalReleaseState state;
  final String sourceClass;
  final String observedAtIso;
  final String coverage;
  final VoidCallback? onOpenAudit;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    final (label, color) = switch (state) {
      TerminalReleaseState.certified => ('CERTIFIED', tokens.positive),
      TerminalReleaseState.live => ('LIVE', tokens.positive),
      TerminalReleaseState.stale => ('STALE', tokens.warning),
      TerminalReleaseState.partial => ('PARTIAL', tokens.warning),
      TerminalReleaseState.unavailable => ('UNAVAILABLE', tokens.negative),
      TerminalReleaseState.development => ('DEVELOPMENT', tokens.muted),
    };
    final lines = [
      if (releaseId.trim().isNotEmpty) 'Release: $releaseId',
      if (sourceClass.trim().isNotEmpty) 'Source: $sourceClass',
      if (observedAtIso.trim().isNotEmpty) 'Observed: $observedAtIso',
      if (coverage.trim().isNotEmpty) 'Coverage: $coverage',
    ];

    return Tooltip(
      message: lines.join('\n'),
      child: InkWell(
        onTap: onOpenAudit,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: tokens.space2, vertical: tokens.space1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            border: Border.all(color: color.withValues(alpha: .4)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: tokens.space1),
              Text(label, style: tokens.captionStyle.copyWith(color: color, fontWeight: FontWeight.w900)),
              if (releaseId.trim().isNotEmpty) ...[
                SizedBox(width: tokens.space1),
                Text(releaseId, style: tokens.captionStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
