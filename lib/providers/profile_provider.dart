import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Exposes the currently logged-in user's profile to the widget tree.
/// Populated from [AuthProvider.currentUser] after login.
class ProfileProvider with ChangeNotifier {
  UserModel? _user;

  String get name     => _user?.name     ?? 'Guest';
  String get email    => _user?.email    ?? '';
  String get role     => _user?.role.stored ?? 'customer';
  UserModel? get user => _user;

  /// Placeholder avatar — could be replaced with a real image URL later.
  String get imageUrl =>
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD_YaJjte7OxJv3HW71iElLuh7M6qb16-yt4be07UjrhlK9SXbRwqQUsEKlrn2NgWd0BGabJ-h8eqUQg6m7b0m-iUdOXQM6nLZnV7jgLicpIvJ1ezvtEFDodBXRMnXHxb9nkeCifaAMjREt9uIr9prgXK9N_7eelRWtZazcbc9TnjrvkKNkNv5uxEnukpDapk0T6FnYNFITLuyRci3ZWWLhVMI9twaVJnAW6mb9siVQEqGBsm3a38NINsIWMt2gxhhqFweq-CEfiZCZ';

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  void updateDisplayName(String newName) {
    if (_user == null) return;
    _user = UserModel(
      id: _user!.id,
      email: _user!.email,
      name: newName,
      role: _user!.role,
      createdAt: _user!.createdAt,
      lastLoginAt: _user!.lastLoginAt,
      loginCount: _user!.loginCount,
    );
    notifyListeners();
  }

  void clear() {
    _user = null;
    notifyListeners();
  }
}
