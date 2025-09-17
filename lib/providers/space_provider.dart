import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SpaceProvider extends ChangeNotifier {
  final String baseUrl;
  String? _userId;
  SpaceProvider({String? overrideBaseUrl}) : baseUrl = overrideBaseUrl ?? _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  void setUserId(String? id) { _userId = id; }
  Map<String, String> _headers() { final h = <String, String>{'Content-Type': 'application/json'}; if (_userId!=null&&_userId!.isNotEmpty) h['x-user-id']=_userId!; return h; }

  Future<bool> submitScore(int score) async {
    final uri = Uri.parse('$baseUrl/api/space/score');
    final resp = await http.post(uri, headers: _headers(), body: json.encode({'score': score}));
    return resp.statusCode == 201;
  }

  Future<List<Map<String, dynamic>>> leaderboard() async {
    final uri = Uri.parse('$baseUrl/api/space/leaderboard');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return <Map<String, dynamic>>[];
    final map = json.decode(resp.body) as Map<String, dynamic>;
    final items = (map['items'] as List<dynamic>? ?? [])
        .map((e) => {'userId': e['userId']?.toString() ?? '', 'best': e['best'] is int ? e['best'] : int.tryParse('${e['best']}') ?? 0})
        .toList();
    return items;
  }
}
