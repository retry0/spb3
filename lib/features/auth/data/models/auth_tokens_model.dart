import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/auth_tokens.dart';

part 'auth_tokens_model.g.dart';

@JsonSerializable()
class AuthTokensModel extends AuthTokens {
  const AuthTokensModel({required super.token});

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    // Handle different API response formats
    if (json.containsKey('token')) {
      return AuthTokensModel(token: json['token'] as String);
    } else if (json.containsKey('accessToken')) {
      return AuthTokensModel(token: json['accessToken'] as String);
    } else {
      // Try to find any token-like field as fallback
      final possibleTokenKeys = [
        'access_token',
        'id_token',
        'jwt',
        'auth_token',
      ];
      for (final key in possibleTokenKeys) {
        if (json.containsKey(key) && json[key] is String) {
          return AuthTokensModel(token: json[key] as String);
        }
      }
      throw Exception('No token field found in response');
    }
  }

  Map<String, dynamic> toJson() => {'token': token};
}
