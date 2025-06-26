import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String Id;
  final String UserName;
  final String Nama;

  const User({required this.Id, required this.UserName, required this.Nama});

  User copyWith({String? Id, String? UserName, String? Nama}) {
    return User(
      Id: Id ?? this.Id,
      UserName: UserName ?? this.UserName,
      Nama: Nama ?? this.Nama,
    );
  }

  @override
  List<Object?> get props => [Id, UserName, Nama];
}
