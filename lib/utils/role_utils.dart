class RoleUtils {
  // Role constants
  static const String userRole = 'user';
  static const String scoringRole = 'scoring';
  static const String ownerRole = 'owner';

  // Check if user has read-only access
  static bool isUser(String role) {
    return role == userRole;
  }

  // Check if user can score
  static bool canScore(String role) {
    return role == scoringRole || role == ownerRole;
  }

  // Check if user is owner/admin
  static bool isOwner(String role) {
    return role == ownerRole;
  }

  // Check if user can manage other users
  static bool canManageUsers(String role) {
    return role == ownerRole;
  }

  // Check if user can access admin features
  static bool canAccessAdmin(String role) {
    return role == ownerRole;
  }

  // Get role display name
  static String getRoleDisplayName(String role) {
    switch (role) {
      case userRole:
        return 'User';
      case scoringRole:
        return 'Scoring Official';
      case ownerRole:
        return 'Owner/Admin';
      default:
        return 'Unknown';
    }
  }

  // Get role description
  static String getRoleDescription(String role) {
    switch (role) {
      case userRole:
        return 'Read-only access. Can create teams and view schedules.';
      case scoringRole:
        return 'Can score games and manage match results.';
      case ownerRole:
        return 'Full access. Can manage users, teams, and all app features.';
      default:
        return 'Unknown role';
    }
  }

  // Get available roles for assignment (only owners can assign roles)
  static List<String> getAssignableRoles(String currentUserRole) {
    if (currentUserRole == ownerRole) {
      return [userRole, scoringRole, ownerRole];
    }
    return [];
  }
}
