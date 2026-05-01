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
          if (user.username == sessionUsername) {
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
          if (user.username == _currentUser!.username) {
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
      OwnerApplication? myOwnerApp;
      for (final app in _data.ownerApplications) {
        if (app.username == user.username) {
          myOwnerApp = app;
          break;
        }
      }

      RoleAssignment? myRole;
      for (final role in _data.roleAssignments) {
        if (role.username == user.username) {
          myRole = role;
          break;
        }
      }

      final approvedRestaurants = _data.ownerApplications
          .where((e) => e.status == RequestStatus.approved)
          .map((e) => e.restaurantName)
          .toSet()
          .toList();

      final pendingRequestsForMyRestaurant = myOwnerApp != null && myOwnerApp.status == RequestStatus.approved
          ? _data.staffRoleRequests
              .where((e) => e.restaurantName.toLowerCase() == myOwnerApp!.restaurantName.toLowerCase() && e.status == RequestStatus.pending)
              .toList()
          : <StaffRoleRequest>[];

      String activeRoleLabel = 'Tài khoản thường';
      String activeRestaurant = '';
      if (myOwnerApp != null && myOwnerApp.status == RequestStatus.approved) {
        activeRoleLabel = 'Chủ quán';
        activeRestaurant = myOwnerApp.restaurantName;
      } else if (myRole != null) {
        activeRoleLabel = myRole.role == AccountRole.manager ? 'Quản lý' : 'Nhân viên';
        activeRestaurant = myRole.restaurantName;
      }

      home = HomeShell(
        user: user,
        roleLabel: activeRoleLabel,
        restaurantName: activeRestaurant,
        ownerApplication: myOwnerApp,
        myStaffRequests: _data.staffRoleRequests.where((e) => e.username == user.username).toList(),
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

