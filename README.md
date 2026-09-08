# Reading Marathon

Mod de Project Zomboid (Build 42) que agrega la opción **"Maratón de lectura"**
al lado de "Leer" en el menú contextual de cualquier libro/revista.

## Qué hace

- El personaje tiene que estar **sentado en un sillón o sofá** (chico o grande).
- Lee **solo lo que deja algo permanente**: libros de skill (multiplicador de
  XP) primero y libros de recetas después. Los comics, revistas y novelas que
  solo quitan aburrimiento **no** entran en la maratón.
- **Excepción**: si durante la maratón el personaje se aburre mucho
  (`BOREDOM >= 0.60`, ~"Very Bored") y tiene algo de ocio a mano, se toma un
  respiro y lee eso; después vuelve a los libros importantes. Elige el que más
  aburrimiento saca.
- Salta lo que no aporta nada: libros ya terminados, demasiado difíciles para el
  nivel actual, ya superados, recetas ya aprendidas y lecturas hechas hace poco.
- La maratón termina cuando no quedan libros importantes, aunque sobre ocio.
- Mientras dura la maratón, **corta la lectura apenas aparece el hambre o la
  sed**, come o bebe, y retoma el mismo libro donde lo dejó. La sed va primero
  porque aprieta más rápido.
  - **Comida**: solo snacks (chocolates, papas fritas, galletitas, caramelos).
    Elige el más contundente que tenga a mano.
  - **Agua**: cualquier envase con agua no contaminada; elige el que menos
    tenga, para ir vaciando los que están por la mitad, y toma solo lo que
    necesita para la sed.
- La maratón se corta si el personaje se levanta, se queda sin luz para leer, se
  duerme o si el jugador interrumpe la acción. También se puede detener a mano
  con la opción "Detener maratón de lectura".

## Detección del sillón

En B42 los sofás tienen `CustomName = Couch` y tanto sofás como sillones
individuales tienen `BedType = averageBed`, mientras que las sillas de comedor y
los bancos usan `badBed` / `badChair`. El mod usa eso, más el nombre del sprite
como último recurso para muebles de otros mods.

Si querés permitir cualquier asiento, poné en la consola o en un mod aparte:

```lua
ReadingMarathon.requireComfySeat = false
```

## Configuración rápida

En `42/media/lua/client/ReadingMarathon/ReadingMarathon_Core.lua`:

| Variable | Default | Qué hace |
| --- | --- | --- |
| `RM.hungerThreshold` | `0.22` | Hambre (0..1) a partir de la cual come. |
| `RM.requireComfySeat` | `true` | Exigir sillón en vez de cualquier asiento. |
| `RM.checkEveryTicks` | `10` | Cada cuántos ticks revisa el estado. |
| `RM.thirstThreshold` | `0.30` | Sed (0..1) a partir de la cual toma agua. |
| `RM.maxNeedFails` | `3` | Intentos fallidos de comer/beber antes de rendirse. |
| `RM.interruptToSatisfyNeeds` | `true` | Cortar el libro en curso para comer o beber. |
| `RM.includeRecipeBooks` | `true` | Contar libros de recetas como importantes. |
| `RM.boredomThreshold` | `0.60` | Aburrimiento (0..1) para permitir leer ocio. |

Otros mods pueden sumar snacks propios:

```lua
ReadingMarathon.SNACK_TYPES["Base.MiSnack"] = true
```

## Instalación (local)

Copiar la carpeta a `%USERPROFILE%\Zomboid\mods\ReadingMarathon` y activarla
desde el menú de mods.

```powershell
Copy-Item -Recurse -Force . "$env:USERPROFILE\Zomboid\mods\ReadingMarathon"
```

## Estructura

```
42/
  mod.info
  poster.png                         -- imagen grande del panel de mods (512x290)
  icon.png                           -- icono de la lista de mods (256x256)
  media/lua/client/ReadingMarathon/
    ReadingMarathon_Core.lua         -- estado, sillones, selección de libros
    ReadingMarathon_Snacks.lua       -- qué cuenta como snack y cuál elegir
    ReadingMarathon_Session.lua      -- motor: cola de acciones + hambre
    ReadingMarathon_ContextMenu.lua  -- opción del menú contextual
  media/lua/shared/Translate/        -- EN, ES, ES_MX, ES_CL
```

## Imagen del mod

`poster.png` e `icon.png` se generan a partir de `ReadingMarathon_icon.jpg`
(fuente, fuera de la carpeta `42/`). El juego necesita **PNG**, y en `mod.info`
las rutas se resuelven relativas a la carpeta de versión:

```
poster=poster.png
icon=icon.png
```

Para regenerarlas si cambia el original: recorte cuadrado centrado a 256x256
para el icono, y la imagen completa escalada a 512 de ancho para el poster.
