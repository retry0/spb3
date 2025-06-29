part of 'espb_form_bloc.dart';

abstract class EspbFormState extends Equatable {
  const EspbFormState();
  
  @override
  List<Object?> get props => [];
}

class EspbFormInitial extends EspbFormState {}

// Loading states
class EspbFormLoading extends EspbFormState {
  final String spbNumber;
  
  const EspbFormLoading({required this.spbNumber});
  
  @override
  List<Object> get props => [spbNumber];
}

class EspbFormLoaded extends EspbFormState {
  final EspbFormModel formData;
  
  const EspbFormLoaded({required this.formData});
  
  @override
  List<Object> get props => [formData];
}

class EspbFormEmpty extends EspbFormState {
  final String spbNumber;
  
  const EspbFormEmpty({required this.spbNumber});
  
  @override
  List<Object> get props => [spbNumber];
}

class EspbFormLoadFailure extends EspbFormState {
  final String spbNumber;
  final String message;
  
  const EspbFormLoadFailure({
    required this.spbNumber,
    required this.message,
  });
  
  @override
  List<Object> get props => [spbNumber, message];
}

// Saving states
class EspbFormSaving extends EspbFormState {
  final String spbNumber;
  
  const EspbFormSaving({required this.spbNumber});
  
  @override
  List<Object> get props => [spbNumber];
}

class EspbFormSaveSuccess extends EspbFormState {
  final String spbNumber;
  final bool isSynced;
  
  const EspbFormSaveSuccess({
    required this.spbNumber,
    required this.isSynced,
  });
  
  @override
  List<Object> get props => [spbNumber, isSynced];
}

class EspbFormSaveFailure extends EspbFormState {
  final String spbNumber;
  final String message;
  
  const EspbFormSaveFailure({
    required this.spbNumber,
    required this.message,
  });
  
  @override
  List<Object> get props => [spbNumber, message];
}

// Syncing states
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
  final String spbNumber;
  final String message;
  
  const EspbFormSyncFailure({
    required this.spbNumber,
    required this.message,
  });
  
  @override
  List<Object> get props => [spbNumber, message];
}

// Sync all states
class EspbFormSyncingAll extends EspbFormState {}

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

// Migration states
class EspbFormMigrating extends EspbFormState {}

class EspbFormMigrateSuccess extends EspbFormState {}

class EspbFormMigrateFailure extends EspbFormState {
  final String message;
  
  const EspbFormMigrateFailure({required this.message});
  
  @override
  List<Object> get props => [message];
}