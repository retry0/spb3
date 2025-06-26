import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/models/spb_model.dart';
import '../../domain/usecases/get_spb_for_driver_usecase.dart';
import '../../domain/usecases/sync_spb_data_usecase.dart';

part 'spb_event.dart';
part 'spb_state.dart';

class SpbBloc extends Bloc<SpbEvent, SpbState> {
  final GetSpbForDriverUseCase _getSpbForDriverUseCase;
  final SyncSpbDataUseCase _syncSpbDataUseCase;
  final Connectivity _connectivity;

  // For pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  List<SpbModel> _allSpbData = [];

  // For sorting
  String _sortColumn = 'tglAntarBuah';
  bool _sortAscending = false;

  // For filtering
  String _searchQuery = '';

  SpbBloc({
    required GetSpbForDriverUseCase getSpbForDriverUseCase,
    required SyncSpbDataUseCase syncSpbDataUseCase,
    required Connectivity connectivity,
  }) : _getSpbForDriverUseCase = getSpbForDriverUseCase,
       _syncSpbDataUseCase = syncSpbDataUseCase,
       _connectivity = connectivity,
       super(SpbInitial()) {
    on<SpbLoadRequested>(_onSpbLoadRequested);
    on<SpbRefreshRequested>(_onSpbRefreshRequested);
    on<SpbSyncRequested>(_onSpbSyncRequested);
    on<SpbSortRequested>(_onSpbSortRequested);
    on<SpbSearchRequested>(_onSpbSearchRequested);
    on<SpbPageChanged>(_onSpbPageChanged);
    on<SpbPageSizeChanged>(_onSpbPageSizeChanged);
    on<SpbConnectivityChanged>(_onSpbConnectivityChanged);
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      if (result.isNotEmpty && !result.contains(ConnectivityResult.none)) {
        add(const SpbConnectivityChanged(isConnected: true));
      } else {
        add(const SpbConnectivityChanged(isConnected: false));
      }
    });
  }

  Future<void> _onSpbLoadRequested(
    SpbLoadRequested event,
    Emitter<SpbState> emit,
  ) async {
    emit(SpbLoading());

    final result = await _getSpbForDriverUseCase(
      driver: event.driver,
      kdVendor: event.kdVendor,
      forceRefresh: false,
    );

    await result.fold(
      (failure) async {
        emit(SpbLoadFailure(message: failure.message));
      },
      (spbList) async {
        _allSpbData = spbList;

        // Apply sorting
        _sortData();

        // Apply filtering
        final filteredData = _filterData();

        // Apply pagination
        final paginatedData = _paginateData(filteredData);

        emit(
          SpbLoaded(
            spbList: paginatedData,
            totalItems: filteredData.length,
            currentPage: _currentPage,
            totalPages: (filteredData.length / _itemsPerPage).ceil(),
            itemsPerPage: _itemsPerPage,
            isConnected: await _checkConnectivity(),
            sortColumn: _sortColumn,
            sortAscending: _sortAscending,
            searchQuery: _searchQuery,
          ),
        );
      },
    );
  }

  Future<void> _onSpbRefreshRequested(
    SpbRefreshRequested event,
    Emitter<SpbState> emit,
  ) async {
    emit(
      SpbRefreshing(
        spbList: _allSpbData,
        totalItems: _allSpbData.length,
        currentPage: _currentPage,
        totalPages: (_allSpbData.length / _itemsPerPage).ceil(),
        itemsPerPage: _itemsPerPage,
        isConnected: await _checkConnectivity(),
        sortColumn: _sortColumn,
        sortAscending: _sortAscending,
        searchQuery: _searchQuery,
      ),
    );

    final result = await _getSpbForDriverUseCase(
      driver: event.driver,
      kdVendor: event.kdVendor,
      forceRefresh: true,
    );

    await result.fold(
      (failure) async {
        emit(SpbLoadFailure(message: failure.message));
      },
      (spbList) async {
        _allSpbData = spbList;

        // Apply sorting
        _sortData();

        // Apply filtering
        final filteredData = _filterData();

        // Apply pagination
        final paginatedData = _paginateData(filteredData);

        emit(
          SpbLoaded(
            spbList: paginatedData,
            totalItems: filteredData.length,
            currentPage: _currentPage,
            totalPages: (filteredData.length / _itemsPerPage).ceil(),
            itemsPerPage: _itemsPerPage,
            isConnected: await _checkConnectivity(),
            sortColumn: _sortColumn,
            sortAscending: _sortAscending,
            searchQuery: _searchQuery,
          ),
        );
      },
    );
  }

  Future<void> _onSpbSyncRequested(
    SpbSyncRequested event,
    Emitter<SpbState> emit,
  ) async {
    if (state is SpbLoaded) {
      final currentState = state as SpbLoaded;

      emit(
        SpbSyncing(
          spbList: currentState.spbList,
          totalItems: currentState.totalItems,
          currentPage: currentState.currentPage,
          totalPages: currentState.totalPages,
          itemsPerPage: currentState.itemsPerPage,
          isConnected: currentState.isConnected,
          sortColumn: currentState.sortColumn,
          sortAscending: currentState.sortAscending,
          searchQuery: currentState.searchQuery,
        ),
      );

      final result = await _syncSpbDataUseCase(
        driver: event.driver,
        kdVendor: event.kdVendor,
      );

      await result.fold(
        (failure) async {
          emit(
            SpbSyncFailure(
              message: failure.message,
              spbList: currentState.spbList,
              totalItems: currentState.totalItems,
              currentPage: currentState.currentPage,
              totalPages: currentState.totalPages,
              itemsPerPage: currentState.itemsPerPage,
              isConnected: await _checkConnectivity(),
              sortColumn: currentState.sortColumn,
              sortAscending: currentState.sortAscending,
              searchQuery: currentState.searchQuery,
            ),
          );
        },
        (_) async {
          // Reload data after sync
          final reloadResult = await _getSpbForDriverUseCase(
            driver: event.driver,
            kdVendor: event.kdVendor,
            forceRefresh: false,
          );

          await reloadResult.fold(
            (failure) async {
              emit(
                SpbSyncFailure(
                  message: failure.message,
                  spbList: currentState.spbList,
                  totalItems: currentState.totalItems,
                  currentPage: currentState.currentPage,
                  totalPages: currentState.totalPages,
                  itemsPerPage: currentState.itemsPerPage,
                  isConnected: await _checkConnectivity(),
                  sortColumn: currentState.sortColumn,
                  sortAscending: currentState.sortAscending,
                  searchQuery: currentState.searchQuery,
                ),
              );
            },
            (spbList) async {
              _allSpbData = spbList;

              // Apply sorting
              _sortData();

              // Apply filtering
              final filteredData = _filterData();

              // Apply pagination
              final paginatedData = _paginateData(filteredData);

              emit(
                SpbLoaded(
                  spbList: paginatedData,
                  totalItems: filteredData.length,
                  currentPage: _currentPage,
                  totalPages: (filteredData.length / _itemsPerPage).ceil(),
                  itemsPerPage: _itemsPerPage,
                  isConnected: await _checkConnectivity(),
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  searchQuery: _searchQuery,
                ),
              );
            },
          );
        },
      );
    }
  }

  void _onSpbSortRequested(SpbSortRequested event, Emitter<SpbState> emit) {
    if (state is SpbLoaded) {
      final currentState = state as SpbLoaded;

      // Update sort parameters
      _sortColumn = event.column;
      _sortAscending = event.ascending;

      // Apply sorting
      _sortData();

      // Apply filtering
      final filteredData = _filterData();

      // Apply pagination
      final paginatedData = _paginateData(filteredData);

      emit(
        SpbLoaded(
          spbList: paginatedData,
          totalItems: filteredData.length,
          currentPage: _currentPage,
          totalPages: (filteredData.length / _itemsPerPage).ceil(),
          itemsPerPage: _itemsPerPage,
          isConnected: currentState.isConnected,
          sortColumn: _sortColumn,
          sortAscending: _sortAscending,
          searchQuery: _searchQuery,
        ),
      );
    }
  }

  void _onSpbSearchRequested(SpbSearchRequested event, Emitter<SpbState> emit) {
    if (state is SpbLoaded) {
      final currentState = state as SpbLoaded;

      // Update search query
      _searchQuery = event.query;

      // Reset to first page when searching
      _currentPage = 1;

      // Apply filtering
      final filteredData = _filterData();

      // Apply pagination
      final paginatedData = _paginateData(filteredData);

      emit(
        SpbLoaded(
          spbList: paginatedData,
          totalItems: filteredData.length,
          currentPage: _currentPage,
          totalPages: (filteredData.length / _itemsPerPage).ceil(),
          itemsPerPage: _itemsPerPage,
          isConnected: currentState.isConnected,
          sortColumn: _sortColumn,
          sortAscending: _sortAscending,
          searchQuery: _searchQuery,
        ),
      );
    }
  }

  void _onSpbPageChanged(SpbPageChanged event, Emitter<SpbState> emit) {
    if (state is SpbLoaded) {
      final currentState = state as SpbLoaded;

      // Update current page
      _currentPage = event.page;

      // Apply filtering
      final filteredData = _filterData();

      // Apply pagination
      final paginatedData = _paginateData(filteredData);

      emit(
        SpbLoaded(
          spbList: paginatedData,
          totalItems: filteredData.length,
          currentPage: _currentPage,
          totalPages: (filteredData.length / _itemsPerPage).ceil(),
          itemsPerPage: _itemsPerPage,
          isConnected: currentState.isConnected,
          sortColumn: _sortColumn,
          sortAscending: _sortAscending,
          searchQuery: _searchQuery,
        ),
      );
    }
  }

  void _onSpbPageSizeChanged(SpbPageSizeChanged event, Emitter<SpbState> emit) {
    if (state is SpbLoaded) {
      final currentState = state as SpbLoaded;

      // Update page size and current page
      _itemsPerPage = event.pageSize;
      _currentPage = event.page;

      // Apply filtering
      final filteredData = _filterData();

      // Calculate total pages with new page size
      final totalPages = (filteredData.length / _itemsPerPage).ceil();
      
      // Ensure current page is valid with new page size
      if (_currentPage > totalPages) {
        _currentPage = totalPages > 0 ? totalPages : 1;
      }

      // Apply pagination
      final paginatedData = _paginateData(filteredData);

      emit(
        SpbLoaded(
          spbList: paginatedData,
          totalItems: filteredData.length,
          currentPage: _currentPage,
          totalPages: totalPages,
          itemsPerPage: _itemsPerPage,
          isConnected: currentState.isConnected,
          sortColumn: _sortColumn,
          sortAscending: _sortAscending,
          searchQuery: _searchQuery,
        ),
      );
    }
  }

  Future<void> _onSpbConnectivityChanged(
    SpbConnectivityChanged event,
    Emitter<SpbState> emit,
  ) async {
    if (state is SpbLoaded) {
      final currentState = state as SpbLoaded;
      
      // If we just got connected and we were previously disconnected, try to sync
      if (event.isConnected && !currentState.isConnected) {
        // We'll handle this in the UI layer to avoid circular dependencies
      }

      emit(
        SpbLoaded(
          spbList: currentState.spbList,
          totalItems: currentState.totalItems,
          currentPage: currentState.currentPage,
          totalPages: currentState.totalPages,
          itemsPerPage: currentState.itemsPerPage,
          isConnected: event.isConnected,
          sortColumn: currentState.sortColumn,
          sortAscending: currentState.sortAscending,
          searchQuery: currentState.searchQuery,
        ),
      );
    }
  }

  // Helper methods
  void _sortData() {
    _allSpbData.sort((a, b) {
      dynamic valueA;
      dynamic valueB;
      switch (_sortColumn) {
        case 'noSpb':
          valueA = a.noSpb;
          valueB = b.noSpb;
          break;
        case 'tglAntarBuah':
          valueA = a.tglAntarBuah;
          valueB = b.tglAntarBuah;
          break;
        case 'millTujuan':
          valueA = a.millTujuan;
          valueB = b.millTujuan;
          break;
        case 'status':
          valueA = a.status;
          valueB = b.status;
          break;
        default:
          valueA = a.tglAntarBuah;
          valueB = b.tglAntarBuah;
      }
      int comparison;
      if (valueA is String && valueB is String) {
        comparison = valueA.compareTo(valueB);
      } else if (valueA is num && valueB is num) {
        comparison = valueA.compareTo(valueB);
      } else if (valueA is DateTime && valueB is DateTime) {
        comparison = valueA.compareTo(valueB);
      } else {
        comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  List<SpbModel> _filterData() {
    if (_searchQuery.isEmpty) {
      return _allSpbData;
    }
    final query = _searchQuery.toLowerCase();
    return _allSpbData.where((spb) {
      return spb.noSpb.toLowerCase().contains(query) ||
          spb.millTujuan.toLowerCase().contains(query) ||
          spb.status.toLowerCase().contains(query) ||
          spb.tglAntarBuah.toLowerCase().contains(query) ||
          (spb.kodeVendor?.toLowerCase().contains(query) ?? false) ||
          (spb.driver?.toLowerCase().contains(query) ?? false) ||
          (spb.noPolisi?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<SpbModel> _paginateData(List<SpbModel> data) {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= data.length) {
      return [];
    }

    return data.sublist(
      startIndex,
      endIndex > data.length ? data.length : endIndex,
    );
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.isNotEmpty &&
        !connectivityResult.contains(ConnectivityResult.none);
  }
}