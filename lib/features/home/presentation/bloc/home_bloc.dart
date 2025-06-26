import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/repositories/home_repository.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository _repository;

  HomeBloc(this._repository) : super(const HomeInitial()) {
    on<HomeDataRequested>(_onHomeDataRequested);
  }

  Future<void> _onHomeDataRequested(
    HomeDataRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());
    
    try {
      // Simulate loading data
      await Future.delayed(const Duration(seconds: 1));
      
      final metrics = {
        'totalUsers': 1234,
        'activeSessions': 89,
        'dataPoints': 5678,
        'securityScore': 98,
      };
      
      final activities = [
        {'type': 'login', 'user': 'john.doe@example.com', 'time': '2 minutes ago'},
        {'type': 'data_update', 'user': 'jane.smith@example.com', 'time': '5 minutes ago'},
        {'type': 'logout', 'user': 'bob.wilson@example.com', 'time': '10 minutes ago'},
      ];
      
      emit(HomeLoaded(metrics: metrics, activities: activities));
    } catch (e) {
      emit(HomeError(message: e.toString()));
    }
  }
}