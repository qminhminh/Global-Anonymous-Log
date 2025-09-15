import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  static final String _baseUrl = _resolveBaseUrl();
  static String _resolveBaseUrl() {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  String? _userId;
  String? get userId => _userId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    notifyListeners();
  }

  Future<String?> signInAnonymous() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/anonymous');
      final resp = await http.post(uri);
      if (resp.statusCode == 201) {
        final map = json.decode(resp.body) as Map<String, dynamic>;
        final id = (map['userId'] ?? '').toString();
        if (id.isNotEmpty) {
          _userId = id;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', id);
          notifyListeners();
          return id;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    notifyListeners();
  }
}
