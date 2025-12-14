// lib/widgets/common/nav_link.dart
import 'package:flutter/material.dart';

/// Widget para enlaces de navegación con efecto hover.
/// 
/// Usado en el AppBar para los enlaces externos (Mi UTB, Turnos, etc.).
class NavLink extends StatefulWidget {
  /// Texto del enlace.
  final String text;

  const NavLink({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  State<NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<NavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Text(
        widget.text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
          decorationColor: Colors.white,
          decorationThickness: 2,
        ),
      ),
    );
  }
}
