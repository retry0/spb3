import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/user.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends User {
  const UserModel({
    required super.Id,
    required super.UserName,
    required super.Nama,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  factory UserModel.fromDatabase(Map<String, dynamic> data) {
    return UserModel(
      Id: data['Id'] as String,
      UserName: data['UserName'] as String,
      Nama: data['Nama'] as String,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {'id': Id, 'userName': UserName, 'Nama': Nama};
  }
}
