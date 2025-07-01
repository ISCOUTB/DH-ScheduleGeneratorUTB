def insertar_datos(conn, datos):
    cursor = conn.cursor()

    for m in datos['materias']:
        cursor.execute("INSERT INTO Materia VALUES (%s, %s, %s)", m)

    for p in datos['profesores']:
        cursor.execute("INSERT INTO Profesor VALUES (%s, %s)", p)

    # Separa cursos teóricos y laboratorios
    cursos_teoricos = [c for c in datos['cursos'] if c[1] == "Teórico"]
    cursos_lab = [c for c in datos['cursos'] if c[1] == "Laboratorio"]

    # Insertar teóricos primero
    for c in cursos_teoricos:
        cursor.execute("""
            INSERT INTO Curso (NRC, Tipo, CodigoMateria, ProfesorID, NRCTeorico, GroupID)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, c)

    # Luego insertar laboratorios
    for c in cursos_lab:
        cursor.execute("""
            INSERT INTO Curso (NRC, Tipo, CodigoMateria, ProfesorID, NRCTeorico, GroupID)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, c)

    for cl in datos['clases']:
        cursor.execute("""
            INSERT INTO Clase (NRC, HoraInicio, HoraFinal, Aula, Dia)
            VALUES (%s, %s, %s, %s, %s)
        """, cl)

    conn.commit()
    print("Datos insertados correctamente.")
