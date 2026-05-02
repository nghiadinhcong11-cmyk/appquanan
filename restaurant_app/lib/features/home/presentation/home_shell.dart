import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/auth_models.dart';
import '../../billing/presentation/billing_screen.dart';
import '../../menu/presentation/menu_management_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../tables/presentation/tables_screen.dart';
import '../../staff/presentation/staff_management_screen.dart';
import 'overview_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.user,
    required this.roleLabel,
    required this.restaurantName,
    required this.restaurantId,
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
    this.allOwnerApplications = const [],
  });

  final UserAccount user;
  final String roleLabel;
  final String restaurantName;
  final String restaurantId;
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
  final List<OwnerApplication> allOwnerApplications;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  String get _activeRestaurant => widget.restaurantName.isEmpty ? 'Cơ sở demo' : widget.restaurantName;

  List<({Widget page, String title, NavigationDestination nav})> get _filteredTabs {
    final tabs = [
      (
        page: OverviewScreen(
          api: widget.api,
          restaurantName: _activeRestaurant,
          restaurantId: widget.restaurantId,
          user: widget.user,
        ),
        title: 'Tổng quan',
        nav: const NavigationDestination(icon: Icon(Icons.home), label: 'Tổng quan'),
      ),
      (
        page: TablesScreen(
          api: widget.api,
          restaurantName: _activeRestaurant,
          restaurantId: widget.restaurantId,
          user: widget.user,
        ),
        title: 'Sơ đồ',
        nav: const NavigationDestination(icon: Icon(Icons.map), label: 'Sơ đồ'),
      ),
      (
        page: OrdersScreen(api: widget.api, restaurantId: widget.restaurantId),
        title: 'Bán hàng',
        nav: const NavigationDestination(icon: Icon(Icons.receipt), label: 'Bán hàng'),
      ),
    ];

    if (widget.user.canSeeBills) {
      tabs.add((
        page: BillingScreen(
          api: widget.api,
          restaurantName: _activeRestaurant,
          restaurantId: widget.restaurantId,
        ),
        title: 'Lịch sử bill',
        nav: const NavigationDestination(icon: Icon(Icons.request_page), label: 'Bill'),
      ));
    }

    if (widget.user.canManageInventory) {
      tabs.add((
        page: MenuManagementScreen(
          api: widget.api,
          restaurantName: _activeRestaurant,
          restaurantId: widget.restaurantId,
          username: widget.user.username,
        ),
        title: 'Menu',
        nav: const NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Menu'),
      ));
    }

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final ownerStatus = widget.ownerApplication?.status;
    final user = widget.user;
    final tabs = _filteredTabs;

    // Ensure index doesn't go out of bounds if permissions change
    if (_index >= tabs.length) {
      _index = 0;
    }

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
                      Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(widget.roleLabel, style: const TextStyle(color: Colors.white70)),
                      Text(_activeRestaurant, style: const TextStyle(color: Colors.white70)),
                      if (user.isAdmin) const Text('VAI TRÒ: ADMIN HỆ THỐNG', style: TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              ),
            ),
            if (user.isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                title: const Text('ADMIN: Duyệt chủ quán', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: _openAdminApproveSheet,
              ),
            const Divider(),
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
            if (user.canManageStaff) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.people, color: Colors.red),
                title: const Text('Quản lý nhân sự'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaffManagementScreen(
                        api: widget.api,
                        restaurantName: widget.restaurantName,
                        restaurantId: widget.restaurantId,
                        pendingRequests: widget.pendingApprovals,
                        onApprove: widget.onApproveStaff,
                      ),
                    ),
                  );
                },
              ),
            ],
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
      appBar: AppBar(backgroundColor: const Color(0xFFE30D25), foregroundColor: Colors.white, title: Text(tabs[_index].title)),
      body: tabs[_index].page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: tabs.map((t) => t.nav).toList(),
      ),
    );
  }

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
    AccountRole selectedRole = AccountRole.waiter;

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
                    value: selectedRestaurant,
                    items: filtered.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) => setModalState(() => selectedRestaurant = value),
                    decoration: const InputDecoration(labelText: 'Chọn cơ sở'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccountRole>(
                    value: selectedRole,
                    items: const [
                      DropdownMenuItem(value: AccountRole.waiter, child: Text('Phục vụ (Waiter)')),
                      DropdownMenuItem(value: AccountRole.cashier, child: Text('Thu ngân (Cashier)')),
                      DropdownMenuItem(value: AccountRole.kitchen, child: Text('Bếp (Kitchen)')),
                      DropdownMenuItem(value: AccountRole.manager, child: Text('Quản lý (Manager)')),
                    ],
                    onChanged: (value) => setModalState(() => selectedRole = value ?? AccountRole.waiter),
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
      isScrollControlled: true,
      builder: (context) {
        if (widget.pendingApprovals.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Không có yêu cầu nhân sự nào đang chờ.'),
          );
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text('Phê duyệt nhân sự', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.pendingApprovals.length,
                  itemBuilder: (context, index) {
                    final req = widget.pendingApprovals[index];
                    return Card(
                      child: ListTile(
                        title: Text('User: ${req.username}'),
                        subtitle: Text('Vai trò: ${req.requestedRole.name}\nGhi chú: ${req.note}'),
                        trailing: FilledButton(
                          onPressed: () async {
                            await widget.onApproveStaff(req.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Duyệt'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAdminApproveSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final pendingApps = widget.allOwnerApplications.where((e) => e.status == RequestStatus.pending).toList();
        if (pendingApps.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Không có đơn đăng ký chủ quán nào đang chờ.'),
          );
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text('Phê duyệt chủ quán (Admin)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: pendingApps.length,
                  itemBuilder: (context, index) {
                    final app = pendingApps[index];
                    return Card(
                      child: ListTile(
                        title: Text('Cơ sở: ${app.restaurantName}'),
                        subtitle: Text('Người đăng ký: ${app.username}\nMinh chứng: ${app.proof}'),
                        trailing: FilledButton(
                          onPressed: () async {
                            await widget.onMockAdminApproveOwner(app.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Duyệt'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

