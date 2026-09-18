/// A persisted auth session.
class AppSession {
  AppSession({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}