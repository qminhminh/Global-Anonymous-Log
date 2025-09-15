import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String title;
  const ChatScreen({super.key, required this.peerId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final baseUrl = FeedProvider.baseUrl;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final uri = Uri.parse('$baseUrl/api/messages/${widget.peerId}?page=1&limit=50');
    final resp = await http.get(uri, headers: {'x-user-id': userId});
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>).cast<Map<String, dynamic>>();
      setState(() => _messages = items);
      await Future.delayed(const Duration(milliseconds: 50));
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final baseUrl = FeedProvider.baseUrl;
    final userId = context.read<AuthProvider>().userId;
    final uri = Uri.parse('$baseUrl/api/messages/${widget.peerId}');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', if (userId != null) 'x-user-id': userId},
      body: json.encode({'content': text}),
    );
    setState(() => _sending = false);
    if (resp.statusCode == 201) {
      _controller.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final mine = m['fromId'] == context.read<AuthProvider>().userId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: mine ? Colors.teal.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(m['content'] ?? ''),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Write a message...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending ? const CircularProgressIndicator() : const Icon(Icons.send),
                    onPressed: _send,
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

