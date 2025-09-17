import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GameProvider extends ChangeNotifier {
  final String baseUrl;
  String? _userId;

  GameProvider({String? overrideBaseUrl})
      : baseUrl = overrideBaseUrl ?? _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  void setUserId(String? id) { _userId = id; }
  Map<String, String> _headers() {
    final h = <String, String>{ 'Content-Type': 'application/json' };
    if (_userId != null && _userId!.isNotEmpty) h['x-user-id'] = _userId!;
    return h;
  }

  String? currentCode;
  String? question;
  String? optionA;
  String? optionB;
  int votesA = 0;
  int votesB = 0;
  Timer? _poller;

  void _apply(Map<String, dynamic> data) {
    currentCode = data['code']?.toString();
    question = data['question']?.toString();
    optionA = data['optionA']?.toString();
    optionB = data['optionB']?.toString();
    votesA = (data['votesA'] is int) ? data['votesA'] : int.tryParse('${data['votesA']}') ?? 0;
    votesB = (data['votesB'] is int) ? data['votesB'] : int.tryParse('${data['votesB']}') ?? 0;
    notifyListeners();
  }

  Future<String?> createRoom(String q, String a, String b) async {
    final uri = Uri.parse('$baseUrl/api/game/create');
    final resp = await http.post(uri, headers: _headers(), body: json.encode({ 'question': q, 'optionA': a, 'optionB': b }));
    if (resp.statusCode == 201) {
      final map = json.decode(resp.body) as Map<String, dynamic>;
      currentCode = map['code']?.toString();
      await fetchRoom(currentCode!);
      return currentCode;
    }
    return null;
  }

  Future<bool> joinRoom(String code) async {
    final uri = Uri.parse('$baseUrl/api/game/join/$code');
    final resp = await http.post(uri, headers: _headers());
    if (resp.statusCode == 200) {
      currentCode = code;
      await fetchRoom(code);
      return true;
    }
    return false;
  }

  Future<void> fetchRoom(String code) async {
    final uri = Uri.parse('$baseUrl/api/game/room/$code');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final map = json.decode(resp.body) as Map<String, dynamic>;
      _apply(map);
    }
  }

  Future<void> vote(String choice) async {
    if (currentCode == null) return;
    final uri = Uri.parse('$baseUrl/api/game/vote/$currentCode');
    await http.post(uri, headers: _headers(), body: json.encode({ 'choice': choice }));
    await fetchRoom(currentCode!);
  }

  void startPolling() {
    _poller?.cancel();
    if (currentCode == null) return;
    _poller = Timer.periodic(const Duration(seconds: 2), (_) => fetchRoom(currentCode!));
  }

  void stopPolling() { _poller?.cancel(); _poller = null; }
}
