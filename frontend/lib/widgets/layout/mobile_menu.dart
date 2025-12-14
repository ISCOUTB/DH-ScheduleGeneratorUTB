// lib/widgets/layout/mobile_menu.dart
import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// Menú desplegable para la vista móvil.
class MobileMenu extends StatelessWidget {
  /// Lista de items del menú.
  final List<MobileMenuItem> items;

  /// Callback cuando se cierra el menú.
  final VoidCallback? onClose;

  const MobileMenu({
    Key? key,
    required this.items,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.primary,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildMenuItems(),
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final List<Widget> widgets = [];
    
    for (int i = 0; i < items.length; i++) {
      widgets.add(_MobileMenuItemWidget(item: items[i]));
      
      // Agregar divisor entre items (excepto después del último)
      if (i < items.length - 1) {
        widgets.add(const Divider(color: Colors.white24, height: 1, thickness: 1));
      }
    }
    
    return widgets;
  }
}

/// Modelo de datos para un item del menú móvil.
class MobileMenuItem {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const MobileMenuItem({
    required this.label,
    required this.onTap,
    this.icon,
  });
}

class _MobileMenuItemWidget extends StatelessWidget {
  final MobileMenuItem item;

  const _MobileMenuItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
