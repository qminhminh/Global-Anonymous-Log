import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EntryModel {
  final String id;
  final String content;
  int hearts;
  int repliesCount;
  final DateTime createdAt;

  EntryModel({
    required this.id,
    required this.content,
    required this.hearts,
    required this.repliesCount,
    required this.createdAt,
  });

  factory EntryModel.fromMap(Map<String, dynamic> map) {
    return EntryModel(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      content: map['content'] ?? '',
      hearts: map['hearts'] is int ? map['hearts'] as int : int.tryParse('${map['hearts']}') ?? 0,
      repliesCount: map['repliesCount'] is int ? map['repliesCount'] as int : int.tryParse('${map['repliesCount']}') ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ReplyModel {
  final String id;
  final String entryId;
  final String content;
  final DateTime createdAt;

  ReplyModel({
    required this.id,
    required this.entryId,
    required this.content,
    required this.createdAt,
  });

  factory ReplyModel.fromMap(Map<String, dynamic> map) {
    return ReplyModel(
      id: map['id']?.toString() ?? map['_id']?.toString() ?? '',
      entryId: map['entryId']?.toString() ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class FeedProvider extends ChangeNotifier {
  // Ghi chú: đổi BASE_URL nếu deploy server
  static final String baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    // Ưu tiên --dart-define=API_BASE_URL=http://<host>:3000
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    // Mặc định: Android emulator -> 10.0.2.2, iOS simulator -> localhost
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  final List<EntryModel> _entries = <EntryModel>[];
  bool _loading = false;
  String? _error;

  List<EntryModel> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchFeed({String mode = 'random', int limit = 20}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final uri = Uri.parse('$baseUrl/api/entries?mode=$mode&limit=$limit');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final list = (data['items'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => EntryModel.fromMap(e as Map<String, dynamic>))
          .toList();
      _entries
        ..clear()
        ..addAll(list);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> createEntry(String content) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'content': content}),
      );
      if (resp.statusCode == 201) {
        final map = json.decode(resp.body) as Map<String, dynamic>;
        final created = EntryModel.fromMap(map);
        _entries.insert(0, created);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> heartEntry(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries/$id/heart');
      final resp = await http.post(uri);
      if (resp.statusCode == 200) {
        final idx = _entries.indexWhere((e) => e.id == id);
        if (idx != -1) {
          _entries[idx].hearts += 1;
          notifyListeners();
        }
      }
    } catch (_) {
      // noop
    }
  }

  Future<bool> createReply(String entryId, String content) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries/$entryId/replies');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'content': content}),
      );
      if (resp.statusCode == 201) {
        final idx = _entries.indexWhere((e) => e.id == entryId);
        if (idx != -1) {
          _entries[idx].repliesCount += 1;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<ReplyModel>> fetchReplies(String entryId, {int page = 1, int limit = 20}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries/$entryId/replies?page=$page&limit=$limit');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return <ReplyModel>[];
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final list = (data['items'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => ReplyModel.fromMap(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return <ReplyModel>[];
    }
  }
}
