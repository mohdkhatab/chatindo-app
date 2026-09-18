import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_session.dart';
import 'api_client.dart';

/// Holds the auth session, persists tokens, and exposes the API client.
class SessionController extends ChangeNotifier {
  SessionController() {
    unawaited(_restore());
  }

  final ApiClient api = ApiClient();

  AppSession? _session;
  bool _ready = false;
  String? _pendingUserId;

  AppSession? get session => _session;
  bool get ready => _ready;
  bool get loggedIn => _session != null;
  bool get busy => !_ready;

  static const _kAccess = 'session.access_token';
  static const _kRefresh = 'session.refresh_token';
  static const _kUserId = 'session.user_id';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_kAccess);
    final refresh = prefs.getString(_kRefresh);
    if (access != null && refresh != null) {
      _session = AppSession(accessToken: access, refreshToken: refresh);
      api.accessToken = access;
      api.refreshToken = refresh;
      _pendingUserId = prefs.getString(_kUserId);
      try {
        await _fetchMe();
      } catch (_) {
        // Token exchange failed; fall through to ready state.
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _fetchMe() async {
    try {
      final body = await api.get('users-me');
      final me = body['user'];
      _pendingUserId = me is Map ? (me['id'] as String?) : null;
      await _persist();
    } catch (_) {
      // Token may have expired — attempt a silent refresh.
      await refresh();
    }
  }

  /// Exchange refresh_token for a fresh pair.
  Future<void> refresh() async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken == null) return;
    final body = await api.post('auth-refresh-token', body: {'refresh_token': refreshToken});
    await _applySession(body['access_token'] as String?, body['refresh_token'] as String?);
  }

  Future<void> login(String email, String password) async {
    final body = await api.post('auth-login', body: {'email': email, 'password': password});
    await _applySession(body['access_token'] as String?, body['refresh_token'] as String?);
  }

  Future<void> signup({required String email, required String password, required String username, required String displayName}) async {
    final body = await api.post('auth-signup', body: {
      'email': email,
      'password': password,
      'username': username,
      'display_name': displayName,
    });
    await _applySession(body['access_token'] as String?, body['refresh_token'] as String?);
  }

  Future<void> logout() async {
    try {
      await api.post('auth-logout');
    } catch (_) {
      // best-effort; still clear local state
    }
    await _clear();
  }

  Future<void> _applySession(String? access, String? refresh) async {
    if (access == null || refresh == null) {
      throw ApiException('Session tokens were not returned');
    }
    _session = AppSession(accessToken: access, refreshToken: refresh);
    api.accessToken = access;
    api.refreshToken = refresh;
    await _fetchMe();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_session != null) {
      await prefs.setString(_kAccess, _session!.accessToken);
      await prefs.setString(_kRefresh, _session!.refreshToken);
      await prefs.setString(_kUserId, _pendingUserId ?? '');
    }
  }

  Future<void> _clear() async {
    _session = null;
    api.accessToken = null;
    api.refreshToken = null;
    _pendingUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUserId);
    notifyListeners();
  }

  /// Runs a request and retries it once after refreshing the token on a 401.
  Future<Map<String, dynamic>> guarded(Future<Map<String, dynamic>> Function() run) async {
    try {
      return await run();
    } on ApiException catch (e) {
      if (e.statusCode == 401 && _session != null) {
        try {
          await refresh();
          return await run();
        } catch (re) {
          if (re is ApiException && re.statusCode == 401) {
            await _clear();
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  String? get currentUserId => _pendingUserId ?? _session?.claimsUserId;

  Map<String, dynamic>? get meAvatar {
    return null; // profile details are fetched through users-me when needed.
  }
}

/// Build from decoded JWT (payload base64) so refresh failures can force logout.
extension on AppSession {
  String? get claimsUserId {
    try {
      final parts = accessToken.split('.');
      final payload = parts.length >= 2 ? jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic> : null;
      return payload?['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}