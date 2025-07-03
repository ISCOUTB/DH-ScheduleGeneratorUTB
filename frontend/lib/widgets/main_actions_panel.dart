import 'package:flutter/material.dart';

class MainActionsPanel extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onClear;
  final VoidCallback onGenerate;

  const MainActionsPanel({
    Key? key,
    required this.onSearch,
    required this.onFilter,
    required this.onClear,
    required this.onGenerate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _MainCardButton(
                    color: const Color(0xFF0051FF),
                    icon: Icons.search,
                    label: "Buscar materia",
                    onTap: onSearch)),
            const SizedBox(width: 20),
            Expanded(
                child: _MainCardButton(
                    color: const Color(0xFF0051FF),
                    icon: Icons.filter_alt,
                    label: "Realizar filtro",
                    onTap: onFilter)),
            const SizedBox(width: 20),
            Expanded(
                child: _MainCardButton(
                    color: const Color(0xFFFF2F2F),
                    icon: Icons.delete_outline,
                    label: "Limpiar Horarios",
                    onTap: onClear)),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8CFF62),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: onGenerate,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Generar Horarios",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Icon(Icons.calendar_month, color: Colors.black),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _MainCardButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MainCardButton(
      {required this.color,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  State<_MainCardButton> createState() => _MainCardButtonState();
}

class _MainCardButtonState extends State<_MainCardButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color hoverColor = widget.color.withOpacity(0.8);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: _isHovered ? hoverColor : widget.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}