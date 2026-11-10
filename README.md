# CharTracker

**Addon de gestión y seguimiento de personajes para World of Warcraft 3.3.5a (Wrath of the Lich King).**

CharTracker permite consultar y organizar información de múltiples personajes desde una única interfaz, facilitando el seguimiento de recursos, profesiones, monedas, estadísticas PvP y bloqueos de bandas.

Diseñado con una interfaz minimalista en escala de grises, priorizando la organización, la legibilidad y la facilidad de uso.

## Características

### Personajes
- Registro automático de personajes al iniciar sesión.
- Información de nivel, clase, hermandad y equipamiento.
- Colores identificativos de cada clase.
- Organización manual del orden de los personajes.

### Oro y oficios
- Seguimiento del oro, plata y cobre de cada personaje.
- Consulta de premios de cocina y fichas de joyería de Dalaran.

### Profesiones
- Seguimiento de profesiones principales y secundarias.
- Visualización de niveles de habilidad.
- Colores diferenciados según el rango de profesión.
- Registro de equitación.

### Emblemas
Seguimiento de emblemas de Escarcha, Triunfo, Conquista, Valor y Heroísmo.

### PvP
- Puntos de honor.
- Puntos de arena.
- Total de muertes honorables.

### Bandas
Consulta de bloqueos activos de bandas:

- Ciudadela de la Corona de Hielo (ICC).
- Cámara de Archavon (VoA).
- Sagrario Rubí (RS).
- Prueba del Cruzado (ToC).
- Prueba del Gran Cruzado (ToGC).

Compatible con modalidades de 10 y 25 jugadores.

### Notas
- Dos pizarras independientes.
- Guardado automático.
- Límite de 1.200 unidades de texto por pizarra.
- Contadores de escritura individuales.

### DKP global
Campo editable para llevar un registro de DKP compartido entre los personajes de una misma cuenta.

## Interfaz

CharTracker incorpora una interfaz de tonos grises con tablas organizadas, desplazamiento de personajes, botones rectangulares y acceso rápido desde el minimapa.

Incluye un botón de guía con información sobre las funciones y comandos del addon.

## Instalación

1. Descarga la versión disponible desde GitHub.
2. Extrae la carpeta `CharTracker`.
3. Copia la carpeta en `World of Warcraft/Interface/AddOns/`.
4. Inicia World of Warcraft 3.3.5a.
5. Activa el addon desde la selección de personajes si fuera necesario.

## Comandos

| Comando | Función |
|---|---|
| `/ct` | Abrir CharTracker |
| `/chartracker` | Abrir CharTracker |
| `/ctsave` | Actualizar los datos del personaje |
| `/emblems` | Acceso al seguimiento de emblemas |
| `/ctdebug` | Mostrar información de diagnóstico |
| `/ctguild` | Comprobar la detección de hermandad |

## Almacenamiento de datos

CharTracker utiliza el sistema de **SavedVariables** de World of Warcraft.

Los datos se almacenan localmente y se mantienen separados por cuenta de WoW. El addon no transmite información a servidores externos ni sincroniza automáticamente datos entre diferentes cuentas u ordenadores.

Para compartir el addon con otras personas, basta con distribuir su carpeta de instalación, sin incluir los archivos personales de `WTF`.

## Compatibilidad

- **Juego:** World of Warcraft
- **Expansión:** Wrath of the Lich King
- **Versión:** 3.3.5a
- **Interface:** 30300
- **Idioma:** Español

## Desarrollo

**Autor:** Comunaxo

**Repositorio:** https://github.com/Dicktian

**Versión:** 1.3-3.3.5aa

Proyecto independiente, desarrollado para facilitar la administración de personajes en World of Warcraft 3.3.5a.

---

© Comunaxo
