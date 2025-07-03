import 'package:flutter/material.dart';
import '../models/subject.dart';

class SubjectsPanel extends StatelessWidget {
  final bool isFullExpandedView;
  final List<Subject> addedSubjects;
  final int usedCredits;
  final int creditLimit;
  final Color Function(int) getSubjectColor;
  final VoidCallback onShowPanel;
  final VoidCallback onHidePanel;
  final VoidCallback onAddSubject;
  final VoidCallback onToggleExpandView;
  final Function(Subject) onRemoveSubject;
  final bool isExpandedView;

  const SubjectsPanel({
    Key? key,
    required this.isFullExpandedView,
    required this.addedSubjects,
    required this.usedCredits,
    required this.creditLimit,
    required this.getSubjectColor,
    required this.onShowPanel,
    required this.onHidePanel,
    required this.onAddSubject,
    required this.onToggleExpandView,
    required this.onRemoveSubject,
    required this.isExpandedView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isFullExpandedView ? 60 : 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      padding: isFullExpandedView
          ? const EdgeInsets.only(top: 12)
          : const EdgeInsets.all(20),
      child: isFullExpandedView
          ? _buildCollapsedView()
          : _buildExpandedView(),
    );
  }

  Widget _buildCollapsedView() {
    return Column(
      children: [
        const SizedBox(height: 4),
        Center(
          child: Tooltip(
            message: "Mostrar panel",
            child: IconButton(
              icon: const Icon(Icons.chevron_left,
                  size: 32, color: Colors.black54),
              onPressed: onShowPanel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Materias seleccionadas",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: "Encoger panel",
              icon: const Icon(Icons.chevron_right,
                  size: 32, color: Colors.black54),
              onPressed: onHidePanel,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ...addedSubjects.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final subject = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: getSubjectColor(idx),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(subject.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove, color: Colors.red),
                        onPressed: () => onRemoveSubject(subject),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onAddSubject,
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar materia"),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: onToggleExpandView,
              icon: Icon(
                  isExpandedView ? Icons.fullscreen_exit : Icons.fullscreen),
              label: Text(isExpandedView ? "Vista Normal" : "Expandir Vista"),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: "Créditos: ",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  TextSpan(
                    text: "$usedCredits/$creditLimit",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2979FF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}