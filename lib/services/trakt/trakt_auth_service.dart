import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class TraktAuthService {
  static final TraktAuthService _instance = TraktAuthService._internal();
  factory TraktAuthService() => _instance;
  TraktAuthService._internal();

  // Replace with your own Trakt API client ID from https://trakt.tv/oauth/applications
  static const String clientId = 'YOUR_TRAKT_CLIENT_ID';
  static const String redirectUri = 'playtorrio://trakt-callback';
  static const String _tokenUrl = 'https://api.trakt.tv/oauth/token';
  static const String _revokeUrl = 'https://api.trakt.tv/oauth/revoke';
  static const String _authorizeUrl = 'https://trakt.tv/oauth/authorize';

  final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _codeVerifier;

  String? get accessToken => _accessToken;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('trakt_access_token');
    _refreshToken = prefs.getString('trakt_refresh_token');
    final expiresStr = prefs.getString('trakt_expires_at');
    if (expiresStr != null) {
      _expiresAt = DateTime.tryParse(expiresStr);
    }
    isLoggedIn.value = _accessToken != null && (_expiresAt == null || _expiresAt!.isAfter(DateTime.now()));
    if (isLoggedIn.value && _expiresAt != null && _expiresAt!.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      await refreshAccessToken();
    }
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    // Simple S256: use sha256 if crypto package available, otherwise fallback to plain
    // For production, add crypto package and use sha256
    return verifier;
  }

  Future<void> authorize() async {
    _codeVerifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(_codeVerifier!);

    final authUrl = '$_authorizeUrl?'
        'response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=$redirectUri'
        '&code_challenge=$challenge'
        '&code_challenge_method=plain';

    isLoading.value = true;
    try {
      await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> handleCallback(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code == null) return false;

    isLoading.value = true;
    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': _codeVerifier,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'] as String;
        _refreshToken = data['refresh_token'] as String;
        final expiresIn = data['expires_in'] as int? ?? 7776000;
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await _persistTokens();
        isLoggedIn.value = true;
        return true;
      }
    } catch (e) {
      debugPrint('Trakt auth error: $e');
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refresh_token': _refreshToken,
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'grant_type': 'refresh_token',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'] as String;
        _refreshToken = data['refresh_token'] as String;
        final expiresIn = data['expires_in'] as int? ?? 7776000;
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await _persistTokens();
        isLoggedIn.value = true;
        return true;
      }
    } catch (e) {
      debugPrint('Trakt refresh error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    if (_accessToken != null) {
      try {
        await http.post(
          Uri.parse(_revokeUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': _accessToken}),
        );
      } catch (_) {}
    }

    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _codeVerifier = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trakt_access_token');
    await prefs.remove('trakt_refresh_token');
    await prefs.remove('trakt_expires_at');

    isLoggedIn.value = false;
  }

  Future<void> _persistTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString('trakt_access_token', _accessToken!);
    if (_refreshToken != null) await prefs.setString('trakt_refresh_token', _refreshToken!);
    if (_expiresAt != null) await prefs.setString('trakt_expires_at', _expiresAt!.toIso8601String());
  }
}
