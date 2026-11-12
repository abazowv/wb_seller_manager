import 'package:equatable/equatable.dart';

import 'json.dart';

class User extends Equatable {
  const User({required this.id, required this.name, required this.email, this.createdAt});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: toInt(json['id']),
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        createdAt: toStringOrNull(json['created_at']),
      );

  final int id;
  final String name;
  final String email;
  final String? createdAt;

  @override
  List<Object?> get props => [id, name, email, createdAt];
}
