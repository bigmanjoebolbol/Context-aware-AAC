import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../models/contact_entry.dart';
import '../services/storage_service.dart';

class ContactsManagementScreen extends StatefulWidget {
  final StorageService storage;
  const ContactsManagementScreen({super.key, required this.storage});

  @override
  State<ContactsManagementScreen> createState() => _ContactsManagementScreenState();
}

class _ContactsManagementScreenState extends State<ContactsManagementScreen> {
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.getProfile()!;
  }

  Future<void> _importFromPhone() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      if (!mounted) return;
      
      final selected = await showModalBottomSheet<Contact>(
        context: context,
        builder: (context) => ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(contacts[i].displayName),
            onTap: () => Navigator.pop(context, contacts[i]),
          ),
        ),
      );

      if (selected != null) {
        _addContact(selected.displayName, 'Friend');
      }
    }
  }

  void _addContact(String name, String relationship) {
    final entry = ContactEntry(
      id: const Uuid().v4(),
      name: name,
      relationship: relationship,
    );
    setState(() {
      _profile.contacts.add(entry);
    });
    widget.storage.saveProfile(_profile);
  }

  void _deleteContact(ContactEntry entry) {
    setState(() {
      _profile.contacts.remove(entry);
    });
    widget.storage.saveProfile(_profile);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _importFromPhone,
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Add people you talk to frequently. This helps the AI suggest more personal replies.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          ..._profile.contacts.map((c) => ListTile(
            leading: CircleAvatar(child: Text(c.name[0])),
            title: Text(c.name),
            subtitle: Text(c.relationship),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteContact(c),
            ),
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship (e.g. Mom, Boss)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                _addContact(nameCtrl.text, relCtrl.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
