import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'espb_form_model.g.dart';

@JsonSerializable()
class EspbFormModel extends Equatable {
  final String noSpb;
  final String status;
  final String createdBy;
  final String latitude;
  final String longitude;
  final String? alasan;
  final String isAnyHandlingEx;
  final int timestamp;
  final bool isSynced;
  final int retryCount;
  final String? lastError;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSyncAttempt;

  const EspbFormModel({
    required this.noSpb,
    required this.status,
    required this.createdBy,
    required this.latitude,
    required this.longitude,
    this.alasan,
    required this.isAnyHandlingEx,
    required this.timestamp,
    this.isSynced = false,
    this.retryCount = 0,
    this.lastError,
    this.createdAt,
    this.updatedAt,
    this.lastSyncAttempt,
  });

  factory EspbFormModel.fromJson(Map<String, dynamic> json) => _$EspbFormModelFromJson(json);

  Map<String, dynamic> toJson() => _$EspbFormModelToJson(this);

  // For database operations
  factory EspbFormModel.fromDatabase(Map<String, dynamic> map) {
    return EspbFormModel(
      noSpb: map['no_spb'] as String,
      status: map['status'] as String,
      createdBy: map['created_by'] as String,
      latitude: map['latitude'] as String,
      longitude: map['longitude'] as String,
      alasan: map['alasan'] as String?,
      isAnyHandlingEx: map['is_any_handling_ex'] as String,
      timestamp: map['timestamp'] as int,
      isSynced: (map['is_synced'] as int) == 1,
      retryCount: map['retry_count'] as int,
      lastError: map['last_error'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int) * 1000)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['updated_at'] as int) * 1000)
          : null,
      lastSyncAttempt: map['last_sync_attempt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['last_sync_attempt'] as int) * 1000)
          : null,
    );
  }

  Map<String, dynamic> toDatabase() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return {
      'no_spb': noSpb,
      'status': status,
      'created_by': createdBy,
      'latitude': latitude,
      'longitude': longitude,
      'alasan': alasan,
      'is_any_handling_ex': isAnyHandlingEx,
      'timestamp': timestamp,
      'is_synced': isSynced ? 1 : 0,
      'retry_count': retryCount,
      'last_error': lastError,
      'created_at': createdAt != null ? createdAt!.millisecondsSinceEpoch ~/ 1000 : now,
      'updated_at': updatedAt != null ? updatedAt!.millisecondsSinceEpoch ~/ 1000 : now,
      'last_sync_attempt': lastSyncAttempt != null ? lastSyncAttempt!.millisecondsSinceEpoch ~/ 1000 : null,
    };
  }

  // Create a copy with updated fields
  EspbFormModel copyWith({
    String? noSpb,
    String? status,
    String? createdBy,
    String? latitude,
    String? longitude,
    String? alasan,
    String? isAnyHandlingEx,
    int? timestamp,
    bool? isSynced,
    int? retryCount,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncAttempt,
  }) {
    return EspbFormModel(
      noSpb: noSpb ?? this.noSpb,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      alasan: alasan ?? this.alasan,
      isAnyHandlingEx: isAnyHandlingEx ?? this.isAnyHandlingEx,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
    );
  }

  // For API requests
  Map<String, dynamic> toApiRequest() {
    return {
      'noSPB': noSpb,
      'status': status,
      'createdBy': createdBy,
      'latitude': latitude,
      'longitude': longitude,
      'alasan': alasan,
      'isAnyHandlingEx': isAnyHandlingEx,
      'timestamp': timestamp,
    };
  }

  @override
  List<Object?> get props => [
    noSpb,
    status,
    createdBy,
    latitude,
    longitude,
    alasan,
    isAnyHandlingEx,
    timestamp,
    isSynced,
    retryCount,
    lastError,
    createdAt,
    updatedAt,
    lastSyncAttempt,
  ];
}