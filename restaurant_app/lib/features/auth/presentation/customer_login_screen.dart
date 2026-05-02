import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
  });

  final Future<String?> Function(String email, String password) onLogin;
  final Future<String?> Function(String displayName, String email, String password) onRegister;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginEmailController = TextEditingController();
  final _loginPassController = TextEditingController();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPassController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _busy = true);
    final err = await widget.onLogin(_loginEmailController.text.trim(), _loginPassController.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập đủ thông tin, mật khẩu tối thiểu 6 ký tự')),
      );
      return;
    }

    setState(() => _busy = true);
    final err = await widget.onRegister(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Đăng ký thành công. Bạn có thể đăng nhập.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tài khoản hệ thống'),
          bottom: const TabBar(tabs: [Tab(text: 'Đăng nhập'), Tab(text: 'Đăng ký')]),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _loginEmailController, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _loginPassController, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
                const SizedBox(height: 20),
                FilledButton(onPressed: _busy ? null : _handleLogin, child: const Text('Đăng nhập')),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Họ tên')),
                const SizedBox(height: 12),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
                const SizedBox(height: 20),
                FilledButton(onPressed: _busy ? null : _handleRegister, child: const Text('Đăng ký tài khoản')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
