import 'package:equatable/equatable.dart';

import '../../data/models/espb_form_data.dart';

abstract class EspbFormEvent extends Equatable {
  const EspbFormEvent();

  @override
  List<Object?> get props => [];
}

class SaveAcceptanceFormRequested extends EspbFormEvent {
  final String noSpb;
  final String latitude;
  final String longitude;
  final String createdBy;

  const SaveAcceptanceFormRequested({
    required this.noSpb,
    required this.latitude,
    required this.longitude,
    required this.createdBy,
  });

  @override
  List<Object> get props => [noSpb, latitude, longitude, createdBy];
}

class SaveKendalaFormRequested extends EspbFormEvent {
  final String noSpb;
  final String alasan;
  final bool isDriverOrVehicleChanged;
  final String latitude;
  final String longitude;
  final String createdBy;

  const SaveKendalaFormRequested({
    required this.noSpb,
    required this.alasan,
    required this.isDriverOrVehicleChanged,
    required this.latitude,
    required this.longitude,
    required this.createdBy,
  });

  @override
  List<Object> get props => [
    noSpb,
    alasan,
    isDriverOrVehicleChanged,
    latitude,
    longitude,
    createdBy,
  ];
}

class SyncFormRequested extends EspbFormEvent {
  final String formId;

  const SyncFormRequested({required this.formId});

  @override
  List<Object> get props => [formId];
}

class SyncAllFormsRequested extends EspbFormEvent {
  const SyncAllFormsRequested();
}

class GetFormRequested extends EspbFormEvent {
  final String formId;

  const GetFormRequested({required this.formId});

  @override
  List<Object> get props => [formId];
}

class GetPendingFormsRequested extends EspbFormEvent {
  const GetPendingFormsRequested();
}

class GetFormsForSpbRequested extends EspbFormEvent {
  final String noSpb;

  const GetFormsForSpbRequested({required this.noSpb});

  @override
  List<Object> get props => [noSpb];
}

class ConnectivityChanged extends EspbFormEvent {
  final bool isConnected;

  const ConnectivityChanged({required this.isConnected});

  @override
  List<Object> get props => [isConnected];
}