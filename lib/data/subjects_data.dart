// lib/data/subjects_data.dart
import '../models/subject.dart';
import '../models/class_option.dart';
import '../models/schedule.dart';

List<Subject> subjects = [
  // Física Mecánica
  Subject(
    code: 'F01A',
    name: 'Física Mecánica',
    credits: 4,
    classOptions: [
      // Grupo 1
      ClassOption(
        type: 'Teórico',
        subjectName: 'Física Mecánica',
        credits: 4,
        schedules: [
          Schedule(day: 'Martes', time: '10:00 - 11:50'),
          Schedule(day: 'Jueves', time: '15:00 - 16:50'),
        ],
        professor: 'Vilma',
        nrc: '1001',
        groupId: 1,
      ),
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Laboratorio',
        credits: 4,
        schedules: [
          Schedule(day: 'Lunes', time: '13:00 - 14:50'),
        ],
        professor: 'Kevin Mendoza',
        nrc: '1002',
        groupId: 1,
      ),
      // Grupo 2
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Teórico',
        credits: 4,
        schedules: [
          Schedule(day: 'Martes', time: '10:00 - 11:50'),
          Schedule(day: 'Miércoles', time: '10:00 - 11:50'),
        ],
        professor: 'Yony Pastrana',
        nrc: '1003',
        groupId: 2,
      ),
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Laboratorio',
        credits: 4,
        schedules: [
          Schedule(day: 'Viernes', time: '15:00 - 16:50'),
        ],
        professor: 'Aris Daniela',
        nrc: '1004',
        groupId: 2,
      ),
      // Grupo 3
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Teórico',
        credits: 4,
        schedules: [
          Schedule(day: 'Lunes', time: '09:00 - 10:50'),
          Schedule(day: 'Viernes', time: '13:00 - 14:50'),
        ],
        professor: 'Yony Pastrana',
        nrc: '1005',
        groupId: 3,
      ),
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Laboratorio',
        credits: 4,
        schedules: [
          Schedule(day: 'Martes', time: '13:00 - 14:50'),
        ],
        professor: 'Kevin Mendoza',
        nrc: '1006',
        groupId: 3,
      ),
      // Grupo 4
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Teórico',
        credits: 4,
        schedules: [
          Schedule(day: 'Jueves', time: '15:00 - 16:50'),
          Schedule(day: 'Martes', time: '17:00 - 18:50'),
        ],
        professor: 'Elias Imitola',
        nrc: '1007',
        groupId: 4,
      ),
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Laboratorio',
        credits: 4,
        schedules: [
          Schedule(day: 'Miércoles', time: '10:00 - 11:50'),
        ],
        professor: 'Aris Daniela',
        nrc: '1008',
        groupId: 4,
      ),
    ],
  ),

  // Cálculo Integral
  Subject(
    code: 'M03A',
    name: 'Cálculo Integral',
    credits: 4,
    classOptions: [
      // Teórico - Eder Barrios (Grupo 1)
      ClassOption(
        subjectName: 'Cálculo Integral',
        type: 'Teórico',
        credits: 4,
        schedules: [
          Schedule(day: 'Martes', time: '07:00 - 08:50'),
        ],
        professor: 'Eder Barrios',
        nrc: '2001',
        groupId: 1,
      ),
      // Laboratorios asociados a Eder Barrios (Grupo 1)
      ClassOption(
        subjectName: 'Cálculo Integral',
        type: 'Laboratorio',
        credits: 4,
        schedules: [
          Schedule(day: 'Jueves', time: '16:00 - 17:50'),
        ],
        professor: 'Deimer Zambrano',
        nrc: '2002',
        groupId: 1,
      ),
      ClassOption(
        subjectName: 'Cálculo Integral',
        type: 'Laboratorio',
        credits: 4,
        schedules: [
          Schedule(day: 'Miércoles', time: '10:00 - 11:50'),
        ],
        professor: 'Cesar Serna',
        nrc: '2003',
        groupId: 1,
      ),
      // Teórico - Carlos Payares (Grupo 2)
      ClassOption(
        subjectName: 'Cálculo Integral',
        type: 'Teórico',
        credits: 4,
        schedules: [
          Schedule(day: 'Martes', time: '13:00 - 14:50'),
        ],
        professor: 'Carlos Payares',
        nrc: '2007',
        groupId: 2,
      ),
      // Laboratorios asociados a Carlos Payares (Grupo 2)
      ClassOption(
        subjectName: 'Cálculo Integral',
        type: 'Laboratorio',
        credits: 4,
        schedules: [
          Schedule(day: 'Jueves', time: '10:00 - 11:50'),
        ],
        professor: 'Cesar Serna',
        nrc: '2008',
        groupId: 2,
      ),
      // Teórico - Moisés Quintana (Grupo 3)
      ClassOption(
        subjectName: 'Cálculo Integral',
        type: 'Teórico',
        credits: 4,
        schedules: [
          Schedule(day: 'Martes', time: '10:00 - 11:50'),
        ],
        professor: 'Moisés Quintana',
        nrc: '2014',
        groupId: 3,
      ),
      // Laboratorios asociados a Moisés Quintana (Grupo 3)
      ClassOption(
        subjectName: 'Cálculo Integral',
        type: 'Laboratorio',
        credits: 4,
        schedules: [
          Schedule(day: 'Miércoles', time: '14:00 - 15:50'),
        ],
        professor: 'Moisés Quintana',
        nrc: '2018',
        groupId: 3,
      ),
    ],
  ),
  // Inglés 1
  Subject(
    code: 'I01A',
    name: 'Inglés 1',
    credits: 2,
    classOptions: [
      // Grupo 1
      ClassOption(
        subjectName: 'Inglés 1',
        type: 'Teórico',
        credits: 2,
        schedules: [
          Schedule(day: 'Lunes', time: '07:00 - 07:50'),
          Schedule(day: 'Miércoles', time: '07:00 - 07:50'),
          Schedule(day: 'Jueves', time: '07:00 - 07:50'),
          Schedule(day: 'Viernes', time: '07:00 - 07:50'),
        ],
        professor: 'Gilsy Martínez Polo',
        nrc: '3001',
        groupId: 1,
      ),
      // Grupo 2
      ClassOption(
        subjectName: 'Inglés 1',
        type: 'Teórico',
        credits: 2,
        schedules: [
          Schedule(day: 'Lunes', time: '10:00 - 10:50'),
          Schedule(day: 'Martes', time: '10:00 - 10:50'),
          Schedule(day: 'Jueves', time: '10:00 - 10:50'),
          Schedule(day: 'Viernes', time: '10:00 - 10:50'),
        ],
        professor: 'Eilin Pérez',
        nrc: '3002',
        groupId: 2,
      ),
      // Grupo 3
      ClassOption(
        subjectName: 'Inglés 1',
        type: 'Teórico',
        credits: 2,
        schedules: [
          Schedule(day: 'Viernes', time: '18:00 - 20:00'),
          Schedule(day: 'Sábado', time: '08:00 - 10:00'),
        ],
        professor: 'Cindy Paola',
        nrc: '3003',
        groupId: 3,
      ),
    ],
  ),

  // Álgebra Lineal
  Subject(
    code: 'M04A',
    name: 'Álgebra Lineal',
    credits: 3,
    classOptions: [
      // Grupo 1
      ClassOption(
        subjectName: 'Álgebra Lineal',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Martes', time: '09:00 - 09:50'),
          Schedule(day: 'Miércoles', time: '09:00 - 10:50'),
        ],
        professor: 'Jorge Cohen',
        nrc: '4001',
        groupId: 1,
      ),
      // Grupo 2
      ClassOption(
        subjectName: 'Álgebra Lineal',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Jueves', time: '13:00 - 13:50'),
          Schedule(day: 'Viernes', time: '14:00 - 15:50'),
        ],
        professor: 'Victor Hernández',
        nrc: '4002',
        groupId: 2,
      ),
      // Grupo 3
      ClassOption(
        subjectName: 'Álgebra Lineal',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Lunes', time: '09:00 - 10:50'),
          Schedule(day: 'Miércoles', time: '11:00 - 11:50'),
        ],
        professor: 'Adriana Castillo',
        nrc: '4003',
        groupId: 3,
      ),
      // Grupo 4
      ClassOption(
        subjectName: 'Álgebra Lineal',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Lunes', time: '11:00 - 12:50'),
          Schedule(day: 'Jueves', time: '12:00 - 12:50'),
        ],
        professor: 'Diana Escorcia',
        nrc: '4004',
        groupId: 4,
      ),
      // Grupo 5
      ClassOption(
        subjectName: 'Álgebra Lineal',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Viernes', time: '09:00 - 09:50'),
          Schedule(day: 'Martes', time: '10:00 - 11:50'),
        ],
        professor: 'Adriana Castillo',
        nrc: '4005',
        groupId: 5,
      ),
      // Grupo 6
      ClassOption(
        subjectName: 'Álgebra Lineal',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Lunes', time: '13:00 - 14:50'),
          Schedule(day: 'Jueves', time: '16:00 - 16:50'),
        ],
        professor: 'Andy Domínguez',
        nrc: '4006',
        groupId: 6,
      ),
      // Grupo 7
      ClassOption(
        subjectName: 'Álgebra Lineal',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Jueves', time: '14:00 - 15:50'),
          Schedule(day: 'Martes', time: '16:00 - 16:50'),
        ],
        professor: 'Victor Hernández',
        nrc: '4007',
        groupId: 7,
      ),
      // Grupo 8
      ClassOption(
        subjectName: 'Álgebra Lineal',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Viernes', time: '16:00 - 17:50'),
          Schedule(day: 'Miércoles', time: '17:00 - 17:50'),
        ],
        professor: 'John Moreno',
        nrc: '4008',
        groupId: 8,
      ),
    ],
  ),

  // Programación
  Subject(
    code: 'C03A',
    name: 'Programación',
    credits: 3,
    classOptions: [
      // Grupo 1
      ClassOption(
        subjectName: 'Programación',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Jueves', time: '07:00 - 08:50'),
          Schedule(day: 'Viernes', time: '12:00 - 12:50'),
        ],
        professor: 'Julio Gamarra',
        nrc: '5001',
        groupId: 1,
      ),
      // Grupo 2
      ClassOption(
        subjectName: 'Programación',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Viernes', time: '09:00 - 09:50'),
          Schedule(day: 'Lunes', time: '15:00 - 16:50'),
        ],
        professor: 'María Rincón',
        nrc: '5002',
        groupId: 2,
      ),
      // Grupo 3
      ClassOption(
        subjectName: 'Programación',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Viernes', time: '08:00 - 09:50'),
          Schedule(day: 'Miércoles', time: '14:00 - 14:50'),
        ],
        professor: 'María Rincón',
        nrc: '5003',
        groupId: 3,
      ),
      // Grupo 4
      ClassOption(
        subjectName: 'Programación',
        type: 'Teórico',
        credits: 3,
        schedules: [
          Schedule(day: 'Miércoles', time: '13:00 - 14:50'),
          Schedule(day: 'Martes', time: '16:00 - 16:50'),
        ],
        professor: 'Carlos Botero',
        nrc: '5004',
        groupId: 4,
      ),
    ],
  ),
];