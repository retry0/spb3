// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spb_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpbModel _$SpbModelFromJson(Map<String, dynamic> json) => SpbModel(
  noSpb: json['noSpb'] as String,
  tglAntarBuah: json['tglAntarBuah'] as String,
  millTujuan: json['millTujuan'] as String,
  status: json['status'] as String,
  keterangan: json['keterangan'] as String?,
  kodeVendor: json['kodeVendor'] as String?,
  driver: json['driver'] as String?,
  noPolisi: json['noPolisi'] as String?,
  jumJjg: json['jumJjg']?.toString(),
  brondolan: json['brondolan']?.toString(),
  totBeratTaksasi: json['totBeratTaksasi']?.toString(),
  driverName: json['driverName'] as String?,
  millTujuanName: json['millTujuanName'] as String?,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  updatedAt:
      json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? true,
);

Map<String, dynamic> _$SpbModelToJson(SpbModel instance) => <String, dynamic>{
  'noSpb': instance.noSpb,
  'tglAntarBuah': instance.tglAntarBuah,
  'millTujuan': instance.millTujuan,
  'status': instance.status,
  'keterangan': instance.keterangan,
  'kodeVendor': instance.kodeVendor,
  'driver': instance.driver,
  'noPolisi': instance.noPolisi,
  'jumJjg': instance.jumJjg,
  'brondolan': instance.brondolan,
  'totBeratTaksasi': instance.totBeratTaksasi,
  'driverName': instance.driverName,
  'millTujuanName': instance.millTujuanName,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'isSynced': instance.isSynced,
};
