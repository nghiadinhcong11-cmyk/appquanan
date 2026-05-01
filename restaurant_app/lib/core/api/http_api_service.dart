import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/models/auth_models.dart';
import '../../shared/models/business_models.dart';
import '../storage/auth_storage.dart';

class HttpApiService {
  HttpApiService(this._storage, {String? baseUrl})
      : baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://appquanan.onrender.com');

  final AuthStorage _storage;
  final String baseUrl;

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<Map<String, String>> _headers() async {
    final token = await _storage.loadToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _tryRefreshToken() async {
    final refresh = await _storage.loadRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await http.post(
        _u('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) return false;
      await _storage.saveToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      var res = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 12));
      if (res.statusCode == 401 && await _tryRefreshToken()) {
        res = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 12));
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
      return data;
    } catch (e) {
      throw Exception('GET $uri thất bại: $e');
    }
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final uri = _u(path);
    try {
      var res = await http.post(uri, headers: await _headers(), body: jsonEncode(body)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 401 && await _tryRefreshToken()) {
        res = await http.post(uri, headers: await _headers(), body: jsonEncode(body)).timeout(const Duration(seconds: 12));
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
      return data;
    } catch (e) {
      throw Exception('POST $uri thất bại: $e');
    }
  }

  Future<ApiData> loadData() async {
    final data = await _getJson(_u('/bootstrap'));
    final accounts = (data['accounts'] as List<dynamic>)
        .map((e) => UserAccount.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final ownerApplications = (data['ownerApplications'] as List<dynamic>)
        .map((e) => OwnerApplication.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final staffRoleRequests = (data['staffRoleRequests'] as List<dynamic>)
        .map((e) => StaffRoleRequest.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final roleAssignments = (data['roleAssignments'] as List<dynamic>)
        .map((e) => RoleAssignment.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return ApiData(accounts: accounts, ownerApplications: ownerApplications, staffRoleRequests: staffRoleRequests, roleAssignments: roleAssignments);
  }

  Future<UserAccount?> login(String username, String password) async {
    try {
      final data = await _postJson('/auth/login', {'username': username, 'password': password});
      await _storage.saveSessionUsername(username);
      final token = data['token'] as String?;
      final refresh = data['refreshToken'] as String?;
      if (token != null) await _storage.saveToken(token);
      if (refresh != null) await _storage.saveRefreshToken(refresh);
      final userMap = Map<String, dynamic>.from(data['user'] as Map);
      return UserAccount(username: userMap['username'] as String, password: '', displayName: userMap['displayName'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<String?> register(String displayName, String username, String password) async {
    try {
      final data = await _postJson('/auth/register', {'displayName': displayName, 'username': username, 'password': password});
      final token = data['token'] as String?;
      final refresh = data['refreshToken'] as String?;
      if (token != null) await _storage.saveToken(token);
      if (refresh != null) await _storage.saveRefreshToken(refresh);
      await _storage.saveSessionUsername(username);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> submitOwnerApplication(String username, String restaurantName, String proof) async {
    try {
      await _postJson('/owner-applications', {'username': username, 'restaurantName': restaurantName, 'proof': proof});
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> submitStaffRequest({required String username, required String restaurantName, required AccountRole role, required String note}) async {
    try {
      await _postJson('/staff-requests', {'username': username, 'restaurantName': restaurantName, 'requestedRole': role.name, 'note': note});
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> approveOwnerApplication(String appId) async => _postJson('/owner-applications/$appId/approve', {});
  Future<void> approveStaffRequest(String requestId) async => _postJson('/staff-requests/$requestId/approve', {});

  Future<void> addMenuItem({required String restaurantName, required String name, required int price, required String createdBy}) async {
    await _postJson('/menu', {'restaurantName': restaurantName, 'name': name, 'price': price, 'createdBy': createdBy});
  }

  Future<List<MenuItemRecord>> getMenuItems(String restaurantName) async {
    final data = await _getJson(_u('/menu', {'restaurantName': restaurantName}));
    return (data['items'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => MenuItemRecord(id: int.parse(m['id'].toString()), name: m['name'] as String, price: (m['price'] as num).toInt(), createdBy: m['createdBy'] as String))
        .toList();
  }

  Future<void> addBill({required String restaurantName, required String tableName, required int total, required int itemCount}) async {
    await _postJson('/bills', {'restaurantName': restaurantName, 'tableName': tableName, 'total': total, 'itemCount': itemCount});
  }

  Future<List<BillRecord>> getBills(String restaurantName) async {
    final data = await _getJson(_u('/bills', {'restaurantName': restaurantName}));
    return (data['bills'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => BillRecord(id: int.parse(m['id'].toString()), tableName: m['tableName'] as String, total: (m['total'] as num).toInt(), itemCount: (m['itemCount'] as num).toInt(), createdAt: DateTime.parse(m['createdAt'] as String)))
        .toList();
  }

  Future<TodayStats> getTodayStats(String restaurantName) async {
    final data = await _getJson(_u('/stats/today', {'restaurantName': restaurantName}));
    return TodayStats(billCount: (data['billCount'] as num).toInt(), revenue: (data['revenue'] as num).toInt());
  }

  Future<void> logout() async {
    final refresh = await _storage.loadRefreshToken();
    if (refresh != null) {
      try {
        await _postJson('/auth/logout', {'refreshToken': refresh});
      } catch (_) {}
    }
    await _storage.clearSession();
  }
}
