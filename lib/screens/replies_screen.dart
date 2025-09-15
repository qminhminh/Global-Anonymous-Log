import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feed_provider.dart';

class RepliesScreen extends StatefulWidget {
  final EntryModel entry;
  const RepliesScreen({super.key, required this.entry});

  @override
  State<RepliesScreen> createState() => _RepliesScreenState();
}

class _RepliesScreenState extends State<RepliesScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ReplyModel> _replies = <ReplyModel>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await context.read<FeedProvider>().fetchReplies(widget.entry.id);
    setState(() {
      _replies = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trả lời ẩn danh'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bài viết', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(widget.entry.content),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_replies.isEmpty
                    ? const Center(child: Text('Chưa có trả lời nào'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _replies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final r = _replies[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: Text(r.content),
                            subtitle: Text(_formatTime(r.createdAt)),
                          );
                        },
                      )),
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
                      decoration: const InputDecoration(hintText: 'Viết trả lời ẩn danh...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      final ok = await context.read<FeedProvider>().createReply(widget.entry.id, text);
                      if (ok) {
                        _controller.clear();
                        await _load();
                      }
                    },
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return '${diff.inDays} ngày';
  }
}
