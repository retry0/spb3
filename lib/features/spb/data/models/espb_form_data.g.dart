// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'espb_form_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EspbFormData _$EspbFormDataFromJson(Map<String, dynamic> json) => EspbFormData(
      id: json['id'] as String,
      noSpb: json['noSpb'] as String,
      formType: $enumDecode(_$EspbFormTypeEnumMap, json['formType']),
      status: json['status'] as String,
      alasan: json['alasan'] as String?,
      isDriverOrVehicleChanged: json['isDriverOrVehicleChanged'] as bool?,
      latitude: json['latitude'] as String,
      longitude: json['longitude'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      syncedAt: json['syncedAt'] == null
          ? null
          : DateTime.parse(json['syncedAt'] as String),
      isSynced: json['isSynced'] as bool? ?? false,
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );

Map<String, dynamic> _$EspbFormDataToJson(EspbFormData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'noSpb': instance.noSpb,
      'formType': _$EspbFormTypeEnumMap[instance.formType]!,
      'status': instance.status,
      'alasan': instance.alasan,
      'isDriverOrVehicleChanged': instance.isDriverOrVehicleChanged,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'syncedAt': instance.syncedAt?.toIso8601String(),
      'isSynced': instance.isSynced,
      'retryCount': instance.retryCount,
      'lastError': instance.lastError,
    };

const _$EspbFormTypeEnumMap = {
  EspbFormType.acceptance: 'acceptance',
  EspbFormType.kendala: 'kendala',
};