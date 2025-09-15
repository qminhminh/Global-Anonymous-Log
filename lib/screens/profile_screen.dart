import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? me;
  List<dynamic> myPosts = <dynamic>[];
  List<dynamic> myHearts = <dynamic>[];
  List<dynamic> conversations = <dynamic>[];
  bool saving = false;

  late final TabController _tab = TabController(length: 3, vsync: this);
  final TextEditingController _avatar = TextEditingController();
  final TextEditingController _color = TextEditingController(text: '#27B0A5');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final baseUrl = FeedProvider.baseUrl;
    final uid = context.read<AuthProvider>().userId;
    if (uid == null) return;
    Future<Map<String, dynamic>?> getJson(String path) async {
      final resp = await http.get(Uri.parse('$baseUrl$path'), headers: {'x-user-id': uid});
      if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
      return null;
    }
    final meRes = await getJson('/api/profile/me');
    if (meRes != null) {
      me = meRes;
      _avatar.text = (meRes['avatarUrl'] ?? '') as String;
      _color.text = (meRes['themeColor'] ?? '#27B0A5') as String;
    }
    final postsRes = await getJson('/api/profile/my-entries');
    final heartsRes = await getJson('/api/profile/my-hearts');
    final convRes = await http.get(Uri.parse('$baseUrl/api/messages'), headers: {'x-user-id': uid});
    if (mounted) {
      setState(() {
        myPosts = (postsRes?['items'] as List<dynamic>? ?? <dynamic>[]);
        myHearts = (heartsRes?['items'] as List<dynamic>? ?? <dynamic>[]);
        conversations = convRes.statusCode == 200
            ? ((json.decode(convRes.body) as Map<String, dynamic>)['items'] as List<dynamic>)
            : <dynamic>[];
      });
    }
  }

  Future<void> _saveProfile() async {
    final baseUrl = FeedProvider.baseUrl;
    final uid = context.read<AuthProvider>().userId;
    if (uid == null) return;
    setState(() => saving = true);
    final resp = await http.post(
      Uri.parse('$baseUrl/api/profile/me'),
      headers: {'Content-Type': 'application/json', 'x-user-id': uid},
      body: json.encode({'avatarUrl': _avatar.text.trim(), 'themeColor': _color.text.trim()}),
    );
    setState(() => saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resp.statusCode == 200 ? 'Saved' : 'Save failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(text: 'Posts'),
          Tab(text: 'Loved'),
          Tab(text: 'Messages'),
        ]),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildPosts(myPosts),
          _buildPosts(myHearts),
          _buildConversations(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      color: const Color(0xFF0E0E12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: (_avatar.text.trim().isNotEmpty) ? NetworkImage(_avatar.text.trim()) : null,
                  child: (_avatar.text.trim().isEmpty) ? const Icon(Icons.person, size: 28) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('anon:${_shortId((me?['anonId'] ?? '').toString())}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _avatar, decoration: const InputDecoration(hintText: 'Avatar URL'))),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: TextField(controller: _color, decoration: const InputDecoration(hintText: '#031D31')),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: saving ? null : _saveProfile,
              icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPosts(List<dynamic> items) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader();
          final it = items[index - 1] as Map<String, dynamic>;
          return ListTile(
            tileColor: const Color(0xFF0E0E12),
            title: Text((it['content'] ?? '') as String, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(_formatTime(DateTime.tryParse((it['createdAt'] ?? '').toString()) ?? DateTime.now())),
          );
        },
      ),
    );
  }

  Widget _buildConversations() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, i) {
          final c = conversations[i] as Map<String, dynamic>;
          final peer = (c['peerId'] ?? '').toString();
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            tileColor: const Color(0xFF0E0E12),
            title: Text('anon:${_shortId(peer)}'),
            subtitle: Text((c['lastMessage'] ?? '') as String, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChatScreen(peerId: peer, title: 'Chat with ${_shortId(peer)}')),
              );
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: conversations.length,
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  return '${diff.inDays} d';
}

String _shortId(String s) {
  if (s.isEmpty) return '';
  if (s.length <= 6) return s;
  return s.substring(0, 6);
}


