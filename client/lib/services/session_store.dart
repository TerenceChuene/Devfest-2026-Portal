class SessionUser {
  const SessionUser({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String role;
  final String? displayName;
  final String? avatarUrl;

  bool get isAdmin => role == 'admin';

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class SessionStore {
  String? accessToken;
  SessionUser? user;

  bool get isSignedIn => accessToken != null && user != null;

  void setSession({required String token, required SessionUser sessionUser}) {
    accessToken = token;
    user = sessionUser;
  }

  void clear() {
    accessToken = null;
    user = null;
  }
}
