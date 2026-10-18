# PACIENTE CERO

Juego arcade casual para celulares (Android / iOS), en 2D con vista cenital y vertical, hecho en **Godot 4.3+ con GDScript**.
Arrancás con un solo zombi y contagiás humanos para armar una horda. Hay 5 niveles: **Ciudad** (10 oleadas), **Comisaría** (15), **Campo** (20, con soldados), **Ruinas** (25, supervivientes y motos) y **Desierto** (30, con tanques). Al ganar un nivel se desbloquea el siguiente y pasás a él con tu horda y tus mejoras.

Los personajes y la ciudad se dibujan con primitivas 2D (`_draw()`, tweens y partículas propias). Los mapas de la comisaría, el campo, las ruinas y el desierto son imágenes (`assets/maps/`). Los sonidos se generan por código al iniciar. No hay dependencias externas y funciona sin internet.

---

## 1. Cómo ejecutarlo

1. Instalá **Godot 4.3** (o más nuevo de la rama 4.x) desde https://godotengine.org/download. Alcanza con la versión estándar; no hace falta la .NET.
2. Abrí Godot → **Importar** → elegí `project.godot` de esta carpeta.
3. Apretá **F5** (Ejecutar proyecto).

En la PC se prueba así:

| Acción | Control |
|---|---|
| Mover | Hacé clic y arrastrá en cualquier parte (simula el dedo) o usá WASD / flechas |
| Pausa | Botón violeta, `Esc` o `P` |

En el celular, apoyás un dedo y arrastrás: el joystick aparece donde tocaste. La mordida y el ataque a policías son automáticos por cercanía.

---

## 2. Qué incluye (estado por fase)

### Fase 1: prototipo jugable ✔
- Proyecto vertical de 720×1280 con estirado `canvas_items` + `expand`, así se adapta a pantallas 19.5:9 y a tablets.
- Mapa urbano fijo: calles, veredas, cordones, cruces peatonales, edificios pastel, árboles, bancos, autos, faroles, hidrantes, tachos, conos y una barrera. Todo funciona como obstáculo.
- Joystick dinámico (multitouch seguro: sigue un solo dedo).
- Humanos que pasean y escapan de los zombis, con gotitas de susto.
- Contagio: mordida automática de 0.16 s → destello verde → partículas → anillo → el humano se suma a la horda.
- Aliados que siguen al líder en formación orgánica (espiral áurea + separación) y persiguen humanos cercanos.

### Fase 2: juego completo ✔
- 10 oleadas configurables en `scripts/core/balance.gd`. Los humanos aparecen por los bordes, nunca encima del jugador.
- Policías desde la oleada 2: llegan en patrullas, mantienen distancia, disparan, retroceden y se derrotan por contacto. Oleada a oleada son más, más rápidos, más resistentes y con mejor puntería; desde la oleada 5 un disparo elimina a un aliado.
- Vida y daño: líder con 3 golpes y aliados con 2. Si cae el líder, el control pasa al aliado más cercano.
- 6 mejoras acumulables (se elige 1 de 3 entre oleadas): Velocidad, Contagio, Resistencia, Horda, Furia e Instinto.
- Combo con ventana de 3 s y **FIEBRE ZOMBI** a los 5 contagios seguidos: más velocidad, puntaje x2, aura y partículas intensas.
- Victoria ("¡NIVEL SUPERADO!" o "¡INVASIÓN COMPLETA!" en el último) y derrota ("LA HUMANIDAD RESISTIÓ") con estadísticas.
- Guardado local (`user://paciente_cero.cfg`) de récord de puntos, oleada máxima, horda máxima, estadísticas, mejoras elegidas y ajustes.

### Fase 3: pulido ✔
- Paleta exacta de la planilla y dirección de arte de las láminas: personajes chibi cenitales, rastro verde del líder y logo con cabeza de zombi en la "O".
- Menú con JUGAR, MEJORAS (catálogo y veces elegida), RÉCORDS, AJUSTES (sonido, vibración, borrar récords), récord y botón de sonido.
- Tutorial "ARRASTRÁ PARA MOVERTE" sólo en la primera partida.
- 14 sonidos sintetizados (mordida, contagio con tono que sube en cadena, combo, fiebre, daño, policía, oleada, victoria, derrota, etc.).
- Pausa automática cuando la app pasa a segundo plano. Margen seguro para el notch.
- Optimización:
  - Los personajes se dibujan una sola vez al iniciar en un atlas de texturas (`scripts/autoload/actor_atlas.gd`); en juego cada uno es un `Sprite2D` que rota y cambia de cuadro.
  - El mapa estático se convierte en 2 texturas al cargar (`Baker` en `scripts/graphics/baker.gd`).
  - Las partículas usan una textura de 4 vértices en lugar de círculos.
  - Además: grillas espaciales, IA que decide cada ~0.2 s, separación cada 3 frames, sondeo de obstáculos cada 2 frames, pool de partículas y proyectiles, máximo de 3 pasos de física por frame y tope de 100 zombis simultáneos.
  - En la misma prueba de estrés (100 zombis, 25 civiles y 4 policías, render por software), el frame pasó de unos 295 ms a unos 58 ms: 5 veces más rápido.

### v0.3: niveles ✔
- 3 niveles definidos en `scripts/core/levels.gd`: Ciudad (10 oleadas), Comisaría (15) y Campo (20). Las oleadas suben de 5 en 5.
- Cada nivel arranca de cero (1 zombi, sin mejoras). Al ganar se desbloquea el siguiente y aparece el botón **SIGUIENTE**.
- JUGAR abre "ELEGÍ EL NIVEL", con miniatura, oleadas, enemigos, récord y candado.
- Comisaría: más policía, que llega antes y en patrullas más grandes.
- Campo: aparecen **soldados** desde la oleada 3. Son lentos y resistentes, tiran ráfagas de 3 desde lejos y cada bala hace 2 de daño.
- Los mapas de imagen tienen sus obstáculos (árboles, rocas, autos, cajas, edificio) cargados a mano en `scripts/world/world_map.gd`.
- Récord de oleada por nivel en el menú y en RÉCORDS.

### v0.4: niveles 4 y 5 ✔
- **Nivel 4, Las Ruinas** (25 oleadas): ciudad destruida con paredes, autos quemados y cajones como obstáculos.
  - **Superviviente**: escopeta que tira un abanico de 5 perdigones de corto alcance.
  - **Motociclista**: más rápido que la horda, da vueltas alrededor y dispara sin frenar.
- **Nivel 5, El Desierto** (30 oleadas): campo abierto con rocas y cráteres. Soldados, supervivientes, motos y un **tanque** cada 5 oleadas (dos en la última).
  - El tanque gira la torreta y tira cañonazos: un círculo rojo marca dónde va a caer y la explosión daña a todos los zombis del radio.
  - Sólo recibe daño con 5 zombis o más mordiéndolo a la vez (las marcas sobre el tanque se pintan de verde) y no puede apuntar a los que tiene pegados: hay que rodearlo.
  - Al destruirlo: +400 puntos y 6 zombis de regalo.
- Selector de niveles compacto para los 5 mapas.

### v0.5: horda continua y contagio de enemigos ✔
- Al ganar un nivel, la horda (cantidad de zombis) y las mejoras pasan al siguiente. Queda guardado: si elegís ese nivel desde el menú, arrancás con esa horda.
- Cada mejora tiene tope de nivel 5 (HORDA no tiene tope).
- Los enemigos armados se pueden **contagiar**: si cuando caen los rodean suficientes zombis, se suman a la horda. Policía, superviviente y moto: 5 zombis. Soldado: 10. El tanque no se contagia. Al morderlos aparecen marcas sobre su cabeza que se pintan de verde con cada zombi que los rodea.
- Con una horda grande llegan más enemigos armados (hasta +40 % con 100 zombis), para que los niveles sigan siendo un desafío.
- Nivel 1 más amable en las últimas oleadas y tanque un poco menos castigador.

### v0.5.1 ✔
- Comisaría: la zona jugable es sólo el estacionamiento y la calle de arriba. Nadie puede pasar a las veredas de los costados ni a la parte del edificio; los enemigos entran por la calle, por los costados y salen por la puerta de la comisaría.

### Fuera del MVP a propósito
La lámina muestra **botón de mordida**, **botón sprint**, **S.W.A.T.** y **barricadas por oleada**. La especificación y la planilla piden explícitamente *no* incluir botones de mordida o sprint, así que no están. S.W.A.T. y barricadas dinámicas quedan como ampliaciones naturales: se agregan como un nuevo `kind` en `Unit` y una entrada en `WAVES`. Tampoco hay música de fondo, sólo efectos.

---

## 3. Estructura

```
project.godot            Configuración (vertical, 720×1280, autoloads, renderer Compatibility)
export_presets.cfg       Presets Android e iOS
scenes/main/main_menu.tscn
assets/maps/              station.jpg, field.jpg, ruins.jpg, desert.jpg (mapas) y city_thumb.jpg (miniatura)
scenes/game/game.tscn    Game (GameManager) → WorldMap, Units (y-sort), Effects, Projectiles,
                         WaveManager, InfectionSystem, UpgradeManager, PlayerController, UIManager
scripts/
  core/       balance.gd (balance general y oleadas del nivel 1), levels.gd (niveles 2 a 5),
              palette.gd, spatial_grid.gd
  autoload/   save_manager.gd, audio_manager.gd, scene_transition.gd
  game/       game_manager.gd, wave_manager.gd, infection_system.gd, upgrade_manager.gd,
              player_controller.gd, projectiles.gd, effects.gd
  ai/         human_ai.gd, zombie_ai.gd, police_ai.gd
  actors/     unit.gd           (un actor reutilizable: humano → zombi sin recrear el nodo)
  world/      world_map.gd      (ciudad dibujada, mapas de imagen, colisiones y puntos de aparición)
  graphics/   actor_art.gd, icon_view.gd
  ui/         ui_manager.gd, ui_kit.gd, main_menu.gd, logo_view.gd
tests/        bot_runner (partida completa automática) y shot_runner (capturas)
docs/screenshots/  Capturas de cada pantalla
```

### Ajustar el balance
Todo está en `scripts/core/balance.gd`: velocidades, radios, vida, puntajes, combo y fiebre, y la tabla `WAVES` del nivel 1. Las oleadas de los niveles 2 a 5 están en `scripts/core/levels.gd`: soldados (`soldiers`, `s_*`), supervivientes (`survivors`, `sv_*`), motos (`bikers`, `b_*`) y tanques (`tanks`, `t_*`). Las constantes de cada enemigo (velocidad, alcance, daño, cadencia) están en `balance.gd`.

---

## 4. Pruebas automáticas

```bash
# Partida completa jugada por un bot (persigue humanos y elige mejoras al azar). LEVEL=1..5
LEVEL=1 godot --headless --fixed-fps 60 --path . res://tests/bot_runner.tscn

# Bot quieto, para verificar la derrota
BOT_MODE=idle godot --headless --fixed-fps 60 --path . res://tests/bot_runner.tscn

# Capturas (requiere pantalla o xvfb): menu, game_start, game_horde, upgrade, pause, defeat, victory,
# menu_upgrades, menu_records, menu_settings
SHOT=menu godot --path . --resolution 720x1280 res://tests/shot_runner.tscn
```

Resultado de referencia (Godot 4.3): el bot, que no esquiva disparos, pierde la mayoría de las partidas entre las oleadas 6 y 10 y gana alrededor de 1 de cada 5. La simulación tarda ~1.1 ms por frame con 100 zombis. Con el bot quieto se pierde en la oleada 3.

```bash
# Prueba de estrés de rendimiento (requiere pantalla o xvfb)
godot --path . --rendering-driver opengl3 res://tests/perf_runner.tscn
```

---

## 5. Generar una APK de Android

1. En Godot: **Editor → Administrar plantillas de exportación → Descargar e instalar** (las de tu versión).
2. Instalá **JDK 17** y el **Android SDK** (lo más simple es instalar Android Studio y abrir el SDK Manager: Platform-Tools, Build-Tools 34, Platform 34).
3. **Editor → Configuración del editor → Exportar → Android**: completá
   - `Java SDK Path` (carpeta del JDK 17)
   - `Android SDK Path` (por ejemplo `C:\Users\<vos>\AppData\Local\Android\Sdk`)
   - Godot crea solo un keystore de *debug* para probar.
4. **Proyecto → Exportar…** → preset **Android** (ya configurado: `com.pacientecero.game`, arm64-v8a + armeabi-v7a, inmersivo, permiso de vibración, sin internet).
5. **Exportar proyecto** → `build/android/PacienteCero.apk`. Para probar en el teléfono: activá *Depuración USB* y usá el botón de Android de *Remote Debug / One-click deploy*, o instalá la APK con `adb install`.
6. **Para publicar**: generá un keystore de release (`keytool -genkey -v -keystore release.keystore -alias pacientecero -keyalg RSA -keysize 2048 -validity 10000`), cargalo en el preset (Keystore → Release) y exportá en modo Release. Para Google Play conviene exportar como **AAB**: activá `Gradle Build` y elegí formato AAB (pide instalar la plantilla de compilación Android desde el menú Proyecto).

## 6. Compilación para iOS

Necesitás una **Mac con Xcode** y una cuenta de Apple Developer (la gratuita sirve para probar en tu propio iPhone).

1. Instalá las plantillas de exportación en Godot (igual que en Android).
2. **Proyecto → Exportar…** → preset **iOS**: completá `App Store Team ID` (lo ves en developer.apple.com → Membership) y, si querés, cambiá el `Bundle Identifier` (`com.pacientecero.game`).
3. El preset viene con *Export Project Only* activado: genera un proyecto de Xcode en `build/ios/`.
4. Abrí el `.xcodeproj` en Xcode → *Signing & Capabilities* → elegí tu Team → conectá el iPhone → **Run**.
5. Para la App Store: en Xcode, *Product → Archive* → *Distribute App*.

Íconos: el proyecto usa `icon.svg`. Antes de publicar conviene cargar íconos PNG en las tamaños que pide cada preset (Android 192×192 y adaptativos de 432×432; iOS 1024×1024).

---

## 7. Notas técnicas
- Renderer **Compatibility** (OpenGL ES 3 / WebGL2): es el más compatible con celulares de gama media.
- La fuente es la del sistema (redondeada o gruesa si el dispositivo la tiene). Si querés una tipografía propia con licencia libre, por ejemplo Nunito (OFL), copiá el `.ttf` y cambiá `UIKit.font()`.
- Los colores sólo se cambian en `scripts/core/palette.gd`.

---

## 8. Probar online y publicar en GitHub

### Con GitHub (recomendado)
El repo trae `.github/workflows/build.yml`. Cada vez que subís cambios a la rama `main`, GitHub:
1. compila la **versión web** y la publica en **GitHub Pages** (un link para jugar desde cualquier celular);
2. compila una **APK de prueba** para Android, que se descarga desde la pestaña **Actions** → la última ejecución → *Artifacts*.

Pasos una sola vez:
1. Creá un repositorio nuevo en github.com (por ejemplo `paciente-cero`). Puede ser público o privado. Pages en repos privados requiere un plan pago.
2. Subí esta carpeta. Con GitHub Desktop: *File → Add local repository* → *Publish repository*. Por consola:
   ```bash
   git remote add origin https://github.com/<tu-usuario>/paciente-cero.git
   git push -u origin main
   ```
3. En el repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
4. Esperá unos 3–5 minutos (Actions en verde). El juego queda en `https://<tu-usuario>.github.io/paciente-cero/`.

### Probar en Android sin tienda
Pasá la APK de prueba al teléfono, abrila y aceptá *Instalar apps de origen desconocido*. La APK *debug* sirve sólo para probar. Para Google Play hace falta una firma *release* (ver sección 5).

### Hacia las tiendas
- **Google Play**: cuenta de desarrollador (pago único de USD 25), exportación AAB firmada con tu keystore *release*, ficha de la app, capturas (las de `docs/screenshots/` sirven de base) y política de privacidad (el juego no recolecta datos).
- **App Store**: Apple Developer Program (USD 99/año), una Mac con Xcode, exportación iOS desde Godot y subida con Xcode → App Store Connect.
