import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/auth_models.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key, required this.api});

  final HttpApiService api;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserAccount> _users = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await widget.api.getAllUsers();
      setState(() => _users = users);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editUser(UserAccount u) async {
    final nameCtl = TextEditingController(text: u.displayName);
    String role = u.systemRole;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa ${u.username}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Tên hiển thị')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: const [
                DropdownMenuItem(value: 'user', child: Text('user')),
                DropdownMenuItem(value: 'admin', child: Text('admin')),
              ],
              onChanged: (v) => role = v ?? role,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              await widget.api.adminUpdateUser(userId: u.id!, displayName: nameCtl.text.trim(), systemRole: role);
              if (!mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserAccount u) async {
    await widget.api.adminDeleteUser(u.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý người dùng')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, i) {
                final u = _users[i];
                return ListTile(
                  title: Text(u.displayName),
                  subtitle: Text('${u.email ?? u.username} • ${u.systemRole}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') await _editUser(u);
                      if (v == 'delete') await _deleteUser(u);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      PopupMenuItem(value: 'delete', child: Text('Xóa tài khoản')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
