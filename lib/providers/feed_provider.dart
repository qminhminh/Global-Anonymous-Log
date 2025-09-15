import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EntryModel {
  final String id;
  final String content;
  int hearts;
  int repliesCount;
  final DateTime createdAt;
  final String? emotion;
  final String? imageUrl;
  final String? authorId;
  final DateTime? diaryDate;
  Map<String, int> reactionsCounts;

  EntryModel({
    required this.id,
    required this.content,
    required this.hearts,
    required this.repliesCount,
    required this.createdAt,
    this.emotion,
    this.imageUrl,
    this.authorId,
    this.diaryDate,
    Map<String, int>? reactionsCounts,
  }) : reactionsCounts = reactionsCounts ?? <String, int>{};

  factory EntryModel.fromMap(Map<String, dynamic> map) {
    return EntryModel(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      content: map['content'] ?? '',
      hearts: map['hearts'] is int ? map['hearts'] as int : int.tryParse('${map['hearts']}') ?? 0,
      repliesCount: map['repliesCount'] is int ? map['repliesCount'] as int : int.tryParse('${map['repliesCount']}') ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      emotion: map['emotion']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      authorId: map['authorId']?.toString(),
      diaryDate: DateTime.tryParse(map['diaryDate']?.toString() ?? ''),
      reactionsCounts: (map['reactionsCounts'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v is int ? v : int.tryParse('$v') ?? 0)) ?? <String, int>{},
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
  static final String baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  final List<EntryModel> _entries = <EntryModel>[];
  bool _loading = false;
  String? _error;
  String? _userId;

  List<EntryModel> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;
  String? get error => _error;
  String? get userId => _userId;

  void setUserId(String? id) {
    _userId = id;
    notifyListeners();
  }

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

  Map<String, String> _authHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_userId != null && _userId!.isNotEmpty) headers['x-user-id'] = _userId!;
    return headers;
  }

  Future<bool> followUser(String targetId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/social/follow/$targetId');
      final resp = await http.post(uri, headers: _authHeaders());
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<bool> unfollowUser(String targetId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/social/follow/$targetId');
      final resp = await http.delete(uri, headers: _authHeaders());
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<bool> createEntry(String content, {String? emotion, String? imageUrl, DateTime? diaryDate}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries');
      final resp = await http.post(
        uri,
        headers: _authHeaders(),
        body: json.encode({'content': content, 'emotion': emotion, 'imageUrl': imageUrl, 'diaryDate': diaryDate?.toIso8601String()}),
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
      final uri = Uri.parse('$baseUrl/api/entries/$id/react');
      final resp = await http.post(
        uri,
        headers: _authHeaders(),
        body: json.encode({ 'type': 'heart' }),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final counts = (data['counts'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v is int ? v : int.tryParse('$v') ?? 0));
        final idx = _entries.indexWhere((e) => e.id == id);
        if (idx != -1 && counts != null) { _entries[idx].reactionsCounts = counts; notifyListeners(); }
      }
    } catch (_) {
      // noop
    }
  }

  Future<void> reactToEntry(String id, String type) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries/$id/react');
      final resp = await http.post(
        uri,
        headers: _authHeaders(),
        body: json.encode({ 'type': type }),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final counts = (data['counts'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v is int ? v : int.tryParse('$v') ?? 0));
        final idx = _entries.indexWhere((e) => e.id == id);
        if (idx != -1 && counts != null) { _entries[idx].reactionsCounts = counts; notifyListeners(); }
      }
    } catch (_) {}
  }

  Future<bool> createReply(String entryId, String content) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries/$entryId/replies');
      final resp = await http.post(
        uri,
        headers: _authHeaders(),
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

  Future<bool> updateEntry(String id, {String? content, String? emotion, DateTime? diaryDate}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries/$id');
      final body = <String, dynamic>{};
      if (content != null) body['content'] = content;
      if (emotion != null) body['emotion'] = emotion;
      if (diaryDate != null) body['diaryDate'] = diaryDate.toIso8601String();
      final resp = await http.put(uri, headers: _authHeaders(), body: json.encode(body));
      if (resp.statusCode == 200) {
        final map = json.decode(resp.body) as Map<String, dynamic>;
        final updated = EntryModel.fromMap(map);
        final idx = _entries.indexWhere((e) => e.id == id);
        if (idx != -1) {
          _entries[idx] = updated;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (_) { return false; }
  }

  Future<bool> deleteEntry(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/entries/$id');
      final resp = await http.delete(uri, headers: _authHeaders());
      if (resp.statusCode == 200) {
        _entries.removeWhere((e) => e.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) { return false; }
  }
}
