import 'dart:convert';

enum AccountRole { manager, staff }

enum RequestStatus { pending, approved, rejected }

class UserAccount {
  const UserAccount({
    required this.username,
    required this.password,
    required this.displayName,
  });

  final String username;
  final String password;
  final String displayName;

  Map<String, dynamic> toMap() => {
        'username': username,
        'password': password,
        'displayName': displayName,
      };

  static UserAccount fromMap(Map<String, dynamic> map) => UserAccount(
        username: map['username'] as String,
        password: map['password'] as String,
        displayName: map['displayName'] as String,
      );
}

class OwnerApplication {
  const OwnerApplication({
    required this.id,
    required this.username,
    required this.restaurantName,
    required this.proof,
    required this.status,
  });

  final String id;
  final String username;
  final String restaurantName;
  final String proof;
  final RequestStatus status;

  OwnerApplication copyWith({RequestStatus? status}) => OwnerApplication(
        id: id,
        username: username,
        restaurantName: restaurantName,
        proof: proof,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'restaurantName': restaurantName,
        'proof': proof,
        'status': status.name,
      };

  static OwnerApplication fromMap(Map<String, dynamic> map) => OwnerApplication(
        id: map['id'] as String,
        username: map['username'] as String,
        restaurantName: map['restaurantName'] as String,
        proof: map['proof'] as String,
        status: RequestStatus.values.firstWhere((e) => e.name == map['status']),
      );
}

class StaffRoleRequest {
  const StaffRoleRequest({
    required this.id,
    required this.username,
    required this.restaurantName,
    required this.requestedRole,
    required this.note,
    required this.status,
  });

  final String id;
  final String username;
  final String restaurantName;
  final AccountRole requestedRole;
  final String note;
  final RequestStatus status;

  StaffRoleRequest copyWith({RequestStatus? status}) => StaffRoleRequest(
        id: id,
        username: username,
        restaurantName: restaurantName,
        requestedRole: requestedRole,
        note: note,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'restaurantName': restaurantName,
        'requestedRole': requestedRole.name,
        'note': note,
        'status': status.name,
      };

  static StaffRoleRequest fromMap(Map<String, dynamic> map) => StaffRoleRequest(
        id: map['id'] as String,
        username: map['username'] as String,
        restaurantName: map['restaurantName'] as String,
        requestedRole: AccountRole.values.firstWhere((e) => e.name == map['requestedRole']),
        note: map['note'] as String? ?? '',
        status: RequestStatus.values.firstWhere((e) => e.name == map['status']),
      );
}

class RoleAssignment {
  const RoleAssignment({
    required this.username,
    required this.restaurantName,
    required this.role,
  });

  final String username;
  final String restaurantName;
  final AccountRole role;

  Map<String, dynamic> toMap() => {
        'username': username,
        'restaurantName': restaurantName,
        'role': role.name,
      };

  static RoleAssignment fromMap(Map<String, dynamic> map) => RoleAssignment(
        username: map['username'] as String,
        restaurantName: map['restaurantName'] as String,
        role: AccountRole.values.firstWhere((e) => e.name == map['role']),
      );
}

class ApiData {
  const ApiData({
    required this.accounts,
    required this.ownerApplications,
    required this.staffRoleRequests,
    required this.roleAssignments,
  });

  final List<UserAccount> accounts;
  final List<OwnerApplication> ownerApplications;
  final List<StaffRoleRequest> staffRoleRequests;
  final List<RoleAssignment> roleAssignments;

  ApiData copyWith({
    List<UserAccount>? accounts,
    List<OwnerApplication>? ownerApplications,
    List<StaffRoleRequest>? staffRoleRequests,
    List<RoleAssignment>? roleAssignments,
  }) {
    return ApiData(
      accounts: accounts ?? this.accounts,
      ownerApplications: ownerApplications ?? this.ownerApplications,
      staffRoleRequests: staffRoleRequests ?? this.staffRoleRequests,
      roleAssignments: roleAssignments ?? this.roleAssignments,
    );
  }

  Map<String, dynamic> toMap() => {
        'accounts': accounts.map((e) => e.toMap()).toList(),
        'ownerApplications': ownerApplications.map((e) => e.toMap()).toList(),
        'staffRoleRequests': staffRoleRequests.map((e) => e.toMap()).toList(),
        'roleAssignments': roleAssignments.map((e) => e.toMap()).toList(),
      };

  static ApiData fromMap(Map<String, dynamic> map) => ApiData(
        accounts: (map['accounts'] as List<dynamic>? ?? [])
            .map((e) => UserAccount.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        ownerApplications: (map['ownerApplications'] as List<dynamic>? ?? [])
            .map((e) => OwnerApplication.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        staffRoleRequests: (map['staffRoleRequests'] as List<dynamic>? ?? [])
            .map((e) => StaffRoleRequest.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        roleAssignments: (map['roleAssignments'] as List<dynamic>? ?? [])
            .map((e) => RoleAssignment.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static ApiData empty() => const ApiData(
        accounts: [],
        ownerApplications: [],
        staffRoleRequests: [],
        roleAssignments: [],
      );
}

String encodeApiData(ApiData data) => jsonEncode(data.toMap());

ApiData decodeApiData(String raw) => ApiData.fromMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
