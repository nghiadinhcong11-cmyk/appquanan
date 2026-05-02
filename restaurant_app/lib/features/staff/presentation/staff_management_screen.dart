import 'package:flutter/material.dart';
import '../../../core/api/http_api_service.dart';
import '../../../shared/models/auth_models.dart';

class StaffManagementScreen extends StatefulWidget {
  final HttpApiService api;
  final String restaurantName;
  final String restaurantId;
  final List<StaffRoleRequest> pendingRequests;
  final Future<void> Function(String requestId) onApprove;

  const StaffManagementScreen({
    super.key,
    required this.api,
    required this.restaurantName,
    required this.restaurantId,
    required this.pendingRequests,
    required this.onApprove,
  });

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<UserAccount> _allStaff = [];
  List<UserAccount> _filteredStaff = [];
  bool _loading = true;
  String _searchQuery = '';
  AccountRole? _filterRole;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    if (widget.restaurantId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await widget.api.getStaff(widget.restaurantId);
      setState(() {
        _allStaff = list;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading staff: $e');
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredStaff = _allStaff.where((s) {
        final matchesSearch = s.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.username.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesRole = _filterRole == null || s.currentRestaurantRole == _filterRole;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _updateRole(UserAccount user, AccountRole newRole) async {
    if (user.id == null) return;
    try {
      await widget.api.updateStaffRole(widget.restaurantId, user.id!, newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật vai trò.')));
        _loadStaff();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _removeStaff(UserAccount user) async {
    if (user.id == null) return;
    try {
      await widget.api.removeStaff(widget.restaurantId, user.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa nhân viên.')));
        _loadStaff();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  String _roleToVN(AccountRole? role) {
    switch (role) {
      case AccountRole.owner: return 'Chủ quán';
      case AccountRole.manager: return 'Quản lý';
      case AccountRole.cashier: return 'Thu ngân';
      case AccountRole.waiter: return 'Phục vụ';
      case AccountRole.kitchen: return 'Đầu bếp';
      default: return 'Nhân viên';
    }
  }

  void _showEditRoleDialog(UserAccount user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đổi vai trò cho ${user.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AccountRole.manager,
            AccountRole.cashier,
            AccountRole.waiter,
            AccountRole.kitchen
          ].map((r) => ListTile(
            title: Text(_roleToVN(r)),
            onTap: () {
              Navigator.pop(ctx);
              _updateRole(user, r);
            },
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhân sự'),
        backgroundColor: const Color(0xFFE30D25),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilter();
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm tên hoặc username...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tất cả'),
                        selected: _filterRole == null,
                        onSelected: (val) {
                          _filterRole = null;
                          _applyFilter();
                        },
                      ),
                      const SizedBox(width: 8),
                      ...[AccountRole.manager, AccountRole.cashier, AccountRole.waiter, AccountRole.kitchen].map((r) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_roleToVN(r)),
                          selected: _filterRole == r,
                          onSelected: (val) {
                            _filterRole = val ? r : null;
                            _applyFilter();
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadStaff,
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (widget.pendingRequests.isNotEmpty && _filterRole == null && _searchQuery.isEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.pending_actions, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text('Yêu cầu đang chờ (${widget.pendingRequests.length})',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...widget.pendingRequests.map((req) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.orange.shade50,
                          child: ListTile(
                            title: Text(req.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Xin vào vị trí: ${_roleToVN(req.requestedRole)}'),
                            trailing: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                              onPressed: () async {
                                await widget.onApprove(req.id);
                                _loadStaff();
                              },
                              child: const Text('Duyệt'),
                            ),
                          ),
                        )),
                        const Divider(height: 32),
                      ],
                      Row(
                        children: [
                          const Icon(Icons.people, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text('Nhân viên (${_filteredStaff.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_filteredStaff.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text('Không tìm thấy nhân viên nào.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ),
                      ..._filteredStaff.map((s) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: s.currentRestaurantRole == AccountRole.owner ? Colors.red.shade100 : Colors.blue.shade100,
                            child: Icon(
                              s.currentRestaurantRole == AccountRole.owner ? Icons.stars : Icons.person,
                              color: s.currentRestaurantRole == AccountRole.owner ? Colors.red : Colors.blue
                            ),
                          ),
                          title: Text(s.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${s.username} • ${_roleToVN(s.currentRestaurantRole)}'),
                          trailing: s.currentRestaurantRole == AccountRole.owner
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    _showEditRoleDialog(s);
                                  } else if (val == 'remove') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Xác nhận'),
                                        content: Text('Xóa ${s.displayName} khỏi cơ sở?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
                                        ],
                                      )
                                    );
                                    if (confirm == true) {
                                      _removeStaff(s);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Đổi vai trò')),
                                  const PopupMenuItem(value: 'remove', child: Text('Xóa nhân viên', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                        ),
                      )),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
