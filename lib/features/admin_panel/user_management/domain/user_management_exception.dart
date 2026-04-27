class UserManagementException implements Exception {
  final String message;

  const UserManagementException(this.message);

  @override
  String toString() => message;
}
