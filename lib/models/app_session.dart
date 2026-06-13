enum UserRole {
  analyst,
  organizationAdmin,
  platformAdmin,
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.analyst => 'Analyst',
        UserRole.organizationAdmin => 'Organization Admin',
        UserRole.platformAdmin => 'Platform Admin',
      };

  bool get canAccessPlatformAdmin => this == UserRole.platformAdmin;
}

class AppSession {
  const AppSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.organizationId,
    required this.organizationName,
    required this.role,
  });

  final String userId;
  final String email;
  final String displayName;
  final String organizationId;
  final String organizationName;
  final UserRole role;
}
