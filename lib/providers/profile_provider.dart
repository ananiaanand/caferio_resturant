import 'package:flutter/foundation.dart';

class ProfileProvider with ChangeNotifier {
  String _name = 'Alex Johnston';
  String _email = 'alex.j@caferio.com';
  String _imageUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuD_YaJjte7OxJv3HW71iElLuh7M6qb16-yt4be07UjrhlK9SXbRwqQUsEKlrn2NgWd0BGabJ-h8eqUQg6m7b0m-iUdOXQM6nLZnV7jgLicpIvJ1ezvtEFDodBXRMnXHxb9nkeCifaAMjREt9uIr9prgXK9N_7eelRWtZazcbc9TnjrvkKNkNv5uxEnukpDapk0T6FnYNFITLuyRci3ZWWLhVMI9twaVJnAW6mb9siVQEqGBsm3a38NINsIWMt2gxhhqFweq-CEfiZCZ';

  String get name => _name;
  String get email => _email;
  String get imageUrl => _imageUrl;

  void updateProfile({String? name, String? imageUrl}) {
    if (name != null) _name = name;
    if (imageUrl != null) _imageUrl = imageUrl;
    notifyListeners();
  }
}
