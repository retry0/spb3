part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> activities;

  const HomeLoaded({
    required this.metrics,
    required this.activities,
  });

  @override
  List<Object> get props => [metrics, activities];
}

class HomeError extends HomeState {
  final String message;

  const HomeError({required this.message});

  @override
  List<Object> get props => [message];
}