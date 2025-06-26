part of 'spb_bloc.dart';

abstract class SpbEvent extends Equatable {
  const SpbEvent();

  @override
  List<Object> get props => [];
}

class SpbLoadRequested extends SpbEvent {
  final String driver;
  final String kdVendor;

  const SpbLoadRequested({required this.driver, required this.kdVendor});

  @override
  List<Object> get props => [driver, kdVendor];
}

class SpbRefreshRequested extends SpbEvent {
  final String driver;
  final String kdVendor;

  const SpbRefreshRequested({required this.driver, required this.kdVendor});

  @override
  List<Object> get props => [driver, kdVendor];
}

class SpbSyncRequested extends SpbEvent {
  final String driver;
  final String kdVendor;

  const SpbSyncRequested({required this.driver, required this.kdVendor});

  @override
  List<Object> get props => [driver, kdVendor];
}

class SpbSortRequested extends SpbEvent {
  final String column;
  final bool ascending;

  const SpbSortRequested({required this.column, required this.ascending});

  @override
  List<Object> get props => [column, ascending];
}

class SpbSearchRequested extends SpbEvent {
  final String query;

  const SpbSearchRequested({required this.query});

  @override
  List<Object> get props => [query];
}

class SpbPageChanged extends SpbEvent {
  final int page;

  const SpbPageChanged({required this.page});

  @override
  List<Object> get props => [page];
}

class SpbPageSizeChanged extends SpbEvent {
  final int pageSize;
  final int page;

  const SpbPageSizeChanged({required this.pageSize, required this.page});

  @override
  List<Object> get props => [pageSize, page];
}

class SpbConnectivityChanged extends SpbEvent {
  final bool isConnected;

  const SpbConnectivityChanged({required this.isConnected});

  @override
  List<Object> get props => [isConnected];
}