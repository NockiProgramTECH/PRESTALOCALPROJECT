import 'package:flutter/material.dart';

/// Barre de recherche réutilisable avec options de filtrage
///
/// Supporte la recherche par texte avec option de filtre par zone.
/// Utilisée dans la page d'accueil (hero) et la page de recherche.
class SearchBarWidget extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final bool showFilter;
  final bool autoFocus;
  final String? selectedZone;
  final VoidCallback? onZoneTap;
  final Color? backgroundColor;

  const SearchBarWidget({
    super.key,
    this.controller,
    this.hintText = 'Rechercher un service...',
    this.onSubmitted,
    this.onChanged,
    this.onFilterTap,
    this.showFilter = false,
    this.autoFocus = false,
    this.selectedZone,
    this.onZoneTap,
    this.backgroundColor,
  });

  /// Version hero pour la page d'accueil (grande, avec fond vert)
  factory SearchBarWidget.hero({
    TextEditingController? controller,
    ValueChanged<String>? onSubmitted,
    String? selectedZone,
    VoidCallback? onZoneTap,
  }) {
    return SearchBarWidget(
      controller: controller,
      onSubmitted: onSubmitted,
      selectedZone: selectedZone,
      onZoneTap: onZoneTap,
      hintText: 'Quel service cherchez-vous ?',
      backgroundColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: backgroundColor == Colors.white
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Champ de recherche
          TextField(
            controller: controller,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            autofocus: autoFocus,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
              suffixIcon: showFilter
                  ? IconButton(
                      icon: Icon(Icons.tune_rounded, color: Colors.grey.shade500),
                      onPressed: onFilterTap,
                    )
                  : null,
              border: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          // Sélecteur de zone
          if (selectedZone != null)
            InkWell(
              onTap: onZoneTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      selectedZone!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down,
                        size: 20, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
