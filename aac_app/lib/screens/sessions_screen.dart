import 'dart:math';
import 'package:flutter/material.dart';
import '../models/conversation_session.dart';
import '../models/contact_entry.dart';
import '../services/storage_service.dart';
import '../services/app_strings.dart';
import 'conversation_screen.dart';

class SessionsScreen extends StatefulWidget {
  final StorageService storage;
  const SessionsScreen({super.key, required this.storage});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _startQuickChat() async {
    // Quick chat — no session saved
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConversationScreen(storage: widget.storage),
    ));
  }

  Future<void> _showNewSessionDialog() async {
    final profile = widget.storage.getProfile()!;
    final lang = profile.uiLanguage;
    final contacts = profile.contacts;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewSessionSheet(
        storage: widget.storage,
        contacts: contacts,
        lang: lang,
        onCreated: (session) async {
          Navigator.of(ctx).pop();
          setState(() {});
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                ConversationScreen(storage: widget.storage, session: session),
          ));
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _openSession(ConversationSession session) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ConversationScreen(storage: widget.storage, session: session),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _deleteSession(ConversationSession session) async {
    final profile = widget.storage.getProfile()!;
    final lang = profile.uiLanguage;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content:
            Text('This will permanently delete "${session.displayName}" and all its messages.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.get('cancel', lang))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.storage.deleteSession(session.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.storage.getProfile()!;
    final lang = profile.uiLanguage;
    final allSessions = widget.storage.getSessions();
    final savedSessions =
        allSessions.where((s) => !s.isStranger).toList();
    final strangerSessions =
        allSessions.where((s) => s.isStranger).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.get('hi', lang)}, ${profile.name}!'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Saved Contacts'),
            Tab(icon: Icon(Icons.person_outline), text: 'Strangers'),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'quick',
            onPressed: _startQuickChat,
            tooltip: 'Quick Chat (not saved)',
            child: const Icon(Icons.flash_on),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new_session',
            onPressed: _showNewSessionDialog,
            icon: const Icon(Icons.add_comment),
            label: const Text('New Conversation'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SessionList(
            sessions: savedSessions,
            onTap: _openSession,
            onDelete: _deleteSession,
            emptyMessage: 'No saved contact conversations yet.\nTap + to start one!',
          ),
          _SessionList(
            sessions: strangerSessions,
            onTap: _openSession,
            onDelete: _deleteSession,
            emptyMessage: 'No stranger conversations yet.',
          ),
        ],
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<ConversationSession> sessions;
  final void Function(ConversationSession) onTap;
  final void Function(ConversationSession) onDelete;
  final String emptyMessage;

  const _SessionList({
    required this.sessions,
    required this.onTap,
    required this.onDelete,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(emptyMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final session = sessions[i];
        return Dismissible(
          key: ValueKey(session.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            onDelete(session);
            return false; // state update handles removal
          },
          child: Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(ctx).colorScheme.primaryContainer,
                child: Text(
                  session.displayName.isNotEmpty
                      ? session.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(session.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: session.notes != null && session.notes!.isNotEmpty
                  ? Text(session.notes!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : Text(_formatDate(session.lastMessageAt),
                      style: const TextStyle(fontSize: 12)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatDate(session.lastMessageAt),
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              onTap: () => onTap(session),
              onLongPress: () => onDelete(session),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── New Session Creation Sheet ─────────────────────────────────────────────

class _NewSessionSheet extends StatefulWidget {
  final StorageService storage;
  final List<ContactEntry> contacts;
  final String lang;
  final void Function(ConversationSession) onCreated;

  const _NewSessionSheet({
    required this.storage,
    required this.contacts,
    required this.lang,
    required this.onCreated,
  });

  @override
  State<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<_NewSessionSheet> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isStranger = false;
  ContactEntry? _selectedContact;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _generateId() {
    final rand = Random.secure();
    return List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  Future<void> _create() async {
    final name = _selectedContact?.name ?? _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }

    final session = ConversationSession(
      id: _generateId(),
      displayName: name,
      contactId: _selectedContact?.id,
      isStranger: _isStranger,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );
    await widget.storage.createSession(session);
    widget.onCreated(session);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: ListView(
          controller: sc,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Start a Conversation',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Pick existing contact or type a name
            if (widget.contacts.isNotEmpty) ...[
              Text('Choose a saved contact:',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.contacts.map((c) {
                  final selected = _selectedContact?.id == c.id;
                  return FilterChip(
                    label: Text(c.name),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedContact = selected ? null : c;
                      if (!selected) _nameController.text = c.name;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('or type a name')),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _nameController,
              enabled: _selectedContact == null,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Mom, Doctor, Ahmed...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. My cardiologist, speaks Arabic...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Stranger / One-off'),
              subtitle: const Text('Not a saved contact — conversation may be deleted later'),
              value: _isStranger,
              onChanged: (v) => setState(() => _isStranger = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.chat_bubble),
                label: const Text('Start Conversation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
