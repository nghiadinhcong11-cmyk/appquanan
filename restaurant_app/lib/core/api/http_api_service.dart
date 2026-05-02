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

  Future<Map<String, String>> _headers({String? restaurantId}) async {
    final token = await _storage.loadToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (restaurantId != null) 'x-restaurant-id': restaurantId,
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

  Future<Map<String, dynamic>> _getJson(Uri uri, {String? restaurantId}) async {
    try {
      var res = await http.get(uri, headers: await _headers(restaurantId: restaurantId)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 401 && await _tryRefreshToken()) {
        res = await http.get(uri, headers: await _headers(restaurantId: restaurantId)).timeout(const Duration(seconds: 12));
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
      return data;
    } catch (e) {
      throw Exception('GET $uri thất bại: $e');
    }
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body, {String? restaurantId}) async {
    final uri = _u(path);
    try {
      var res = await http.post(uri, headers: await _headers(restaurantId: restaurantId), body: jsonEncode(body)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 401 && await _tryRefreshToken()) {
        res = await http.post(uri, headers: await _headers(restaurantId: restaurantId), body: jsonEncode(body)).timeout(const Duration(seconds: 12));
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
      return UserAccount.fromMap(Map<String, dynamic>.from(data['user'] as Map));
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

  Future<void> addMenuItem({
    required String restaurantId,
    required String name,
    required int price,
    String description = '',
    String imageUrl = '',
  }) async {
    await _postJson('/menu', {
      'restaurantId': restaurantId,
      'name': name,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
    }, restaurantId: restaurantId);
  }

  Future<List<MenuItemRecord>> getMenuItems({required String restaurantId}) async {
    final params = {'restaurantId': restaurantId};
    final data = await _getJson(_u('/menu', params), restaurantId: restaurantId);
    return (data['items'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => MenuItemRecord(
              id: int.parse(m['id'].toString()),
              name: m['name'] as String,
              price: (m['price'] as num).toInt(),
              description: m['description'] as String? ?? '',
              imageUrl: m['imageUrl'] as String? ?? '',
              createdBy: m['createdBy'] as String,
            ))
        .toList();
  }

  Future<void> addBill({
    required String restaurantId,
    required String tableName,
    required int total,
    required int itemCount,
    String? tableId,
  }) async {
    await _postJson('/bills', {
      'restaurantId': restaurantId,
      'tableName': tableName,
      'total': total,
      'itemCount': itemCount,
      'tableId': tableId,
    }, restaurantId: restaurantId);
  }

  Future<List<BillRecord>> getBills({required String restaurantId}) async {
    final data = await _getJson(_u('/bills', {'restaurantId': restaurantId}), restaurantId: restaurantId);
    return (data['bills'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => BillRecord(id: int.parse(m['id'].toString()), tableName: m['tableName'] as String, total: (m['total'] as num).toInt(), itemCount: (m['itemCount'] as num).toInt(), createdAt: DateTime.parse(m['createdAt'] as String)))
        .toList();
  }

  Future<TodayStats> getTodayStats({required String restaurantId}) async {
    final data = await _getJson(_u('/stats/today', {'restaurantId': restaurantId}), restaurantId: restaurantId);
    return TodayStats(
      billCount: (data['billCount'] as num).toInt(),
      revenue: (data['revenue'] as num).toInt(),
      hourlyRevenue: (data['hourlyRevenue'] as List? ?? [])
          .map((e) => HourlyRevenue(
                hour: (e['hour'] as num).toInt(),
                total: (e['total'] as num).toInt(),
              ))
          .toList(),
      popularItems: (data['popularItems'] as List? ?? [])
          .map((e) => PopularItem(
                name: e['name'] as String,
                quantity: (e['quantity'] as num).toInt(),
              ))
          .toList(),
    );
  }

  Future<List<UserAccount>> getStaff(String restaurantId) async {
    final data = await _getJson(_u('/restaurants/staff', {'restaurantId': restaurantId}), restaurantId: restaurantId);
    return (data['staff'] as List<dynamic>)
        .map((e) => UserAccount.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateStaffRole(String restaurantId, String userId, AccountRole role) async {
    await _postJson('/restaurants/staff/update-role', {
      'restaurantId': restaurantId,
      'userId': userId,
      'role': role.name,
    }, restaurantId: restaurantId);
  }

  Future<void> removeStaff(String restaurantId, String userId) async {
    final uri = _u('/restaurants/staff', {'restaurantId': restaurantId, 'userId': userId});
    try {
      var res = await http.delete(uri, headers: await _headers(restaurantId: restaurantId)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 401 && await _tryRefreshToken()) {
        res = await http.delete(uri, headers: await _headers(restaurantId: restaurantId)).timeout(const Duration(seconds: 12));
      }
      if (res.statusCode >= 400) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('DELETE $uri thất bại: $e');
    }
  }

  Future<List<DiningTable>> getTables(String restaurantId) async {
    final data = await _getJson(_u('/restaurants/tables', {'restaurantId': restaurantId}), restaurantId: restaurantId);
    return (data['tables'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => DiningTable.fromMap(m))
        .toList();
  }

  Future<void> addTable(String restaurantId, String tableName) async {
    await _postJson('/restaurants/tables', {'restaurantId': restaurantId, 'name': tableName}, restaurantId: restaurantId);
  }

  Future<void> updateTableStatus(String restaurantId, String tableId, TableState state) async {
    String status = 'empty';
    if (state == TableState.serving) status = 'serving';
    if (state == TableState.waitingPayment) status = 'waiting_payment';

    final uri = _u('/restaurants/tables/$tableId/status');
    try {
      var res = await http.patch(uri,
        headers: await _headers(restaurantId: restaurantId),
        body: jsonEncode({'status': status})
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 401 && await _tryRefreshToken()) {
        res = await http.patch(uri,
          headers: await _headers(restaurantId: restaurantId),
          body: jsonEncode({'status': status})
        ).timeout(const Duration(seconds: 12));
      }

      if (res.statusCode >= 400) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('PATCH $uri thất bại: $e');
    }
  }

  Future<List<KitchenTicket>> getOrderItems(String restaurantId, {String? status, String? tableId}) async {
    final params = {'restaurantId': restaurantId};
    if (status != null) params['status'] = status;
    if (tableId != null) params['tableId'] = tableId;
    final data = await _getJson(_u('/restaurants/order-items', params), restaurantId: restaurantId);
    return (data['items'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => KitchenTicket(
              id: m['id']?.toString(),
              table: m['table_name'] as String? ?? 'N/A',
              item: m['item_name'] as String? ?? 'N/A',
              qty: (m['quantity'] as num).toInt(),
              status: m['status'] as String,
              note: m['note'] as String? ?? '',
              price: (m['price'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<String> addOrderItem({
    required String restaurantId,
    required String tableId,
    required String menuItemId,
    required int quantity,
    String note = '',
  }) async {
    final data = await _postJson('/restaurants/order-items', {
      'restaurantId': restaurantId,
      'tableId': tableId,
      'menuItemId': menuItemId,
      'quantity': quantity,
      'note': note,
    }, restaurantId: restaurantId);
    return data['id'].toString();
  }

  Future<void> updateOrderItemStatus(String restaurantId, String itemId, String status) async {
    final uri = _u('/restaurants/order-items/$itemId/status');
    try {
      var res = await http.patch(uri,
        headers: await _headers(restaurantId: restaurantId),
        body: jsonEncode({'status': status})
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 401 && await _tryRefreshToken()) {
        res = await http.patch(uri,
          headers: await _headers(restaurantId: restaurantId),
          body: jsonEncode({'status': status})
        ).timeout(const Duration(seconds: 12));
      }

      if (res.statusCode >= 400) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('PATCH $uri thất bại: $e');
    }
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
