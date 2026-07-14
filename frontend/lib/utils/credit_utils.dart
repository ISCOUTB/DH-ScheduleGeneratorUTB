// lib/utils/credit_utils.dart

/// Créditos de una materia tal como los publica Banner: pueden ser
/// fraccionarios (ej. 0.5), así que se manejan como `double` en toda la app.
///
/// El backend los envía como número JSON (int o double según el valor), y los
/// horarios destacados guardados antes de este cambio los tienen como int.
double parseCredits(dynamic value) => (value as num?)?.toDouble() ?? 0.0;

/// Suma de créditos redondeada a 2 decimales, para que acumular medios créditos
/// no arrastre error de coma flotante (19.499999999 en vez de 19.5).
double roundCredits(double credits) => (credits * 100).round() / 100;

/// Texto de créditos para la interfaz: sin decimales cuando es entero
/// (`3`), con ellos cuando no lo es (`0.5`, `4.25`).
String formatCredits(num credits) {
  final value = credits.toDouble();
  if ((value - value.roundToDouble()).abs() < 0.001) {
    return value.round().toString();
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
