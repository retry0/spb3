import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' show RefreshController;
import 'dart:async';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/spb_bloc.dart';
import '../../data/models/spb_model.dart';
import 'spb_search_bar.dart';
import 'spb_offline_indicator.dart';
import 'spb_qr_code_modal.dart';
import '../pages/cek_espb_page.dart';
import '../pages/kendala_form_page.dart';
import '../../../../core/theme/app_theme.dart';

class SpbDataTable extends StatefulWidget {
  const SpbDataTable({super.key});

  @override
  State<SpbDataTable> createState() => _SpbDataTableState();
}

class _SpbDataTableState extends State<SpbDataTable>
    with SingleTickerProviderStateMixin {
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _isSearchExpanded = ValueNotifier<bool>(false);
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final ScrollController _horizontalScrollController = ScrollController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String? _driver;
  String? _kdVendor;
  String _sortColumn = 'tglAntarBuah';
  bool _sortAscending = false;

  // Debounce timer for search
  Timer? _debounceTimer;

  // Retry mechanism for sync
  int _syncRetryCount = 0;
  static const int _maxSyncRetries = 3;
  Timer? _syncRetryTimer;

  // Auto-sync timer
  Timer? _autoSyncTimer;
  static const Duration _autoSyncInterval = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _getUserInfo();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // Listen for search query changes
    _searchController.addListener(_onSearchChanged);

    // Start auto-sync timer
    _startAutoSyncTimer();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    _isSearchExpanded.dispose();
    _searchQuery.dispose();
    _horizontalScrollController.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    _syncRetryTimer?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      // Only auto-sync if we have connectivity and user info
      final state = context.read<SpbBloc>().state;
      if (state is SpbLoaded &&
          state.isConnected &&
          _driver != null &&
          _kdVendor != null) {
        context.read<SpbBloc>().add(
          SpbSyncRequested(driver: _driver!, kdVendor: _kdVendor!),
        );
      }
    });
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchQuery.value = _searchController.text;
      if (_driver != null && _kdVendor != null) {
        context.read<SpbBloc>().add(
          SpbSearchRequested(query: _searchController.text),
        );
      }
    });
  }

  void _getUserInfo() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      setState(() {
        _driver = authState.user.UserName;
        _kdVendor = authState.user.Id;
      });

      // Load data once we have user info
      if (_driver != null && _kdVendor != null) {
        context.read<SpbBloc>().add(
          SpbLoadRequested(driver: _driver!, kdVendor: _kdVendor!),
        );
      }
    }
  }

  void _onRefresh() {
    if (_driver != null && _kdVendor != null) {
      context.read<SpbBloc>().add(
        SpbRefreshRequested(driver: _driver!, kdVendor: _kdVendor!),
      );
    }
    _refreshController.refreshCompleted();
  }

  void _onSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
    context.read<SpbBloc>().add(
      SpbSortRequested(column: column, ascending: ascending),
    );
  }

  void _syncData() {
    if (_driver != null && _kdVendor != null) {
      _syncRetryCount = 0; // Reset retry count
      context.read<SpbBloc>().add(
        SpbSyncRequested(driver: _driver!, kdVendor: _kdVendor!),
      );
    }
  }

  void _retrySync() {
    if (_syncRetryCount < _maxSyncRetries) {
      _syncRetryCount++;

      // Exponential backoff for retries
      final backoffDuration = Duration(seconds: 2 * _syncRetryCount);

      _syncRetryTimer?.cancel();
      _syncRetryTimer = Timer(backoffDuration, () {
        _syncData();
      });

      // Show retry message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Retrying sync (${_syncRetryCount}/$_maxSyncRetries)...',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Max retries reached
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Sync failed after multiple attempts. Please try again later.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return BlocConsumer<SpbBloc, SpbState>(
      listener: (context, state) {
        if (state is SpbLoadFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        } else if (state is SpbSyncFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _retrySync,
                textColor: Colors.white,
              ),
            ),
          );
        } else if (state is SpbLoaded && !state.isConnected) {
          // Automatically load from SQLite when offline
          if (_driver != null && _kdVendor != null) {
            // No need to make a special call - the repository already handles
            // offline data loading in the SpbLoadRequested event
          }
        } else if (state is SpbLoaded && state.isConnected) {
          // Check if we were previously offline and now online
          final previousState = context.read<SpbBloc>().state;
          if (previousState is SpbLoaded && !previousState.isConnected) {
            // We just came back online, trigger a sync
            if (_driver != null && _kdVendor != null) {
              context.read<SpbBloc>().add(
                SpbSyncRequested(driver: _driver!, kdVendor: _kdVendor!),
              );
            }
          }
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            // Offline indicator
            if (state is SpbLoaded && !state.isConnected)
              const SpbOfflineIndicator(),

            // Search and filter bar
            _buildSearchAndFilterBar(context, state, isSmallScreen),

            // Data table
            Expanded(
              child: SmartRefresher(
                controller: _refreshController,
                onRefresh: _onRefresh,
                child: _buildTableContent(context, state, isSmallScreen),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilterBar(
    BuildContext context,
    SpbState state,
    bool isSmallScreen,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _isSearchExpanded,
                builder: (context, isExpanded, child) {
                  return isExpanded || !isSmallScreen
                      ? Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari SPB...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                _searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                    : isSmallScreen
                                    ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _isSearchExpanded.value = false;
                                      },
                                    )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      )
                      : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          _isSearchExpanded.value = true;
                        },
                        tooltip: 'Search',
                      );
                },
              ),
              if (!isSmallScreen || !_isSearchExpanded.value) ...[
                const SizedBox(width: 8),
                _buildSortButton(context, state),
              ],
            ],
          ),

          // Active filters display
          ValueListenableBuilder<String>(
            valueListenable: _searchQuery,
            builder: (context, query, child) {
              if (query.isEmpty) return const SizedBox.shrink();

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filter: "$query"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        _searchQuery.value = '';
                        context.read<SpbBloc>().add(
                          const SpbSearchRequested(query: ''),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(BuildContext context, SpbState state) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        bool ascending = true;
        if (value == _sortColumn) {
          ascending = !_sortAscending;
        }
        _onSort(value, ascending);
      },
      itemBuilder:
          (context) => [
            _buildSortMenuItem(
              'tglAntarBuah',
              'Date',
              _sortColumn,
              _sortAscending,
            ),
            _buildSortMenuItem(
              'noSpb',
              'SPB Number',
              _sortColumn,
              _sortAscending,
            ),
            _buildSortMenuItem(
              'millTujuan',
              'Destination',
              _sortColumn,
              _sortAscending,
            ),
            _buildSortMenuItem('status', 'Status', _sortColumn, _sortAscending),
          ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
    String value,
    String label,
    String currentSortColumn,
    bool currentSortAscending,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          if (value == currentSortColumn)
            Icon(
              currentSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
            ),
        ],
      ),
    );
  }

  Widget _buildTableContent(
    BuildContext context,
    SpbState state,
    bool isSmallScreen,
  ) {
    if (state is SpbLoading) {
      return _buildLoadingState();
    } else if (state is SpbLoaded ||
        state is SpbRefreshing ||
        state is SpbSyncing) {
      List<SpbModel> spbList;
      bool isRefreshing = false;

      if (state is SpbLoaded) {
        spbList = state.spbList;
      } else if (state is SpbRefreshing) {
        spbList = state.spbList;
        isRefreshing = true;
      } else if (state is SpbSyncing) {
        spbList = (state as SpbSyncing).spbList;
        isRefreshing = true;
      } else if (state is SpbSyncFailure) {
        spbList = state.spbList;
      } else {
        spbList = [];
      }

      if (spbList.isEmpty) {
        return _buildEmptyState();
      }

      return FadeTransition(
        opacity: _fadeAnimation,
        child:
            isSmallScreen
                ? _buildCardBasedList(context, spbList, isRefreshing)
                : _buildDataTable(context, spbList, isRefreshing),
      );
    } else if (state is SpbLoadFailure) {
      return _buildErrorState(state);
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading SPB data...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No SPB data available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(SpbLoadFailure state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load SPB data',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              state.message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (_driver != null && _kdVendor != null) {
                context.read<SpbBloc>().add(
                  SpbLoadRequested(driver: _driver!, kdVendor: _kdVendor!),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBasedList(
    BuildContext context,
    List<SpbModel> spbList,
    bool isRefreshing,
  ) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: spbList.length,
          itemBuilder: (context, index) {
            final spb = spbList[index];
            return _buildSpbCard(context, spb);
          },
        ),
        if (isRefreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
          ),
      ],
    );
  }

  Widget _buildSpbCard(BuildContext context, SpbModel spb) {
    final isPending = spb.status == "0";
    final isSynced = spb.isSynced;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSpbDetails(context, spb),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      spb.noSpb,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(context, spb.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat(
                      'dd/MM/yyyy',
                    ).format(DateTime.parse(spb.tglAntarBuah)),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat(
                      'HH:mm',
                    ).format(DateTime.parse(spb.tglAntarBuah)),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  // Sync status indicator
                  if (!isSynced)
                    Icon(Icons.sync_problem, size: 14, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      spb.millTujuanName ?? 'N/A',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isPending) ...[
                    _buildActionButton(
                      context,
                      label: 'Terima',
                      icon: Icons.check_circle,
                      color: Colors.green,
                      onPressed: () => _navigateToCekEspbPage(context, spb),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      context,
                      label: 'Kendala',
                      icon: Icons.report_problem,
                      color: AppTheme.errorColor,
                      onPressed: () => _navigateToKendalaFormPage(context, spb),
                    ),
                  ] else ...[
                    _buildActionButton(
                      context,
                      label: 'Detail',
                      icon: Icons.visibility,
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () => _showSpbDetails(context, spb),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code, size: 20),
                    color: Colors.blue,
                    onPressed: () => _showQrCodeModal(context, spb),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'QR Code',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    List<SpbModel> spbList,
    bool isRefreshing,
  ) {
    return Stack(
      children: [
        Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: _buildColumns(context),
                rows: _buildRows(context, spbList),
                sortColumnIndex: _getSortColumnIndex(),
                sortAscending: _sortAscending,
                showCheckboxColumn: false,
                horizontalMargin: 16,
                columnSpacing: 16,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 64,
                headingRowHeight: 56,
                dividerThickness: 1,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                headingRowColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) =>
                      Theme.of(context).colorScheme.surface,
                ),
                dataRowColor: MaterialStateProperty.resolveWith<Color?>((
                  Set<MaterialState> states,
                ) {
                  if (states.contains(MaterialState.selected)) {
                    return Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08);
                  }
                  if (states.contains(MaterialState.hovered)) {
                    return Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.04);
                  }
                  return null;
                }),
              ),
            ),
          ),
        ),
        if (isRefreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
          ),
      ],
    );
  }

  List<DataColumn> _buildColumns(BuildContext context) {
    return [
      DataColumn(
        label: const Text('No. SPB'),
        tooltip: 'SPB Number',
        onSort: (columnIndex, ascending) => _onSort('noSpb', ascending),
      ),
      DataColumn(
        label: const Text('Tanggal'),
        tooltip: 'Date',
        onSort: (columnIndex, ascending) => _onSort('tglAntarBuah', ascending),
      ),
      DataColumn(label: const Text('Jam'), tooltip: 'Time'),
      DataColumn(
        label: const Text('Mill Tujuan'),
        tooltip: 'Destination Mill',
        onSort: (columnIndex, ascending) => _onSort('millTujuan', ascending),
      ),
      DataColumn(
        label: const Text('Status'),
        tooltip: 'Status',
        onSort: (columnIndex, ascending) => _onSort('status', ascending),
      ),
      DataColumn(label: const Text('Sync'), tooltip: 'Sync Status'),
      const DataColumn(label: Text('Action'), tooltip: 'Actions'),
      const DataColumn(label: Text('QR Code'), tooltip: 'QR Code'),
    ];
  }

  List<DataRow> _buildRows(BuildContext context, List<SpbModel> spbList) {
    return spbList.map((spb) {
      return DataRow(
        cells: [
          DataCell(
            Tooltip(
              message: spb.noSpb,
              child: Text(spb.noSpb, overflow: TextOverflow.ellipsis),
            ),
          ),
          DataCell(
            Text(
              DateFormat('dd/MM/yyyy').format(DateTime.parse(spb.tglAntarBuah)),
            ),
          ),
          DataCell(
            Text(DateFormat('HH:mm').format(DateTime.parse(spb.tglAntarBuah))),
          ),
          DataCell(
            Tooltip(
              message: spb.millTujuanName ?? spb.millTujuan,
              child: Text(
                spb.millTujuanName ?? spb.millTujuan,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          DataCell(_buildStatusBadge(context, spb.status)),
          DataCell(_buildSyncStatusIndicator(context, spb.isSynced)),
          DataCell(_buildActionCell(context, spb)),
          DataCell(
            IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.blue),
              onPressed: () => _showQrCodeModal(context, spb),
              tooltip: 'Generate QR Code',
            ),
          ),
        ],
        onSelectChanged: (selected) {
          if (selected == true) {
            _showSpbDetails(context, spb);
          }
        },
        color: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.selected)) {
            return Theme.of(context).colorScheme.primary.withOpacity(0.08);
          }
          if (states.contains(MaterialState.hovered)) {
            return Theme.of(context).colorScheme.primary.withOpacity(0.04);
          }
          return null;
        }),
      );
    }).toList();
  }

  Widget _buildSyncStatusIndicator(BuildContext context, bool isSynced) {
    return isSynced
        ? Icon(Icons.cloud_done, color: Colors.green, size: 20)
        : Tooltip(
          message: 'Not synced with server',
          child: Icon(Icons.sync_problem, color: Colors.orange, size: 20),
        );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color color;
    IconData icon;
    String statusText = _getStatusText(status);

    switch (status) {
      case "0":
        color = Colors.blue;
        icon = Icons.info;
        break;
      case "1":
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case "2":
        color = Colors.red;
        icon = Icons.report_problem;
        break;
      case "3":
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case "5":
        color = Colors.orange;
        icon = Icons.sync_problem;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case "0":
        return "SPB baru disubmit";
      case "1":
        return "Sedang ke lokasi tujuan mill";
      case "2":
        return "Ada kendala";
      case "3":
        return "Cancel";
      case "5":
        return "SPB Gagal sync";
      default:
        return "Unknown";
    }
  }

  Widget _buildActionCell(BuildContext context, SpbModel spb) {
    // Show "Terima" button only if status is "0" (Pending)
    if (spb.status == "0") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => _navigateToCekEspbPage(context, spb),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Terima'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _navigateToKendalaFormPage(context, spb),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Kendala'),
          ),
        ],
      );
    } else {
      return TextButton(
        onPressed: () => _showSpbDetails(context, spb),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('View'),
      );
    }
  }

  void _showQrCodeModal(BuildContext context, SpbModel spb) {
    showDialog(
      context: context,
      builder:
          (context) => SpbQrCodeModal(
            spb: spb,
            driver: _driver ?? '',
            kdVendor: _kdVendor ?? '',
          ),
    );
  }

  Future<void> _navigateToCekEspbPage(
    BuildContext context,
    SpbModel spb,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CekEspbPage(spb: spb)),
    );

    // If returned with success, refresh the data
    if (result == true && _driver != null && _kdVendor != null) {
      context.read<SpbBloc>().add(
        SpbRefreshRequested(driver: _driver!, kdVendor: _kdVendor!),
      );
    }
  }

  Future<void> _navigateToKendalaFormPage(
    BuildContext context,
    SpbModel spb,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => KendalaFormPage(spb: spb)),
    );

    // If returned with success, refresh the data
    if (result == true && _driver != null && _kdVendor != null) {
      context.read<SpbBloc>().add(
        SpbRefreshRequested(driver: _driver!, kdVendor: _kdVendor!),
      );
    }
  }

  void _showSpbDetails(BuildContext context, SpbModel spb) {
    final screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenSize.width * 0.9,
                maxHeight: screenSize.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SPB Detail: ${spb.noSpb}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('No. SPB', spb.noSpb),
                          _buildDetailRow(
                            'Tanggal',
                            DateFormat(
                              'dd/MM/yyyy',
                            ).format(DateTime.parse(spb.tglAntarBuah)),
                          ),
                          _buildDetailRow(
                            'Waktu',
                            DateFormat(
                              'HH:mm',
                            ).format(DateTime.parse(spb.tglAntarBuah)),
                          ),
                          _buildDetailRow(
                            'Mill Tujuan',
                            spb.millTujuanName ?? spb.millTujuan,
                          ),
                          // _buildDetailRow('Status', _getStatusText(spb.status)),
                          // if (spb.keterangan != null &&
                          //     spb.keterangan!.isNotEmpty)
                          //   _buildDetailRow(
                          //     'Keterangan',
                          //     spb.keterangan ?? 'N/A',
                          //   ),
                          _buildDetailRow(
                            'Supir',
                            spb.driverName ?? spb.driver ?? 'N/A',
                          ),
                          _buildDetailRow('No Polisi', spb.noPolisi ?? 'N/A'),
                          _buildDetailRow(
                            'Jumlah Janjang',
                            spb.jumJjg ?? 'N/A',
                          ),
                          _buildDetailRow('Brondolan', spb.brondolan ?? 'N/A'),
                          _buildDetailRow(
                            'Total Berat Taksasi',
                            spb.totBeratTaksasi ?? 'N/A',
                          ),
                          // _buildDetailRow(
                          //   'Synced',
                          //   spb.isSynced ? 'Yes' : 'No',
                          // ),
                          if (!spb.isSynced) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.sync_problem,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Not synced with server',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'This data is stored locally and will be synced when online',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showQrCodeModal(context, spb),
                          icon: const Icon(Icons.qr_code, size: 16),
                          label: const Text('Generate QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  int? _getSortColumnIndex() {
    switch (_sortColumn) {
      case 'noSpb':
        return 0;
      case 'tglAntarBuah':
        return 1;
      case 'millTujuan':
        return 3;
      case 'status':
        return 4;
      default:
        return 1; // Default to tglAntarBuah
    }
  }
}
