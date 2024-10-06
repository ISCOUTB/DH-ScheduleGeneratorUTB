str = " MartesLunMarMiéJueVieSábDom13:00 - 14:50 Tipo: CLASE Edificio: ED. AULAS 4 Salón: A4-204 Fecha de inicio: 29/07/2024 Fecha de fin: 23/11/2024JuevesLunMarMiéJueVieSábDom13:00 - 14:50 Tipo: CLASE Edificio: ED. AULAS 4 Salón: A4-204 Fecha de inicio: 29/07/2024 Fecha de fin: 23/11/2024"
str = str.replace("LunMarMiéJueVieSábDom", " ")
#Martes 13:00 - 14:50 Tipo: CLASE Edificio: ED. AULAS 4 Salón: A4-204 Fecha de inicio: 29/07/2024 Fecha de fin: 23/11/2024Jueves 13:00 - 14:50 Tipo: CLASE Edificio: ED. AULAS 4 Salón: A4-204 Fecha de inicio: 29/07/2024 Fecha de fin: 23/11/2024
str = str.replace("2024", "Tipo")
str = str.split("Tipo")
for i in range(0,len(str),3):
    print(str[i])



