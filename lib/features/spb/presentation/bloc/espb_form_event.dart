part of 'espb_form_bloc.dart';

abstract class EspbFormEvent extends Equatable {
  const EspbFormEvent();

  @override
  List<Object?> get props => [];
}

class EspbFormSaveRequested extends EspbFormEvent {
  final EspbFormData formData;
  
  const EspbFormSaveRequested({required this.formData});
  
  @override
  List<Object> get props => [formData];
}

class EspbFormSyncRequested extends EspbFormEvent {
  final String spbNumber;
  
  const EspbFormSyncRequested({required this.spbNumber});
  
  @override
  List<Object> get props => [spbNumber];
}

class EspbFormSyncAllRequested extends EspbFormEvent {
  const EspbFormSyncAllRequested();
}

class EspbFormConnectivityChanged extends EspbFormEvent {
  final bool isConnected;
  
  const EspbFormConnectivityChanged({required this.isConnected});
  
  @override
  List<Object> get props => [isConnected];
}