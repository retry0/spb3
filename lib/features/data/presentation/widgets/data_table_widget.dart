import 'package:flutter/material.dart';

class DataTableWidget extends StatefulWidget {
  const DataTableWidget({super.key});

  @override
  State<DataTableWidget> createState() => _DataTableWidgetState();
}

class _DataTableWidgetState extends State<DataTableWidget> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  final List<Map<String, dynamic>> _data = [
    {'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'status': 'Active', 'created': '2024-01-15'},
    {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com', 'status': 'Inactive', 'created': '2024-01-14'},
    {'id': 3, 'name': 'Bob Wilson', 'email': 'bob@example.com', 'status': 'Active', 'created': '2024-01-13'},
    {'id': 4, 'name': 'Alice Brown', 'email': 'alice@example.com', 'status': 'Pending', 'created': '2024-01-12'},
    {'id': 5, 'name': 'Charlie Davis', 'email': 'charlie@example.com', 'status': 'Active', 'created': '2024-01-11'},
  ];

  void _sort<T>(Comparable<T> Function(Map<String, dynamic>) getField, int columnIndex, bool ascending) {
    _data.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PaginatedDataTable(
        header: const Text('Data Records'),
        rowsPerPage: 10,
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        columns: [
          DataColumn(
            label: const Text('ID'),
            numeric: true,
            onSort: (columnIndex, ascending) => _sort<num>((d) => d['id'], columnIndex, ascending),
          ),
          DataColumn(
            label: const Text('Name'),
            onSort: (columnIndex, ascending) => _sort<String>((d) => d['name'], columnIndex, ascending),
          ),
          DataColumn(
            label: const Text('Email'),
            onSort: (columnIndex, ascending) => _sort<String>((d) => d['email'], columnIndex, ascending),
          ),
          DataColumn(
            label: const Text('Status'),
            onSort: (columnIndex, ascending) => _sort<String>((d) => d['status'], columnIndex, ascending),
          ),
          DataColumn(
            label: const Text('Created'),
            onSort: (columnIndex, ascending) => _sort<String>((d) => d['created'], columnIndex, ascending),
          ),
          const DataColumn(label: Text('Actions')),
        ],
        source: _DataTableSource(_data),
      ),
    );
  }
}

class _DataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> _data;

  _DataTableSource(this._data);

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    
    final item = _data[index];
    return DataRow(
      cells: [
        DataCell(Text(item['id'].toString())),
        DataCell(Text(item['name'])),
        DataCell(Text(item['email'])),
        DataCell(_StatusChip(status: item['status'])),
        DataCell(Text(item['created'])),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _editItem(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                onPressed: () => _deleteItem(item),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editItem(Map<String, dynamic> item) {
    // Implement edit functionality
  }

  void _deleteItem(Map<String, dynamic> item) {
    // Implement delete functionality
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'inactive':
        color = Colors.red;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}