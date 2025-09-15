// ignore_for_file: unused_local_variable, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feed_provider.dart';
import 'replies_screen.dart';
import 'chat_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _starsCtrl;

  @override
  void initState() {
    super.initState();
    _starsCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().fetchFeed();
    });
  }

  @override
  void dispose() {
    _starsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AnonDiary'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (m) {
              context.read<FeedProvider>().fetchFeed(mode: m);
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'random', child: Text('Random (global)')),
              PopupMenuItem(value: 'recommended', child: Text('Recommended (most reactions)')),
              PopupMenuItem(value: 'latest', child: Text('Latest')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FeedProvider>().fetchFeed(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _starsCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _StarFieldPainter(progress: _starsCtrl.value),
              );
            },
          ),
          const _FeedList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openComposer(context),
        child: const Icon(Icons.edit),
      ),
    );
  }

  void _openComposer(BuildContext context) {
    final controller = TextEditingController();
    String? selectedEmotion;
    final emotions = <String>['joy','sad','angry','lonely','love','anxious','calm'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E12),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Share your feelings (anonymous)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write something... (max ~2000 chars)',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(builder: (context, setState) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: emotions.map((e) {
                    final selected = selectedEmotion == e;
                    return ChoiceChip(
                      label: Text(e),
                      selected: selected,
                      onSelected: (_) => setState(() => selectedEmotion = e),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Post anonymously'),
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  final ok = await context.read<FeedProvider>().createEntry(text, emotion: selectedEmotion);
                  if (ok && mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList();

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        if (feed.loading && feed.entries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (feed.error != null) {
          return Center(child: Text('Error: ${feed.error}'));
        }
        if (feed.entries.isEmpty) {
          return const Center(child: Text('No posts yet. Be the first!'));
        }
        // Responsive center column on wide screens
        final list = ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: feed.entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final e = feed.entries[index];
            final card = _EntryCard(entry: e, buildReactionBar: () => _reactionBar(context, e), onOpenReplies: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RepliesScreen(entry: e)),
              );
            });
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: card,
              ),
            );
          },
        );
        return list;
      },
    );
  }

  Widget _reactionBar(BuildContext context, EntryModel e) {
    final feed = context.read<FeedProvider>();
    final Map<String, int> counts = e.reactionsCounts;
    Widget item(String label, IconData icon, String type) {
      final c = counts[type] ?? 0;
      return Row(children: [
        _ghostIconButton(context, icon, () => feed.reactToEntry(e.id, type)),
        const SizedBox(width: 4),
        Text('$c'),
        const SizedBox(width: 8),
      ]);
    }
    return Row(children: [
      item('heart', Icons.favorite_border, 'heart'),
      item('happy', Icons.emoji_emotions_outlined, 'happy'),
      item('sad', Icons.mood_bad_outlined, 'sad'),
      item('angry', Icons.sentiment_very_dissatisfied_outlined, 'angry'),
    ]);
  }

}

class _EntryCard extends StatefulWidget {
  final EntryModel entry;
  final Widget Function() buildReactionBar;
  final VoidCallback onOpenReplies;
  const _EntryCard({required this.entry, required this.buildReactionBar, required this.onOpenReplies});

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  static const int _trimLength = 180;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final text = e.content;
    final bool shouldTrim = text.length > _trimLength;
    final String shown = _expanded || !shouldTrim ? text : text.substring(0, _trimLength) + '…';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E12).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.authorId != null ? 'anon:${e.authorId!.substring(0, 6)}' : 'anon',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: e.authorId == null ? null : () async {
                  final feed = context.read<FeedProvider>();
                  if (feed.userId != null && e.authorId == feed.userId) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't follow yourself")));
                    return;
                  }
                  final ok = await feed.followUser(e.authorId!);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Following anon user' : 'Failed to follow')));
                },
                child: const Text('Follow'),
              ),
              const SizedBox(width: 4),
              OutlinedButton(
                onPressed: e.authorId == null ? null : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(peerId: e.authorId!, title: 'Chat with ${e.authorId!.substring(0,6)}'),
                    ),
                  );
                },
                child: const Text('Message'),
              )
            ],
          ),
          const SizedBox(height: 8),
          if (e.emotion != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
              ),
              child: Text('#${e.emotion}', style: const TextStyle(color: Colors.tealAccent)),
            ),
            const SizedBox(height: 8),
          ],
          Text(shown, style: const TextStyle(fontSize: 16, height: 1.5)),
          if (shouldTrim && !_expanded) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = true),
              child: Text('See more', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              widget.buildReactionBar(),
              const SizedBox(width: 12),
              _ghostIconButton(context, Icons.reply, widget.onOpenReplies),
              Text('${e.repliesCount}'),
              const Spacer(),
              Text(formatTime(e.createdAt), style: const TextStyle(color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final double progress;
  _StarFieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.25);
    final numStars = 200;
    for (int i = 0; i < numStars; i++) {
      // pseudo random positions using i
      final dx = ((i * 37) % size.width);
      double dy = ((i * 91) % size.height);
      dy = (dy + progress * size.height) % size.height;
      final radius = 0.5 + (i % 3) * 0.4;
      canvas.drawCircle(Offset(dx.toDouble(), dy.toDouble()), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ---- Helpers (top-level) ----
Widget _ghostIconButton(BuildContext context, IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(icon, size: 18),
    ),
  );
}

String formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  return '${diff.inDays} d';
}
