import 'package:flutter/material.dart';
import 'dart:math' as math;

class SpbPaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const SpbPaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
            tooltip: 'First Page',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
            tooltip: 'Previous Page',
          ),
          const SizedBox(width: 8),
          _buildPageNumbers(context),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
            tooltip: 'Next Page',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed:
                currentPage < totalPages
                    ? () => onPageChanged(totalPages)
                    : null,
            tooltip: 'Last Page',
          ),
        ],
      ),
    );
  }

  Widget _buildPageNumbers(BuildContext context) {
    // For small number of pages, show all
    if (totalPages <= 7) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(totalPages, (index) {
          final pageNumber = index + 1;
          return _buildPageButton(context, pageNumber);
        }),
      );
    }

    // For larger number of pages, show a subset with ellipsis
    final List<Widget> pageButtons = [];

    // Always show first page
    pageButtons.add(_buildPageButton(context, 1));

    // Show ellipsis if needed
    if (currentPage > 3) {
      pageButtons.add(const Text('...'));
    }

    // Show pages around current page
    for (
      int i = math.max(2, currentPage - 1);
      i <= math.min(totalPages - 1, currentPage + 1);
      i++
    ) {
      pageButtons.add(_buildPageButton(context, i));
    }

    // Show ellipsis if needed
    if (currentPage < totalPages - 2) {
      pageButtons.add(const Text('...'));
    }

    // Always show last page
    if (totalPages > 1) {
      pageButtons.add(_buildPageButton(context, totalPages));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: pageButtons);
  }

  Widget _buildPageButton(BuildContext context, int pageNumber) {
    final isCurrentPage = pageNumber == currentPage;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: isCurrentPage ? null : () => onPageChanged(pageNumber),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isCurrentPage
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  isCurrentPage
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            pageNumber.toString(),
            style: TextStyle(
              color:
                  isCurrentPage
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
              fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
