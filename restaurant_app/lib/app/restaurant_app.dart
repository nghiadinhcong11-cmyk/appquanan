import 'package:flutter/material.dart';

import '../core/api/http_api_service.dart';
import '../core/storage/auth_storage.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/customer_login_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../shared/models/auth_models.dart';

class RestaurantApp extends StatefulWidget {
  const RestaurantApp({super.key});

  @override
  State<RestaurantApp> createState() => _RestaurantAppState();
}

class _RestaurantAppState extends State<RestaurantApp> {
  final _storage = AuthStorage();
  late final HttpApiService _api = HttpApiService(_storage);

  ApiData _data = ApiData.empty();
  UserAccount? _currentUser;
  bool _loading = true;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final data = await _api.loadData().timeout(const Duration(seconds: 20));
      final sessionUsername = await _storage.loadSessionUsername().timeout(const Duration(seconds: 5));

      UserAccount? current;
      if (sessionUsername != null) {
        for (final user in data.accounts) {
          if (user.username.toLowerCase() == sessionUsername.toLowerCase()) {
            current = user;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _data = data;
        _currentUser = current;
        _loading = false;
        _startupError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _startupError = e.toString();
      });
    }
  }

  Future<void> _refreshData() async {
    final data = await _api.loadData();
    if (!mounted) return;
    setState(() {
      _data = data;
      if (_currentUser != null) {
        for (final user in data.accounts) {
          if (user.username.toLowerCase() == _currentUser!.username.toLowerCase()) {
            _currentUser = user;
            break;
          }
        }
      }
    });
  }

  Future<String?> _login(String username, String password) async {
    final user = await _api.login(username, password);
    if (user == null) return 'Sai tên đăng nhập hoặc mật khẩu';
    await _refreshData();
    if (!mounted) return null;
    setState(() => _currentUser = user);
    return null;
  }

  Future<String?> _register(String displayName, String username, String password) async {
    final err = await _api.register(displayName, username, password);
    await _refreshData();
    return err;
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() => _currentUser = null);
  }

  Future<String?> _submitOwnerApplication(String restaurantName, String proof) async {
    final user = _currentUser;
    if (user == null) return 'Chưa đăng nhập';
    final err = await _api.submitOwnerApplication(user.username, restaurantName, proof);
    await _refreshData();
    return err;
  }

  Future<String?> _submitStaffRequest(String restaurantName, AccountRole role, String note) async {
    final user = _currentUser;
    if (user == null) return 'Chưa đăng nhập';
    final err = await _api.submitStaffRequest(
      username: user.username,
      restaurantName: restaurantName,
      role: role,
      note: note,
    );
    await _refreshData();
    return err;
  }

  Future<void> _approveStaffRequest(String requestId) async {
    await _api.approveStaffRequest(requestId);
    await _refreshData();
  }

  Future<void> _mockAdminApproveOwner(String appId) async {
    await _api.approveOwnerApplication(appId);
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không thể khởi tạo dữ liệu', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(_startupError!, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: () {
                    setState(() {
                      _loading = true;
                      _startupError = null;
                    });
                    _restore();
                  }, child: const Text('Thử lại')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final user = _currentUser;

    Widget home;
    if (user == null) {
      home = AuthScreen(onLogin: _login, onRegister: _register);
    } else {
      // 1. Tìm đơn đăng ký chủ quán của tôi
      OwnerApplication? myOwnerApp;
      try {
        myOwnerApp = _data.ownerApplications.firstWhere(
          (app) => app.username.trim().toLowerCase() == user.username.trim().toLowerCase()
        );
      } catch (_) {
        myOwnerApp = null;
      }

      // 2. Tìm vai trò nhân viên của tôi
      RoleAssignment? myRole;
      try {
        myRole = _data.roleAssignments.firstWhere(
          (ra) => ra.username.trim().toLowerCase() == user.username.trim().toLowerCase()
        );
      } catch (_) {
        myRole = null;
      }

      final approvedRestaurants = _data.ownerApplications
          .where((e) => e.status == RequestStatus.approved)
          .map((e) => e.restaurantName)
          .toSet()
          .toList();

      AccountRole? effectiveRole;
      String activeRestaurant = '';
      String activeRestaurantId = '';
      String activeRoleLabel = 'Tài khoản thường';

      // Ưu tiên quyền Chủ quán trước
      if (myOwnerApp != null && myOwnerApp.status == RequestStatus.approved) {
        effectiveRole = AccountRole.owner;
        activeRestaurant = myOwnerApp.restaurantName;
        activeRoleLabel = 'Chủ quán';
        // Lấy ID từ roleAssignments hoặc một nguồn khác.
        // May mắn là roleAssignments chứa cả ID.
        try {
          activeRestaurantId = _data.roleAssignments.firstWhere(
            (ra) => ra.restaurantName.toLowerCase() == activeRestaurant.toLowerCase()
          ).restaurantId;
        } catch (_) {}
      } else if (myRole != null) {
        effectiveRole = myRole.role;
        activeRestaurant = myRole.restaurantName;
        activeRestaurantId = myRole.restaurantId;
        switch (effectiveRole) {
          case AccountRole.manager: activeRoleLabel = 'Quản lý'; break;
          case AccountRole.cashier: activeRoleLabel = 'Thu ngân'; break;
          case AccountRole.waiter: activeRoleLabel = 'Phục vụ'; break;
          case AccountRole.kitchen: activeRoleLabel = 'Đầu bếp'; break;
          default: activeRoleLabel = 'Nhân viên';
        }
      }

      // TẠO ĐỐI TƯỢNG USER MỚI CÓ KÈM VAI TRÒ ĐỂ GATING UI
      final userWithRole = UserAccount(
        username: user.username,
        password: user.password,
        displayName: user.displayName,
        systemRole: user.systemRole,
        currentRestaurantRole: effectiveRole,
      );

      final pendingRequestsForMyRestaurant = activeRestaurant.isNotEmpty &&
          (effectiveRole == AccountRole.owner || effectiveRole == AccountRole.manager)
          ? _data.staffRoleRequests
              .where((e) => e.restaurantName.toLowerCase() == activeRestaurant.toLowerCase() && e.status == RequestStatus.pending)
              .toList()
          : <StaffRoleRequest>[];

      home = HomeShell(
        user: userWithRole,
        roleLabel: activeRoleLabel,
        restaurantName: activeRestaurant,
        restaurantId: activeRestaurantId,
        ownerApplication: myOwnerApp,
        myStaffRequests: _data.staffRoleRequests
            .where((e) => e.username.trim().toLowerCase() == user.username.trim().toLowerCase())
            .toList(),
        discoverableRestaurants: approvedRestaurants,
        onSubmitOwnerApplication: _submitOwnerApplication,
        onSubmitStaffRequest: _submitStaffRequest,
        pendingApprovals: pendingRequestsForMyRestaurant,
        onApproveStaff: _approveStaffRequest,
        onMockAdminApproveOwner: _mockAdminApproveOwner,
        onLogout: _logout,
        api: _api,
        allOwnerApplications: _data.ownerApplications,
      );
    }

    return MaterialApp(
      title: 'Quán Ăn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    );
  }
}

