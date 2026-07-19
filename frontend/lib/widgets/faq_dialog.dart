// lib/widgets/faq_dialog.dart
import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Una pregunta con su respuesta.
class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}

/// Diálogo de Preguntas frecuentes: acordeón (ExpansionTile) sobre la página
/// actual, sin navegar ni salir de la app. El contenido está hardcodeado; si
/// alguna vez hay que editarlo sin redeploy, se puede mover a un endpoint.
class FaqDialog extends StatelessWidget {
  const FaqDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        builder: (_) => const FaqDialog(),
      );

  static const List<_Faq> _faqs = [
    _Faq(
      '¿Por qué no aparece mi materia en el buscador?',
      'Puede ser un error de escritura (el buscador es por palabras, prueba '
          'con otro término) o que el curso se haya llenado: cuando eso pasa, '
          'Banner deja de listarlo por completo (no aparece como "cerrado", '
          'simplemente desaparece de su sistema), y como nosotros sincronizamos '
          'directo de Banner, también desaparece de aquí. Antes de asumir un '
          'error, verifica manualmente en Banner; si ahí sí aparece con cupos, '
          'repórtanos el caso.',
    ),
    _Faq(
      '¿Qué es un curso personalizado?',
      'Es un curso que tú declaras para que el generador lo use como si '
          'fuera parte de la oferta. Sirve sobre todo para fijar un curso que '
          'ya matriculaste o decidiste y que ya no está disponible, aunque '
          'también puedes usarlo para reservar una variación que quieras '
          'respetar.',
    ),
    _Faq(
      'Quiero un profesor en específico. ¿Cómo hago?',
      'Usa el filtro de profesor de esa materia para elegir con quién '
          'quieres generar el horario.',
    ),
    _Faq(
      '¿Cómo creo un curso personalizado?',
      'Toca "Crear curso", elige la materia del catálogo, marca sus horas en '
          'la grilla y, si quieres, agrega nombre, profesor o NRC. Al crearlo, la '
          'materia entra a tu lista de trabajo con el curso activo.',
    ),
    _Faq(
      'Quiero tener un día libre. ¿Cómo hago?',
      'Si ya sabes qué día quieres libre, usa el filtro de horario por día y '
          'bloquea esas horas para tus materias. Si no tienes un día en mente '
          'pero quieres priorizar tener alguno libre, activa el optimizador '
          'de días libres para que te muestre primero los horarios que dejan '
          'más días sin clases. Si no aparecen de primero, es porque no hay '
          'ninguna combinación posible con lo que has elegido (filtros, '
          'materias, etc.).',
    ),
    _Faq(
      'El curso que matriculé se llenó y ya no aparece en la oferta, pero '
          'quiero explorar otras variantes de horario. ¿Cómo hago?',
      'Créalo como curso personalizado: eso le dice al generador que arme el '
          'resto de tu horario alrededor de ese curso, igual que si siguiera '
          'en la oferta (ver la pregunta "¿Cómo creo un curso personalizado?").',
    ),
    _Faq(
      'No quiero tener muchos huecos entre clases. ¿Cómo hago?',
      'Activa el optimizador de huecos ("Menos huecos") para que el '
          'generador priorice los horarios con menos horas libres entre una '
          'clase y otra.',
    ),
    _Faq(
      '¿Puedo poner cualquier NRC a mi curso personalizado?',
      'El NRC es opcional y de 4 dígitos. Cada curso de la oferta tiene un NRC '
          'único, así que si el que escribes ya existe, ese curso está en la oferta '
          '(o te equivocaste al digitarlo): usa otro o déjalo vacío.',
    ),
    _Faq(
      '¿Cómo fijo un NRC específico y armo mi horario con base en él?',
      'Si ese NRC sigue en la oferta, selecciónalo en el filtro de NRC de su '
          'materia. Si ya no está disponible, créalo como curso personalizado '
          'con ese mismo NRC (si lo recuerdas) para fijarlo igual.',
    ),
    _Faq(
      '¿Cómo guardo un horario para no perderlo?',
      'Márcalo como horario destacado (favorito). Desde ahí puedes '
          'revisarlo cuando quieras y ver el estado de cupos en vivo de sus '
          'cursos.',
    ),
    _Faq(
      'Activé un curso personalizado y desaparecieron los cursos reales de esa '
          'materia. ¿Por qué?',
      'Es a propósito: mientras un curso personalizado esté activo, esa '
          'materia se combina solo con él, no con los cursos reales, para '
          'respetar el que fijaste. Desactívalo con el switch para volver a '
          'combinar con la oferta actual.',
    ),
    _Faq(
      '¿Qué significan los colores de cupos (modo "Estado" y horarios '
          'destacados)?',
      'Cada clase se colorea según sus cupos: verde = seguro, naranja = '
          'precaución, rojo = en riesgo, gris = sin cupos o ya no está en la '
          'oferta. Los cursos personalizados no tienen cupos, así que nunca '
          'se marcan en riesgo.',
    ),
    _Faq(
      '¿Por qué algunos bloques del horario tienen borde y relleno más claro?',
      'Así se marca un curso personalizado: conserva el color de su materia '
          'pero con relleno translúcido y borde, para distinguirlo de los cursos '
          'reales (también en los horarios destacados).',
    ),
    _Faq(
      '¿Cada cuánto se actualiza la oferta y los cupos?',
      'Los datos se sincronizan automáticamente con Banner cada ~10 minutos. '
          'Durante el período de matrícula, se actualiza cada ~6 minutos.',
    ),
    _Faq(
      'Si quito la materia, ¿se borra mi curso personalizado?',
      'No. Los cursos personalizados se guardan por usuario y materia. '
          'Quitar la materia solo la saca de la generación; el curso sigue '
          'en el panel y reaparece al volver a agregarla.',
    ),
    _Faq(
      'Creo que encontré un error. ¿Cómo lo reporto?',
      'Puedes reportar el error a través de la opción correspondiente '
          '("Reportar Error") o escribirnos directamente por WhatsApp al '
          '3122854525 o al 3245437640.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Alto FIJO: el diálogo no cambia de tamaño al abrir/cerrar una respuesta;
    // la lista scrollea por dentro. Se acota al 80% de la pantalla en móvil.
    final double h =
        (MediaQuery.of(context).size.height * 0.8).clamp(360.0, 560.0);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, minHeight: h, maxHeight: h),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Preguntas frecuentes',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _faqs.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, i) {
                    final f = _faqs[i];
                    return ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      iconColor: AppColors.primary,
                      title: Text(
                        f.q,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      children: [
                        Text(
                          f.a,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.grey.shade800),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 16),
              // Pie fijo: contacto para dudas que no estén en la lista.
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 8, top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Si tu duda, pregunta o inquietud no se encuentra '
                        'registrada, escríbenos al 3245437640 o al 3122854525'
                        'y gustosamente aclararemos tu duda.',
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Colors.grey.shade700),
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
}
