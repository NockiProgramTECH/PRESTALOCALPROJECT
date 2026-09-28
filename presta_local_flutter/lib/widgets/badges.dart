import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Pastilles de statut du design system Warm Kinetic :
/// « Disponible » (point émeraude pulsant implicite) et « Vérifié ».
class StatusPills extends StatelessWidget {
  final bool isVerified;
  final String? availabilityLabel;
  final bool compact;

  const StatusPills({
    super.key,
    this.isVerified = false,
    this.availabilityLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (isVerified) const VerifiedPill(),
        if (availabilityLabel != null)
          AvailablePill(label: availabilityLabel!, compact: compact),
      ],
    );
  }
}

/// Pastille « Vérifié PrestLocal » : fond émeraude clair + icône bouclier.
class VerifiedPill extends StatelessWidget {
  final String label;

  const VerifiedPill({super.key, this.label = 'Vérifié PrestLocal'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.successSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            size: 14,
            color: AppTheme.successDeep,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.successDeep,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille « Disponible ... » : point émeraude + libellé vert foncé.
class AvailablePill extends StatelessWidget {
  final String label;
  final bool compact;

  const AvailablePill({super.key, required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.successSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.successText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille générique (tri, filtres, compteurs) : fond sable, texte navy.
class SoftPill extends StatelessWidget {
  final String label;
  final Color? background;
  final Color? foreground;

  const SoftPill({
    super.key,
    required this.label,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? AppTheme.inputFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground ?? AppTheme.navy,
        ),
      ),
    );
  }
}
