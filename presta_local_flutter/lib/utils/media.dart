import '../config/constants.dart';

/// Résout une URL de média (image) renvoyée par l'API.
///
/// Si [path] est déjà une URL absolue (commence par `http`), on la renvoie
/// telle quelle ; sinon on préfixe avec [AppConstants.baseUrl].
String resolveMediaUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  return '${AppConstants.baseUrl}$path';
}
