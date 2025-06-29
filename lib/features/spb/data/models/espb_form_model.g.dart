// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'espb_form_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EspbFormModel _$EspbFormModelFromJson(Map<String, dynamic> json) => EspbFormModel(
      noSpb: json['noSpb'] as String,
      status: json['status'] as String,
      createdBy: json['createdBy'] as String,
      latitude: json['latitude'] as String,
      longitude: json['longitude'] as String,
      alasan: json['alasan'] as String?,
      isAnyHandlingEx: json['isAnyHandlingEx'] as String,
      timestamp: json['timestamp'] as int,
      isSynced: json['isSynced'] as bool? ?? false,
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      lastSyncAttempt: json['lastSyncAttempt'] == null
          ? null
          : DateTime.parse(json['lastSyncAttempt'] as String),
    );

Map<String, dynamic> _$EspbFormModelToJson(EspbFormModel instance) => <String, dynamic>{
      'noSpb': instance.noSpb,
      'status': instance.status,
      'createdBy': instance.createdBy,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'alasan': instance.alasan,
      'isAnyHandlingEx': instance.isAnyHandlingEx,
      'timestamp': instance.timestamp,
      'isSynced': instance.isSynced,
      'retryCount': instance.retryCount,
      'lastError': instance.lastError,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'lastSyncAttempt': instance.lastSyncAttempt?.toIso8601String(),
    };