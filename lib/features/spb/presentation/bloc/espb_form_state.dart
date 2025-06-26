part of 'espb_form_bloc.dart';

abstract class EspbFormState extends Equatable {
  const EspbFormState();
  
  @override
  List<Object?> get props => [];
}

class EspbFormInitial extends EspbFormState {
  const EspbFormInitial();
}

class EspbFormSubmitting extends EspbFormState {
  final String spbNumber;
  
  const EspbFormSubmitting({required this.spbNumber});
  
  @override
  List<Object> get props => [spbNumber];
}

class EspbFormSuccess extends EspbFormState {
  final String spbNumber;
  final bool isSynced;
  final DateTime timestamp;
  
  const EspbFormSuccess({
    required this.spbNumber,
    required this.isSynced,
    required this.timestamp,
  });
  
  @override
  List<Object> get props => [spbNumber, isSynced, timestamp];
}

class EspbFormError extends EspbFormState {
  final String message;
  final String spbNumber;
  
  const EspbFormError({
    required this.message,
    required this.spbNumber,
  });
  
  @override
  List<Object> get props => [message, spbNumber];
}

class EspbFormSyncing extends EspbFormState {
  final String spbNumber;
  
  const EspbFormSyncing({required this.spbNumber});
  
  @override
  List<Object> get props => [spbNumber];
}

class EspbFormSyncSuccess extends EspbFormState {
  final String spbNumber;
  final DateTime timestamp;
  
  const EspbFormSyncSuccess({
    required this.spbNumber,
    required this.timestamp,
  });
  
  @override
  List<Object> get props => [spbNumber, timestamp];
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

class EspbFormSyncAllComplete extends EspbFormState {
  final int count;
  
  const EspbFormSyncAllComplete({required this.count});
  
  @override
  List<Object> get props => [count];
}

class EspbFormSyncAllFailure extends EspbFormState {
  final String message;
  
  const EspbFormSyncAllFailure({required this.message});
  
  @override
  List<Object> get props => [message];
}