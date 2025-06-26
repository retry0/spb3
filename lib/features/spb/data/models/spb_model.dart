import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'spb_model.g.dart';

@JsonSerializable()
class SpbModel extends Equatable {
  final String noSpb;
  final String tglAntarBuah;
  final String millTujuan;
  final String status;
  final String? keterangan;
  final String? kodeVendor;
  final String? driver;
  final String? noPolisi;
  final int? jumJjg;
  final int? brondolan;
  final double? totBeratTaksasi;
  final String? driverName;
  final String? millTujuanName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSynced;

  const SpbModel({
    required this.noSpb,
    required this.tglAntarBuah,
    required this.millTujuan,
    required this.status,
    this.keterangan,
    this.kodeVendor,
    this.driver,
    this.noPolisi,
    this.jumJjg,
    this.brondolan,
    this.totBeratTaksasi,
    this.driverName,
    this.millTujuanName,
    this.createdAt,
    this.updatedAt,
    this.isSynced = true,
  });

  factory SpbModel.fromJson(Map<String, dynamic> json) =>
      _$SpbModelFromJson(json);

  Map<String, dynamic> toJson() => _$SpbModelToJson(this);

  // For database operations
  factory SpbModel.fromDatabase(Map<String, dynamic> map) {
    return SpbModel(
      noSpb: map['no_spb'] as String,
      tglAntarBuah: map['tgl_antar_buah'] as String,
      millTujuan: map['mill_tujuan'] as String,
      status: map['status'] as String,
      keterangan: map['keterangan'] as String?,
      kodeVendor: map['kode_vendor'] as String?,
      driver: map['driver'] as String?,
      noPolisi: map['no_polisi'] as String?,
      jumJjg: map['jum_jjg'] as int?,
      brondolan: map['brondolan'] as int?,
      totBeratTaksasi:
          map['tot_berat_taksasi'] != null
              ? (map['tot_berat_taksasi'] as num).toDouble()
              : null,
      driverName: map['driverName'] as String?,
      millTujuanName: map['millTujuanName'] as String?,
      createdAt:
          map['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] * 1000)
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] * 1000)
              : null,
      isSynced: (map['is_synced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toDatabase() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return {
      'no_spb': noSpb,
      'tgl_antar_buah': tglAntarBuah,
      'mill_tujuan': millTujuan,
      'status': status,
      'keterangan': keterangan,
      'kode_vendor': kodeVendor,
      'driver': driver,
      'no_polisi': noPolisi,
      'jum_jjg': jumJjg,
      'brondolan': brondolan,
      'tot_berat_taksasi': totBeratTaksasi,
      'driverName': driverName,
      'millTujuanName': millTujuanName,
      'created_at':
          createdAt != null ? createdAt!.millisecondsSinceEpoch ~/ 1000 : now,
      'updated_at':
          updatedAt != null ? updatedAt!.millisecondsSinceEpoch ~/ 1000 : now,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  SpbModel copyWith({
    String? noSpb,
    String? tglAntarBuah,
    String? millTujuan,
    String? status,
    String? keterangan,
    String? kodeVendor,
    String? driver,
    String? noPolisi,
    int? jumJjg,
    int? brondolan,
    double? totBeratTaksasi,
    String? driverName,
    String? millTujuanName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return SpbModel(
      noSpb: noSpb ?? this.noSpb,
      tglAntarBuah: tglAntarBuah ?? this.tglAntarBuah,
      millTujuan: millTujuan ?? this.millTujuan,
      status: status ?? this.status,
      keterangan: keterangan ?? this.keterangan,
      kodeVendor: kodeVendor ?? this.kodeVendor,
      driver: driver ?? this.driver,
      noPolisi: noPolisi ?? this.noPolisi,
      jumJjg: jumJjg ?? this.jumJjg,
      brondolan: brondolan ?? this.brondolan,
      totBeratTaksasi: totBeratTaksasi ?? this.totBeratTaksasi,
      driverName: driverName ?? this.driverName,
      millTujuanName: millTujuanName ?? this.millTujuanName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
    noSpb,
    tglAntarBuah,
    millTujuan,
    status,
    keterangan,
    kodeVendor,
    driver,
    noPolisi,
    jumJjg,
    brondolan,
    totBeratTaksasi,
    driverName,
    millTujuanName,
    createdAt,
    updatedAt,
    isSynced,
  ];
}