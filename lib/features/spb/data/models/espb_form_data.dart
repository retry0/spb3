import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'espb_form_data.g.dart';

enum EspbFormType {
  acceptance, // For cek_espb_page.dart
  kendala,    // For kendala_form_page.dart
}

@JsonSerializable()
class EspbFormData extends Equatable {
  final String id;
  final String noSpb;
  final EspbFormType formType;
  final String status;
  final String? alasan;
  final bool? isDriverOrVehicleChanged;
  final String latitude;
  final String longitude;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final bool isSynced;
  final int retryCount;
  final String? lastError;

  const EspbFormData({
    required this.id,
    required this.noSpb,
    required this.formType,
    required this.status,
    this.alasan,
    this.isDriverOrVehicleChanged,
    required this.latitude,
    required this.longitude,
    required this.createdBy,
    required this.createdAt,
    this.syncedAt,
    this.isSynced = false,
    this.retryCount = 0,
    this.lastError,
  });

  factory EspbFormData.fromJson(Map<String, dynamic> json) => _$EspbFormDataFromJson(json);

  Map<String, dynamic> toJson() => _$EspbFormDataToJson(this);

  // For database operations
  factory EspbFormData.fromDatabase(Map<String, dynamic> map) {
    return EspbFormData(
      id: map['id'] as String,
      noSpb: map['no_spb'] as String,
      formType: EspbFormType.values[map['form_type'] as int],
      status: map['status'] as String,
      alasan: map['alasan'] as String?,
      isDriverOrVehicleChanged: map['is_driver_vehicle_changed'] == 1 ? true : false,
      latitude: map['latitude'] as String,
      longitude: map['longitude'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] * 1000),
      syncedAt: map['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['synced_at'] * 1000)
          : null,
      isSynced: map['is_synced'] == 1,
      retryCount: map['retry_count'] as int,
      lastError: map['last_error'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return {
      'id': id,
      'no_spb': noSpb,
      'form_type': formType.index,
      'status': status,
      'alasan': alasan,
      'is_driver_vehicle_changed': isDriverOrVehicleChanged == true ? 1 : 0,
      'latitude': latitude,
      'longitude': longitude,
      'created_by': createdBy,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'synced_at': syncedAt?.millisecondsSinceEpoch ~/ 1000,
      'is_synced': isSynced ? 1 : 0,
      'retry_count': retryCount,
      'last_error': lastError,
      'updated_at': now,
    };
  }

  // For API submission
  Map<String, dynamic> toApiJson() {
    final Map<String, dynamic> data = {
      'noSPB': noSpb,
      'status': status,
      'createdBy': createdBy,
      'latitude': latitude,
      'longitude': longitude,
    };

    // Add form-specific fields
    if (formType == EspbFormType.kendala) {
      data['alasan'] = alasan ?? '';
      data['isAnyHandlingEx'] = isDriverOrVehicleChanged.toString();
    }

    return data;
  }

  // Create a copy with updated fields
  EspbFormData copyWith({
    String? id,
    String? noSpb,
    EspbFormType? formType,
    String? status,
    String? alasan,
    bool? isDriverOrVehicleChanged,
    String? latitude,
    String? longitude,
    String? createdBy,
    DateTime? createdAt,
    DateTime? syncedAt,
    bool? isSynced,
    int? retryCount,
    String? lastError,
  }) {
    return EspbFormData(
      id: id ?? this.id,
      noSpb: noSpb ?? this.noSpb,
      formType: formType ?? this.formType,
      status: status ?? this.status,
      alasan: alasan ?? this.alasan,
      isDriverOrVehicleChanged: isDriverOrVehicleChanged ?? this.isDriverOrVehicleChanged,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isSynced: isSynced ?? this.isSynced,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  // Validate form data
  static String? validate(EspbFormData data) {
    if (data.noSpb.isEmpty) {
      return 'SPB number is required';
    }
    
    if (data.status.isEmpty) {
      return 'Status is required';
    }
    
    if (data.createdBy.isEmpty) {
      return 'Created by is required';
    }
    
    // Validate form-specific fields
    if (data.formType == EspbFormType.kendala) {
      if (data.isDriverOrVehicleChanged == true && (data.alasan == null || data.alasan!.isEmpty)) {
        return 'Reason is required when driver or vehicle is changed';
      }
    }
    
    return null; // Valid
  }

  @override
  List<Object?> get props => [
    id,
    noSpb,
    formType,
    status,
    alasan,
    isDriverOrVehicleChanged,
    latitude,
    longitude,
    createdBy,
    createdAt,
    syncedAt,
    isSynced,
    retryCount,
    lastError,
  ];
}