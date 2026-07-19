// lib/widgets/common/resources_menu.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// Botón del AppBar que agrupa enlaces externos ("Recursos") en un menú que
/// aparece al **pasar el mouse por encima** y desaparece ~1 s después de salir.
///
/// El retraso (y el hecho de que hover sobre el propio menú lo mantenga abierto)
/// evita que el menú se cierre en el hueco entre el botón y la lista.
class ResourcesMenu extends StatefulWidget {
  final String label;

  /// Etiqueta -> URL, en orden (los `Map` conservan el orden de inserción).
  final Map<String, String> items;

  /// Se llama con la URL al elegir un ítem (normalmente lanza el navegador).
  final void Function(String url) onSelect;

  const ResourcesMenu({
    Key? key,
    required this.label,
    required this.items,
    required this.onSelect,
  }) : super(key: key);

  @override
  State<ResourcesMenu> createState() => _ResourcesMenuState();
}

class _ResourcesMenuState extends State<ResourcesMenu> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();
  Timer? _closeTimer;
  bool _hovered = false;

  static const Duration _closeDelay = Duration(seconds: 1);

  void _open() {
    _closeTimer?.cancel();
    if (!_controller.isShowing) _controller.show();
    if (!_hovered) setState(() => _hovered = true);
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(_closeDelay, () {
      if (mounted) {
        _controller.hide();
        setState(() => _hovered = false);
      }
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _open(),
        onExit: (_) => _scheduleClose(),
        child: OverlayPortal(
          controller: _controller,
          overlayChildBuilder: _buildOverlay,
          child: GestureDetector(
            // En táctil (o clic) también abre/cierra.
            onTap: () => _controller.isShowing ? _controller.hide() : _open(),
            child: _buildTrigger(),
          ),
        ),
      ),
    );
  }

  Widget _buildTrigger() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                decoration:
                    _hovered ? TextDecoration.underline : TextDecoration.none,
                decorationColor: Colors.white,
                decorationThickness: 2,
              ),
            ),
            Icon(_hovered ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.white),
          ],
        ),
      );

  Widget _buildOverlay(BuildContext context) {
    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topLeft,
        child: MouseRegion(
          onEnter: (_) => _open(),
          onExit: (_) => _scheduleClose(),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.items.entries
                    .map((e) => _item(e.key, e.value))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(String label, String url) => InkWell(
        onTap: () {
          _controller.hide();
          setState(() => _hovered = false);
          widget.onSelect(url);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              const Icon(Icons.open_in_new, size: 15, color: Colors.black54),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
          ),
        ),
      );
}
