part of 'spb_bloc.dart';

abstract class SpbState extends Equatable {
  const SpbState();
  @override
  List<Object> get props => [];
}

class SpbInitial extends SpbState {}

class SpbLoading extends SpbState {}

class SpbRefreshing extends SpbState {
  final List<SpbModel> spbList;
  final int totalItems;
  final int currentPage;
  final int totalPages;
  final int itemsPerPage;
  final bool isConnected;
  final String sortColumn;
  final bool sortAscending;
  final String searchQuery;

  const SpbRefreshing({
    required this.spbList,
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
    required this.isConnected,
    required this.sortColumn,
    required this.sortAscending,
    required this.searchQuery,
  });

  @override
  List<Object> get props => [
    spbList,
    totalItems,
    currentPage,
    totalPages,
    itemsPerPage,
    isConnected,
    sortColumn,
    sortAscending,
    searchQuery,
  ];
}

class SpbLoaded extends SpbState {
  final List<SpbModel> spbList;
  final int totalItems;
  final int currentPage;
  final int totalPages;
  final int itemsPerPage;
  final bool isConnected;
  final String sortColumn;
  final bool sortAscending;
  final String searchQuery;

  const SpbLoaded({
    required this.spbList,
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
    required this.isConnected,
    required this.sortColumn,
    required this.sortAscending,
    required this.searchQuery,
  });

  @override
  List<Object> get props => [
    spbList,
    totalItems,
    currentPage,
    totalPages,
    itemsPerPage,
    isConnected,
    sortColumn,
    sortAscending,
    searchQuery,
  ];
}

class SpbLoadFailure extends SpbState {
  final String message;

  const SpbLoadFailure({required this.message});

  @override
  List<Object> get props => [message];
}

class SpbSyncing extends SpbState {
  final List<SpbModel> spbList;
  final int totalItems;
  final int currentPage;
  final int totalPages;
  final int itemsPerPage;
  final bool isConnected;
  final String sortColumn;
  final bool sortAscending;
  final String searchQuery;

  const SpbSyncing({
    required this.spbList,
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
    required this.isConnected,
    required this.sortColumn,
    required this.sortAscending,
    required this.searchQuery,
  });

  @override
  List<Object> get props => [
    spbList,
    totalItems,
    currentPage,
    totalPages,
    itemsPerPage,
    isConnected,
    sortColumn,
    sortAscending,
    searchQuery,
  ];
}

class SpbSyncFailure extends SpbState {
  final String message;
  final List<SpbModel> spbList;
  final int totalItems;
  final int currentPage;
  final int totalPages;
  final int itemsPerPage;
  final bool isConnected;
  final String sortColumn;
  final bool sortAscending;
  final String searchQuery;

  const SpbSyncFailure({
    required this.message,
    required this.spbList,
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
    required this.isConnected,
    required this.sortColumn,
    required this.sortAscending,
    required this.searchQuery,
  });

  @override
  List<Object> get props => [
    message,
    spbList,
    totalItems,
    currentPage,
    totalPages,
    itemsPerPage,
    isConnected,
    sortColumn,
    sortAscending,
    searchQuery,
  ];
}