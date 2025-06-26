import 'package:equatable/equatable.dart';

import '../../data/models/espb_form_data.dart';

abstract class EspbFormState extends Equatable {
  const EspbFormState();

  @override
  List<Object?> get props => [];
}

class EspbFormInitial extends EspbFormState {
  const EspbFormInitial();
}

class EspbFormLoading extends EspbFormState {
  const EspbFormLoading();
}

class EspbFormSaving extends EspbFormState {
  const EspbFormSaving();
}

class EspbFormSaved extends EspbFormState {
  final EspbFormData formData;

  const EspbFormSaved({required this.formData});

  @override
  List<Object> get props => [formData];
}

class EspbFormSyncLoading extends EspbFormState {
  final EspbFormData formData;

  const EspbFormSyncLoading({required this.formData});

  @override
  List<Object> get props => [formData];
}

class EspbFormSynced extends EspbFormState {
  final EspbFormData formData;

  const EspbFormSynced({required this.formData});

  @override
  List<Object> get props => [formData];
}

class EspbFormSyncFailed extends EspbFormState {
  final EspbFormData formData;
  final String message;

  const EspbFormSyncFailed({
    required this.formData,
    required this.message,
  });

  @override
  List<Object> get props => [formData, message];
}

class EspbFormError extends EspbFormState {
  final String message;

  const EspbFormError({required this.message});

  @override
  List<Object> get props => [message];
}

class EspbFormLoaded extends EspbFormState {
  final EspbFormData formData;

  const EspbFormLoaded({required this.formData});

  @override
  List<Object> get props => [formData];
}

class EspbFormListLoaded extends EspbFormState {
  final List<EspbFormData> forms;
  final bool isConnected;

  const EspbFormListLoaded({
    required this.forms,
    required this.isConnected,
  });

  @override
  List<Object> get props => [forms, isConnected];
}

class EspbFormSyncAllLoading extends EspbFormState {
  final List<EspbFormData> pendingForms;

  const EspbFormSyncAllLoading({required this.pendingForms});

  @override
  List<Object> get props => [pendingForms];
}

class EspbFormSyncAllComplete extends EspbFormState {
  final int successCount;
  final int totalCount;

  const EspbFormSyncAllComplete({
    required this.successCount,
    required this.totalCount,
  });

  @override
  List<Object> get props => [successCount, totalCount];
}

class EspbFormSyncAllFailed extends EspbFormState {
  final String message;
  final int successCount;
  final int totalCount;

  const EspbFormSyncAllFailed({
    required this.message,
    required this.successCount,
    required this.totalCount,
  });

  @override
  List<Object> get props => [message, successCount, totalCount];
}