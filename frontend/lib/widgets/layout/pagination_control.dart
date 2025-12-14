// lib/widgets/layout/pagination_control.dart
import 'package:flutter/material.dart';

/// Control de paginación para la grilla de horarios.
class PaginationControl extends StatelessWidget {
  /// Página actual (1-indexed).
  final int currentPage;

  /// Total de páginas.
  final int totalPages;

  /// Items por página actual.
  final int itemsPerPage;

  /// Total de items.
  final int totalItems;

  /// Opciones disponibles para items por página.
  final List<int> itemsPerPageOptions;

  /// Callback cuando cambia la página.
  final ValueChanged<int> onPageChanged;

  /// Callback cuando cambia items por página.
  final ValueChanged<int> onItemsPerPageChanged;

  const PaginationControl({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
    required this.totalItems,
    this.itemsPerPageOptions = const [4, 8, 10],
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNavigationButtons(),
          const SizedBox(width: 6),
          _buildPageInput(),
          const SizedBox(width: 6),
          _buildNavigationButtonsEnd(),
          _buildSeparator(),
          _buildItemsPerPageSelector(),
          _buildSeparator(),
          _buildTotalCount(),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primera página
        IconButton(
          icon: const Icon(Icons.first_page),
          onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
          color: Colors.white,
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
        const SizedBox(width: 2),
        // Página anterior
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          color: Colors.white,
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
      ],
    );
  }

  Widget _buildNavigationButtonsEnd() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Página siguiente
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
          color: Colors.white,
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
        const SizedBox(width: 2),
        // Última página
        IconButton(
          icon: const Icon(Icons.last_page),
          onPressed: currentPage < totalPages ? () => onPageChanged(totalPages) : null,
          color: Colors.white,
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
      ],
    );
  }

  Widget _buildPageInput() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Página',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 40,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _PageInputField(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: onPageChanged,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'de $totalPages',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsPerPageSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: itemsPerPage,
              isDense: true,
              dropdownColor: Colors.grey[800],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
              items: itemsPerPageOptions.map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value'),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  onItemsPerPageChanged(newValue);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'por página.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 18,
        width: 1,
        color: Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildTotalCount() {
    return Text(
      'Horarios: $totalItems',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}

/// Campo de entrada para el número de página.
class _PageInputField extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _PageInputField({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  State<_PageInputField> createState() => _PageInputFieldState();
}

class _PageInputFieldState extends State<_PageInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPage.toString());
  }

  @override
  void didUpdateWidget(covariant _PageInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _controller.text = widget.currentPage.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 6),
        isDense: true,
      ),
      onSubmitted: (value) {
        final newPage = int.tryParse(value);
        if (newPage != null && newPage >= 1 && newPage <= widget.totalPages) {
          widget.onPageChanged(newPage);
        } else {
          _controller.text = widget.currentPage.toString();
        }
      },
    );
  }
}
