import 'package:equatable/equatable.dart';

class AuthTokens with EquatableMixin {
  final String token;

  const AuthTokens({required this.token});

  @override
  List<Object> get props => [token];
}
