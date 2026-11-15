/// Base for errors thrown by repositories, with a message that is safe to
/// show the user. View models catch this one type for every backend.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}
