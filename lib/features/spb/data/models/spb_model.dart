import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'spb_model.g.dart';

@JsonSerializable()
class SpbModel extends Equatable {
  final String noSpb;
  final String tglAntarBuah;
  final String millTujuan;
  final String status;
  final String keterangan;
  final String kodeVendor;
  final String namaVendor;
  final String driver;
  final String noPolisi;
  final String jumJjg; // Changed from int? to String?
  final String brondolan; // Changed from int? to String?
  final String totBeratTaksasi; // Changed from double? to String?
  final String driverName;
  final String millTujuanName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSynced;

  const SpbModel({
    required this.noSpb,
    required this.tglAntarBuah,
    required this.millTujuan,
    required this.status,
    required this.keterangan,
    required this.kodeVendor,
    required this.namaVendor,
    required this.driver,
    required this.noPolisi,
    required this.jumJjg,
    required this.brondolan,
    required this.totBeratTaksasi,
    required this.driverName,
    required this.millTujuanName,
    this.createdAt,
    this.updatedAt,
    this.isSynced = true,
  });

  factory SpbModel.fromJson(Map<String, dynamic> json) {
    return SpbModel(
      noSpb: json['noSpb'].toString(),
      tglAntarBuah: json['tglAntarBuah'] as String,
      millTujuan: json['millTujuan'].toString(),
      status: json['status'].toString(),
      keterangan: json['keterangan'].toString(),
      kodeVendor: json['kodeVendor'].toString(),
      namaVendor: json['namaVendor'].toString(),
      driver: json['driver'].toString(),
      noPolisi: json['noPolisi'].toString(),
      jumJjg: json['jumJjg'].toString(), // Convert to String
      brondolan: json['brondolan'].toString(), // Convert to String
      totBeratTaksasi: json['totBeratTaksasi'].toString(), // Convert to String
      driverName: json['driverName'].toString(),
      millTujuanName: json['millTujuanName'].toString(),
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
  }

  Map<String, dynamic> toJson() => {
    'noSpb': noSpb,
    'tglAntarBuah': tglAntarBuah,
    'millTujuan': millTujuan,
    'status': status,
    'keterangan': keterangan,
    'kodeVendor': kodeVendor,
    'namaVendor': namaVendor,
    'driver': driver,
    'noPolisi': noPolisi,
    'jumJjg': jumJjg,
    'brondolan': brondolan,
    'totBeratTaksasi': totBeratTaksasi,
    'driverName': driverName,
    'millTujuanName': millTujuanName,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isSynced': isSynced,
  };

  // For database operations
  factory SpbModel.fromDatabase(Map<String, dynamic> map) {
    return SpbModel(
      noSpb: map['no_spb'] as String,
      tglAntarBuah: map['tgl_antar_buah'] as String,
      millTujuan: map['mill_tujuan'] as String,
      status: map['status'] as String,
      keterangan: map['keterangan'].toString(),
      kodeVendor: map['kode_vendor'].toString(),
      namaVendor: map['namaVendor'].toString(),
      driver: map['driver'].toString(),
      noPolisi: map['no_polisi'].toString(),
      jumJjg: map['jum_jjg'].toString(), // Convert to String
      brondolan: map['brondolan'].toString(), // Convert to String
      totBeratTaksasi: map['tot_berat_taksasi'].toString(), // Convert to String
      driverName: map['driverName'].toString(),
      millTujuanName: map['millTujuanName'].toString(),
      createdAt:
          map['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] * 1000)
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] * 1000)
              : null,
      //isSynced: (map['is_synced'] as int?) == 1,
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
      'namaVendor': namaVendor,
      'driver': driver,
      'no_polisi': noPolisi,
      'jum_jjg': jumJjg, // Store as String
      'brondolan': brondolan, // Store as String
      'tot_berat_taksasi': totBeratTaksasi, // Store as String
      'driverName': driverName,
      'millTujuanName': millTujuanName,
      'created_at':
          createdAt != null ? createdAt!.millisecondsSinceEpoch ~/ 1000 : now,
      'updated_at':
          updatedAt != null ? updatedAt!.millisecondsSinceEpoch ~/ 1000 : now,
      //'is_synced': isSynced ? 1 : 0,
    };
  }

  SpbModel copyWith({
    String? noSpb,
    String? tglAntarBuah,
    String? millTujuan,
    String? status,
    String? keterangan,
    String? kodeVendor,
    String? namaVendor,
    String? driver,
    String? noPolisi,
    String? jumJjg,
    String? brondolan,
    String? totBeratTaksasi,
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
      namaVendor: namaVendor ?? this.namaVendor,
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
    namaVendor,
    driver,
    noPolisi,
    jumJjg,
    brondolan,
    totBeratTaksasi,
    driverName,
    millTujuanName,
    createdAt,
    updatedAt,
    //isSynced,
  ];
}
