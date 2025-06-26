import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'espb_form_data.g.dart';

/// Model representing ESPB form data that needs to be saved and synced
@JsonSerializable()
class EspbFormData extends Equatable {
  final String noSpb;
  final String status; // "1" for accepted, "2" for kendala
  final String createdBy;
  final String latitude;
  final String longitude;
  final String? alasan; // Reason for kendala, null for accepted
  final bool? isAnyHandlingEx; // Driver/vehicle change flag, null for accepted
  final DateTime timestamp;
  final bool isSynced;
  final int retryCount;
  final String? lastError;

  const EspbFormData({
    required this.noSpb,
    required this.status,
    required this.createdBy,
    required this.latitude,
    required this.longitude,
    this.alasan,
    this.isAnyHandlingEx,
    required this.timestamp,
    this.isSynced = false,
    this.retryCount = 0,
    this.lastError,
  });

  factory EspbFormData.fromJson(Map<String, dynamic> json) => _$EspbFormDataFromJson(json);

  Map<String, dynamic> toJson() => _$EspbFormDataToJson(this);

  /// Create a map for database storage
  Map<String, dynamic> toDatabase() {
    return {
      'no_spb': noSpb,
      'status': status,
      'created_by': createdBy,
      'latitude': latitude,
      'longitude': longitude,
      'alasan': alasan,
      'is_any_handling_ex': isAnyHandlingEx != null ? (isAnyHandlingEx! ? 1 : 0) : null,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'is_synced': isSynced ? 1 : 0,
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  /// Create from database record
  factory EspbFormData.fromDatabase(Map<String, dynamic> data) {
    return EspbFormData(
      noSpb: data['no_spb'] as String,
      status: data['status'] as String,
      createdBy: data['created_by'] as String,
      latitude: data['latitude'] as String,
      longitude: data['longitude'] as String,
      alasan: data['alasan'] as String?,
      isAnyHandlingEx: data['is_any_handling_ex'] != null 
          ? (data['is_any_handling_ex'] as int) == 1 
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch((data['timestamp'] as int) * 1000),
      isSynced: (data['is_synced'] as int) == 1,
      retryCount: data['retry_count'] as int,
      lastError: data['last_error'] as String?,
    );
  }

  /// Create a copy with updated fields
  EspbFormData copyWith({
    String? noSpb,
    String? status,
    String? createdBy,
    String? latitude,
    String? longitude,
    String? alasan,
    bool? isAnyHandlingEx,
    DateTime? timestamp,
    bool? isSynced,
    int? retryCount,
    String? lastError,
  }) {
    return EspbFormData(
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
    );
  }

  /// Create a map for API submission
  Map<String, dynamic> toApiRequest() {
    final Map<String, dynamic> data = {
      'noSPB': noSpb,
      'status': status,
      'createdBy': createdBy,
      'latitude': latitude,
      'longitude': longitude,
    };

    // Add optional fields only if they exist
    if (alasan != null && alasan!.isNotEmpty) {
      data['alasan'] = alasan;
    }

    if (isAnyHandlingEx != null) {
      data['isAnyHandlingEx'] = isAnyHandlingEx.toString();
    }

    return data;
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
  ];
}