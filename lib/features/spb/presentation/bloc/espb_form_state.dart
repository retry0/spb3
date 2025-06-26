part of 'espb_form_bloc.dart';

abstract class EspbFormState extends Equatable {
  const EspbFormState();
  
  @override
  List<Object?> get props => [];
}

class EspbFormInitial extends EspbFormState {}

class EspbFormSaving extends EspbFormState {}

class EspbFormSaveSuccess extends EspbFormState {
  final bool isSynced;
  
  const EspbFormSaveSuccess({required this.isSynced});
  
  @override
  List<Object> get props => [isSynced];
}

class EspbFormSaveFailure extends EspbFormState {
  final String message;
  
  const EspbFormSaveFailure({required this.message});
  
  @override
  List<Object> get props => [message];
}

class EspbFormSyncing extends EspbFormState {
  final String spbNumber;
  
  const EspbFormSyncing({required this.spbNumber});
  
  @override
  List<Object> get props => [spbNumber];
}

class EspbFormSyncSuccess extends EspbFormState {
  final String spbNumber;
  
  const EspbFormSyncSuccess({required this.spbNumber});
  
  @override
  List<Object> get props => [spbNumber];
}

class EspbFormSyncFailure extends EspbFormState {
  final String message;
  final String spbNumber;
  
  const EspbFormSyncFailure({
    required this.message,
    required this.spbNumber,
  });
  
  @override
  List<Object> get props => [message, spbNumber];
}

class EspbFormSyncingAll extends EspbFormState {
  const EspbFormSyncingAll();
}

class EspbFormSyncAllSuccess extends EspbFormState {
  final int syncedCount;
  
  const EspbFormSyncAllSuccess({required this.syncedCount});
  
  @override
  List<Object> get props => [syncedCount];
}

class EspbFormSyncAllFailure extends EspbFormState {
  final String message;
  
  const EspbFormSyncAllFailure({required this.message});
  
  @override
  List<Object> get props => [message];
}