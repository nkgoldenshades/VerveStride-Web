import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../models/conversation_thread.dart';
import '../../services/unified_ai_chat_service.dart';
import '../../widgets/gradient_scaffold.dart';
import 'ai_chat_screen.dart';

class AIThreadsScreen extends StatefulWidget {
  const AIThreadsScreen({super.key});

  @override
  State<AIThreadsScreen> createState() => _AIThreadsScreenState();
}

class _AIThreadsScreenState extends State<AIThreadsScreen> {
  final UnifiedAIChatService _chatService = UnifiedAIChatService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<ConversationThread> _threads = [];
  List<ConversationThread> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chatService.addListener(_onUpdated);
    _load();
  }

  @override
  void dispose() {
    _chatService.removeListener(_onUpdated);
    _searchController.dispose();
    super.dispose();
  }

  void _onUpdated() => _load();

  Future<void> _load() async {
    await _chatService.initialize();
    if (!mounted) return;
    final threads = _chatService.getAllThreads();
    setState(() {
      _threads = threads;
      _filtered = _applyFilter(threads, _searchController.text);
      _isLoading = false;
    });
  }

  List<ConversationThread> _applyFilter(
      List<ConversationThread> threads, String q) {
    if (q.isEmpty) return threads;
    final lq = q.toLowerCase();
    return threads
        .where((t) =>
            t.title.toLowerCase().contains(lq) ||
            t.messages.any((m) => m.content.toLowerCase().contains(lq)))
        .toList();
  }

  void _onSearch(String q) {
    setState(() => _filtered = _applyFilter(_threads, q));
  }

  Future<void> _newThread() async {
    await _chatService.initialize();
    final thread = await _chatService.getActiveThread();
    // Force a fresh thread
    await _chatService.deleteThread(thread.id);
    final fresh = await _chatService.getActiveThread();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AIChatScreen(threadId: fresh.id)),
    ).then((_) => _load());
  }

  Future<void> _openThread(ConversationThread thread) async {
    await _chatService.switchToThread(thread.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AIChatScreen(threadId: thread.id)),
    ).then((_) => _load());
  }

  Future<void> _deleteThread(ConversationThread thread) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Chat',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Delete "${thread.title}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _chatService.deleteThread(thread.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('AI Chats'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Chat',
              onPressed: _newThread),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle:
                    const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchController.text.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.chat_bubble_outline,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No chats found'
                                  : 'No chats yet',
                              style: const TextStyle(
                                  fontSize: 18,
                                  color: AppColors.textSecondary),
                            ),
                            if (_searchController.text.isEmpty) ...[
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _newThread,
                                icon: const Icon(Icons.add),
                                label: const Text('New Chat'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final t = _filtered[i];
                          final last = t.messages.isNotEmpty
                              ? t.messages.last
                              : null;
                          final isActive =
                              _chatService.activeThread?.id == t.id;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            color: isActive
                                ? AppColors.primary.withOpacity(0.15)
                                : AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isActive
                                  ? BorderSide(
                                      color: AppColors.primary
                                          .withOpacity(0.4))
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.2),
                                child: Icon(Icons.smart_toy,
                                    color: AppColors.primary, size: 18),
                              ),
                              title: Text(
                                t.title,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (last != null)
                                    Text(
                                      last.content,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    '${DateFormat('MMM d').format(t.lastMessageAt)} · ${t.messages.length} messages',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.textSecondary,
                                    size: 18),
                                onPressed: () => _deleteThread(t),
                              ),
                              onTap: () => _openThread(t),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
