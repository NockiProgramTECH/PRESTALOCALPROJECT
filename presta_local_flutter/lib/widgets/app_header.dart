import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'brand_mark.dart';

/// En-tête commun des écrans principaux (maquette) :
/// logo + pilule localisation, cloche avec pastille, avatar.
///
/// Utilisé par Accueil et Recherche. Les autres onglets utilisent
/// une variante compacte via [AppHeader.slim].
class AppHeader extends StatelessWidget {
  final String? locationLabel;
  final VoidCallback? onLocationTap;
  final VoidCallback? onNotificationsTap;
  final bool hasNotification;
  final String? userName;
  final String? userPhoto;
  final VoidCallback? onAvatarTap;
  final bool slim;
  final String? title;
  final String? subtitle;

  const AppHeader({
    super.key,
    this.locationLabel,
    this.onLocationTap,
    this.onNotificationsTap,
    this.hasNotification = false,
    this.userName,
    this.userPhoto,
    this.onAvatarTap,
    this.slim = false,
    this.title,
    this.subtitle,
  });

  /// Variante compacte : logo + titre (+ sous-titre), cloche, avatar.
  const AppHeader.slim({
    super.key,
    this.title,
    this.subtitle,
    this.onNotificationsTap,
    this.hasNotification = false,
    this.userName,
    this.userPhoto,
    this.onAvatarTap,
  }) : locationLabel = null,
       onLocationTap = null,
       slim = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            const BrandMark(size: 38, radius: 11, iconSize: 20),
            const SizedBox(width: 10),
            Expanded(child: slim ? _slimTitle() : _location()),
            _bell(),
            const SizedBox(width: 10),
            _avatar(),
          ],
        ),
      ),
    );
  }

  Widget _slimTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title ?? 'PrestLocal',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
      ],
    );
  }

  Widget _location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PrestLocal',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: onLocationTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.inputFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    locationLabel ?? 'Ouagadougou, BF',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: AppTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bell() {
    return GestureDetector(
      onTap: onNotificationsTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_outlined,
            size: 26,
            color: AppTheme.navy,
          ),
          if (hasNotification)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final photo = userPhoto?.isNotEmpty == true ? userPhoto! : null;
    return GestureDetector(
      onTap: onAvatarTap,
      child: CircleAvatar(
        radius: 17,
        backgroundColor: AppTheme.primarySoft,
        backgroundImage: photo != null
            ? CachedNetworkImageProvider(photo)
            : null,
        child: photo == null
            ? Text(
                userName?.isNotEmpty == true ? userName![0].toUpperCase() : 'P',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}
