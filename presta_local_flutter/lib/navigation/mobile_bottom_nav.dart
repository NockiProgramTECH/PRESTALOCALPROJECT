import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Onglets de la barre de navigation inférieure.
enum AppTab {
  accueil(Icons.home_rounded, 'Accueil'),
  rechercher(Icons.search_rounded, 'Recherche'),
  favoris(Icons.favorite_rounded, 'Favoris'),
  messages(Icons.chat_bubble_rounded, 'Messages'),
  profil(Icons.person_rounded, 'Profil');

  final IconData icon;
  final String label;

  const AppTab(this.icon, this.label);
}

/// Barre de navigation inférieure (maquette) : fond blanc, icône active
/// orange avec pastille claire, badge sur Messages.
class MobileBottomNav extends StatelessWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;
  final int unreadCount;

  const MobileBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: AppTab.values.map((tab) {
            final isSelected = tab == currentTab;
            final color = isSelected ? AppTheme.primary : AppTheme.muted;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTabSelected(tab),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(tab.icon, size: 24, color: color),
                          if (tab == AppTab.messages && unreadCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
