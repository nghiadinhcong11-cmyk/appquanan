import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/auth_models.dart';
import '../../billing/presentation/billing_screen.dart';
import '../../menu/presentation/menu_management_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../tables/presentation/tables_screen.dart';
import 'overview_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.displayName,
    required this.username,
    required this.roleLabel,
    required this.restaurantName,
    required this.ownerApplication,
    required this.myStaffRequests,
    required this.discoverableRestaurants,
    required this.onSubmitOwnerApplication,
    required this.onSubmitStaffRequest,
    required this.pendingApprovals,
    required this.onApproveStaff,
    required this.onMockAdminApproveOwner,
    required this.onLogout,
    required this.api,
  });

  final String displayName;
  final String username;
  final String roleLabel;
  final String restaurantName;
  final OwnerApplication? ownerApplication;
  final List<StaffRoleRequest> myStaffRequests;
  final List<String> discoverableRestaurants;
  final Future<String?> Function(String restaurantName, String proof) onSubmitOwnerApplication;
  final Future<String?> Function(String restaurantName, AccountRole role, String note) onSubmitStaffRequest;
  final List<StaffRoleRequest> pendingApprovals;
  final Future<void> Function(String requestId) onApproveStaff;
  final Future<void> Function(String appId) onMockAdminApproveOwner;
  final Future<void> Function() onLogout;
  final HttpApiService api;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  String get _activeRestaurant => widget.restaurantName.isEmpty ? 'Cơ sở demo' : widget.restaurantName;

  List<Widget> get _pages => [
        OverviewScreen(api: widget.api, restaurantName: _activeRestaurant),
        TablesScreen(api: widget.api, restaurantName: _activeRestaurant),
        const OrdersScreen(),
        BillingScreen(api: widget.api, restaurantName: _activeRestaurant),
        MenuManagementScreen(api: widget.api, restaurantName: _activeRestaurant, username: widget.username),
      ];

  List<String> get _titles => const ['Tổng quan', 'Sơ đồ bàn', 'Bán hàng', 'Lịch sử bill', 'Menu'];

  String _statusLabel(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'Chờ duyệt';
      case RequestStatus.approved:
        return 'Đã duyệt';
      case RequestStatus.rejected:
        return 'Từ chối';
    }
  }

  Future<void> _openOwnerRequestForm() async {
    final restaurantController = TextEditingController();
    final proofController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Đăng ký làm chủ quán', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: restaurantController, decoration: const InputDecoration(labelText: 'Tên cơ sở')),
            const SizedBox(height: 12),
            TextField(controller: proofController, maxLines: 2, decoration: const InputDecoration(labelText: 'Minh chứng')),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                final err = await widget.onSubmitOwnerApplication(restaurantController.text.trim(), proofController.text.trim());
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(err ?? 'Đã gửi yêu cầu chủ quán.')));
              },
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStaffRequestForm() async {
    final noteController = TextEditingController();
    final searchController = TextEditingController();
    String? selectedRestaurant;
    AccountRole selectedRole = AccountRole.staff;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final keyword = searchController.text.trim().toLowerCase();
            final filtered = widget.discoverableRestaurants.where((e) => e.toLowerCase().contains(keyword)).toList();
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Yêu cầu vai trò tại cơ sở', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(controller: searchController, decoration: const InputDecoration(labelText: 'Tìm tên cơ sở'), onChanged: (_) => setModalState(() {})),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRestaurant,
                    items: filtered.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) => setModalState(() => selectedRestaurant = value),
                    decoration: const InputDecoration(labelText: 'Chọn cơ sở'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccountRole>(
                    initialValue: selectedRole,
                    items: const [
                      DropdownMenuItem(value: AccountRole.staff, child: Text('Nhân viên')),
                      DropdownMenuItem(value: AccountRole.manager, child: Text('Quản lý')),
                    ],
                    onChanged: (value) => setModalState(() => selectedRole = value ?? AccountRole.staff),
                    decoration: const InputDecoration(labelText: 'Vai trò mong muốn'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Ghi chú')),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: selectedRestaurant == null
                        ? null
                        : () async {
                            final err = await widget.onSubmitStaffRequest(selectedRestaurant!, selectedRole, noteController.text.trim());
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(err ?? 'Đã gửi yêu cầu vai trò.')));
                          },
                    child: const Text('Gửi yêu cầu'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openApproveSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        if (widget.pendingApprovals.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Không có yêu cầu nhân sự nào đang chờ duyệt.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: widget.pendingApprovals.length,
          itemBuilder: (context, index) {
            final request = widget.pendingApprovals[index];
            return Card(
              child: ListTile(
                title: Text(request.username),
                subtitle: Text('${request.requestedRole == AccountRole.manager ? 'Quản lý' : 'Nhân viên'} • ${request.note}'),
                trailing: FilledButton(
                  onPressed: () async {
                    await widget.onApproveStaff(request.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Duyệt'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerStatus = widget.ownerApplication?.status;

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 46, 16, 20),
              decoration: const BoxDecoration(color: Color(0xFFE30D25), borderRadius: BorderRadius.only(bottomRight: Radius.circular(38))),
              child: Row(
                children: [
                  const CircleAvatar(radius: 24, child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(widget.roleLabel, style: const TextStyle(color: Colors.white70)),
                      Text(_activeRestaurant, style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storefront, color: Colors.red),
              title: Text(ownerStatus == null ? 'Đăng ký làm chủ quán' : 'Hồ sơ chủ quán: ${_statusLabel(ownerStatus)}'),
              onTap: ownerStatus == null ? _openOwnerRequestForm : null,
            ),
            if (ownerStatus == RequestStatus.pending)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                title: const Text('Giả lập Admin duyệt hồ sơ'),
                onTap: () => widget.onMockAdminApproveOwner(widget.ownerApplication!.id),
              ),
            ListTile(
              leading: const Icon(Icons.badge, color: Colors.red),
              title: const Text('Yêu cầu vai trò nhân sự/quản lý'),
              onTap: _openStaffRequestForm,
            ),
            if (ownerStatus == RequestStatus.approved)
              ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.red),
                title: Text('Duyệt yêu cầu nhân sự (${widget.pendingApprovals.length})'),
                onTap: _openApproveSheet,
              ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              onTap: widget.onLogout,
            ),
            const Spacer(),
            const Padding(padding: EdgeInsets.only(bottom: 18), child: Text('© 2026 - Restaurant POS v0.1.0')),
          ],
        ),
      ),
      appBar: AppBar(backgroundColor: const Color(0xFFE30D25), foregroundColor: Colors.white, title: Text(_titles[_index])),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Sơ đồ'),
          NavigationDestination(icon: Icon(Icons.receipt), label: 'Bán hàng'),
          NavigationDestination(icon: Icon(Icons.request_page), label: 'Bill'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Menu'),
        ],
      ),
    );
  }
}

