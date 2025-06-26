part of 'espb_form_bloc.dart';

abstract class EspbFormEvent extends Equatable {
  const EspbFormEvent();

  @override
  List<Object?> get props => [];
}

class EspbFormSubmitted extends EspbFormEvent {
  final String spbNumber;
  final String status;
  final String createdBy;
  final String latitude;
  final String longitude;
  final String? alasan;
  final bool isAnyHandlingEx;

  const EspbFormSubmitted({
    required this.spbNumber,
    required this.status,
    required this.createdBy,
    required this.latitude,
    required this.longitude,
    this.alasan,
    required this.isAnyHandlingEx,
  });

  @override
  List<Object?> get props => [
    spbNumber,
    status,
    createdBy,
    latitude,
    longitude,
    alasan,
    isAnyHandlingEx,
  ];
}

class EspbFormSyncRequested extends EspbFormEvent {
  final String spbNumber;

  const EspbFormSyncRequested({required this.spbNumber});

  @override
  List<Object> get props => [spbNumber];
}

class EspbFormSyncAll extends EspbFormEvent {
  const EspbFormSyncAll();
}

class EspbFormConnectivityChanged extends EspbFormEvent {
  final bool isConnected;

  const EspbFormConnectivityChanged({required this.isConnected});

  @override
  List<Object> get props => [isConnected];
}