import 'package:flutter/material.dart';

/// Un botón de menú de usuario que muestra un overlay con información y un botón de cierre de sesión.
class UserMenuButton extends StatefulWidget {
  /// El nombre del usuario a mostrar en el menú.
  final String? userName;

  /// Callback que se ejecuta cuando el usuario presiona el botón de cerrar sesión.
  final VoidCallback onLogout;
  const UserMenuButton(
      {Key? key, required this.userName, required this.onLogout})
      : super(key: key);

  @override
  State<UserMenuButton> createState() => _UserMenuButtonState();
}

/// Estado para el [UserMenuButton].
class _UserMenuButtonState extends State<UserMenuButton> {
  /// La entrada del overlay que contiene el menú.
  OverlayEntry? _overlayEntry;

  /// Enlace para posicionar el overlay relativo al botón.
  final LayerLink _layerLink = LayerLink();

  /// Muestra el menú de usuario como un overlay.
  void _showMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  /// Oculta el menú de usuario.
  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Crea la entrada del overlay para el menú.
  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideMenu,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx - 10,
              top: offset.dy + size.height + 5,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7), // Fondo gris claro
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Contenedor del mensaje de bienvenida
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: '¡Hola, ',
                                      style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
                                    ),
                                    TextSpan(
                                      text: widget.userName != null ? '${widget.userName}!' : 'Usuario!',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Bienvenido al generador de horarios.', style: TextStyle(fontSize: 14)),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Botón para cerrar sesión
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF2F2F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () {
                              _hideMenu();
                              widget.onLogout();
                            },
                            child: const Text('Cerrar Sesión',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideMenu(); // Asegura que el menú se oculte al destruir el widget.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// Construye el botón circular con un ícono de persona.
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            // Muestra u oculta el menú al hacer clic.
            if (_overlayEntry == null) {
              _showMenu();
            } else {
              _hideMenu();
            }
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF8CFF62),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(Icons.person, color: Colors.white, size: 25),
          ),
        ),
      ),
    );
  }
}