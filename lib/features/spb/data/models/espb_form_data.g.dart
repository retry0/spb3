// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'espb_form_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EspbFormData _$EspbFormDataFromJson(Map<String, dynamic> json) => EspbFormData(
      noSpb: json['noSpb'] as String,
      status: json['status'] as String,
      createdBy: json['createdBy'] as String,
      latitude: json['latitude'] as String,
      longitude: json['longitude'] as String,
      alasan: json['alasan'] as String?,
      isAnyHandlingEx: json['isAnyHandlingEx'] as bool?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSynced: json['isSynced'] as bool? ?? false,
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );

Map<String, dynamic> _$EspbFormDataToJson(EspbFormData instance) =>
    <String, dynamic>{
      'noSpb': instance.noSpb,
      'status': instance.status,
      'createdBy': instance.createdBy,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'alasan': instance.alasan,
      'isAnyHandlingEx': instance.isAnyHandlingEx,
      'timestamp': instance.timestamp.toIso8601String(),
      'isSynced': instance.isSynced,
      'retryCount': instance.retryCount,
      'lastError': instance.lastError,
    };