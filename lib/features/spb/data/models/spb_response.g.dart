// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spb_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpbResponse _$SpbResponseFromJson(Map<String, dynamic> json) => SpbResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => SpbModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SpbResponseToJson(SpbResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };
