import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/constants.dart';

/// Exception métier levée par [ApiClient].
///
/// [message] est une chaîne lisible par l'utilisateur (champ `detail` de DRF
/// ou première erreur de champ). [errors] conserve les erreurs par champ pour
/// un affichage plus fin si besoin.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

/// Client HTTP centralisé vers l'API Django.
///
/// - Stocke les tokens JWT (access + refresh) dans le **stockage sécurisé**
///   de la plateforme (Keychain iOS, Keystore Android, DPAPI Windows,
///   Keychain macOS).
/// - Attache automatiquement le header `Authorization: Bearer <access>`.
/// - En cas de `401`, tente un refresh du token puis rejoue la requête.
/// - Transforme les réponses d'erreur DRF en [ApiException] lisible.
class ApiClient {
  static const String _accessKey = 'auth_access_token';
  static const String _refreshKey = 'auth_refresh_token';

  // Stockage sécurisé des tokens (chiffré par le système : le Keystore
  // natif est utilisé par défaut, sans option dépréciée).
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  final http.Client _client = http.Client();

  /// Délai max d'une requête réseau (backend Render gratuit qui s'endort :
  /// le premier appel après réveil peut prendre 30-60 s).
  static const Duration _networkTimeout = Duration(seconds: 15);

  // ---- Gestion des tokens ----

  Future<String?> getAccessToken() async {
    return _secure.read(key: _accessKey);
  }

  Future<String?> getRefreshToken() async {
    return _secure.read(key: _refreshKey);
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
  }

  Future<bool> hasTokens() async {
    return (await getAccessToken()) != null;
  }

  Uri _uri(String path) => Uri.parse('${AppConstants.baseUrl}$path');

  Map<String, String> _headers({bool authenticated = true}) {
    return {
      'Content-Type': 'application/json',
      if (authenticated) 'Authorization': 'Bearer $_cachedAccess',
    };
  }

  // Token en cache pour éviter de relire SharedPreferences à chaque appel.
  String? _cachedAccess;
  String? _cachedRefresh;
  Future<void> _cacheTokens() async {
    _cachedAccess = await getAccessToken();
    _cachedRefresh = await getRefreshToken();
  }

  // ---- Méthodes publiques ----

  /// Requête GET (authentifiée par défaut).
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _request('GET', path, authenticated: authenticated);
    return _decode(response);
  }

  /// Requête GET dont la réponse est un **tableau JSON** (ex. liste de
  /// conversations). Retourne une liste vide si le corps n'est pas un tableau.
  Future<List<dynamic>> getList(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _request('GET', path, authenticated: authenticated);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return [];
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map<String, dynamic> && decoded['results'] is List) {
          return decoded['results'] as List<dynamic>;
        }
        return [];
      } catch (_) {
        return [];
      }
    }
    throw ApiException(
      _messageFromErrors(_decodeErrors(response.body), response.statusCode),
      statusCode: response.statusCode,
    );
  }

  /// Décodage des erreurs sans lever d'exception (pour [getList]).
  Map<String, dynamic> _decodeErrors(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  /// Requête POST (avec ou sans authentification).
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _request(
      'POST',
      path,
      body: body,
      authenticated: authenticated,
    );
    return _decode(response, allowEmpty: true);
  }

  /// Requête PATCH authentifiée (mise à jour partielle).
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _request('PATCH', path, body: body);
    return _decode(response);
  }

  /// Requête DELETE authentifiée (ex. suppression d'une réalisation).
  /// Retourne `true` si le serveur répond 2xx (dont 204 sans corps).
  Future<bool> delete(String path) async {
    final response = await _request('DELETE', path);
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// POST en `multipart/form-data` pour publier avec un fichier
  /// (ex. réalisation sur `POST /api/feed/` avec `titre` + `image`).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? fields,
    required Uint8List fileBytes,
    required String filename,
    String fileField = 'image',
  }) async {
    await _cacheTokens();
    final uri = _uri(path);
    final request = http.MultipartRequest('POST', uri);
    if (_cachedAccess != null) {
      request.headers['Authorization'] = 'Bearer $_cachedAccess';
    }
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: filename,
        contentType: MediaType('image', _mimeType(filename)),
      ),
    );
    final streamed = await request.send().timeout(_networkTimeout);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  /// PATCH en `multipart/form-data` pour l'upload d'un fichier
  /// (ex. photo de profil) sur `/api/auth/me/`.
  Future<Map<String, dynamic>> patchMultipart(
    String path, {
    Map<String, String>? fields,
    required Uint8List fileBytes,
    required String filename,
    String fileField = 'photo_profil',
  }) async {
    await _cacheTokens();
    final uri = _uri(path);
    final request = http.MultipartRequest('PATCH', uri)
      ..headers['Authorization'] = 'Bearer $_cachedAccess';
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: filename,
        contentType: MediaType('image', _mimeType(filename)),
      ),
    );
    final streamed = await request.send().timeout(_networkTimeout);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  String _mimeType(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'jpeg';
    if (name.endsWith('.webp')) return 'webp';
    if (name.endsWith('.gif')) return 'gif';
    return 'jpeg';
  }

  // ---- Implémentation ----

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool allowRetry = true,
  }) async {
    await _cacheTokens();

    final uri = _uri(path);
    final headers = _headers(authenticated: authenticated);
    final encoded = body == null ? null : jsonEncode(body);

    var response = await _send(method, uri, headers, encoded);

    // Le refresh token a expiré : déconnexion silencieuse.
    if (response.statusCode == 401 &&
        authenticated &&
        allowRetry &&
        _cachedRefresh != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await _send(method, uri, _headers(), encoded);
      }
    }

    return response;
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    // Timeout explicite : sans lui, un backend endormi (ou un réseau mort)
    // bloque l'appel indéfiniment. Lève TimeoutException, traitée comme
    // une erreur réseau par les appelants.
    switch (method) {
      case 'GET':
        return await _client
            .get(uri, headers: headers)
            .timeout(_networkTimeout);
      case 'POST':
        return await _client
            .post(uri, headers: headers, body: body)
            .timeout(_networkTimeout);
      case 'PATCH':
        return await _client
            .patch(uri, headers: headers, body: body)
            .timeout(_networkTimeout);
      case 'PUT':
        return await _client
            .put(uri, headers: headers, body: body)
            .timeout(_networkTimeout);
      case 'DELETE':
        return await _client
            .delete(uri, headers: headers)
            .timeout(_networkTimeout);
      default:
        throw ApiException('Méthode HTTP non supportée : $method');
    }
  }

  /// Tente de rafraîchir l'access token via `/api/auth/token/refresh/`.
  /// Retourne `true` si un nouvel access token a été obtenu.
  Future<bool> _tryRefresh() async {
    if (_cachedRefresh == null) return false;
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/auth/token/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': _cachedRefresh}),
          )
          .timeout(_networkTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = data['access'] as String;
        _cachedAccess = newAccess;
        await _secure.write(key: _accessKey, value: newAccess);
        // SimpleJWT avec ROTATE_REFRESH_TOKENS=True renvoie un nouveau refresh.
        final newRefresh = data['refresh'];
        if (newRefresh != null) {
          _cachedRefresh = newRefresh as String;
          await _secure.write(key: _refreshKey, value: newRefresh);
        }
        return true;
      }
      // Refresh invalide : on vide les tokens.
      await clearTokens();
      _cachedAccess = null;
      _cachedRefresh = null;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Décode la réponse JSON, en soulevant [ApiException] en cas d'erreur.
  Map<String, dynamic> _decode(
    http.Response response, {
    bool allowEmpty = false,
  }) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // Corps non-JSON : on ignore.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw ApiException(
      _messageFromErrors(data, response.statusCode),
      statusCode: response.statusCode,
      errors: data,
    );
  }

  String _messageFromErrors(Map<String, dynamic> data, int statusCode) {
    if (data.containsKey('detail')) {
      return data['detail'].toString();
    }
    // Erreurs par champ : on prend la première.
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        return '${entry.key} : ${value.first}';
      }
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    if (statusCode >= 500) {
      return AppConstants.errorServer;
    }
    if (statusCode == 401) {
      return 'Email ou mot de passe incorrect.';
    }
    return AppConstants.errorUnknown;
  }
}
