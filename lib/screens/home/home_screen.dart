import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contact_provider.dart';
import 'chat_list_screen.dart';
import '../../widgets/add_contact_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecretChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: const ChatListScreen(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddContactDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddContactDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddContactDialog(),
    );

    if (result == true && context.mounted) {
      // Reload contacts
      context.read<ContactProvider>().loadContacts();
    }
  }
}
