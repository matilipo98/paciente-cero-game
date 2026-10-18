class_name Balance
extends RefCounted
## Todos los valores de balance en un solo lugar para ajustar fácilmente.

# --- Mundo -------------------------------------------------------------------
const WORLD_SIZE := Vector2(720, 1280)
## Zona jugable (debajo del HUD). Los actores nunca salen de este rectángulo.
const PLAY_RECT := Rect2(12, 130, 696, 1138)

# --- Actores -----------------------------------------------------------------
const ZOMBIE_RADIUS := 21.0
const ALLY_RADIUS := 18.5
const HUMAN_RADIUS := 18.5
const POLICE_RADIUS := 20.0

const LEADER_SPEED := 200.0
const ALLY_SPEED := 190.0
const ALLY_CATCHUP_MULT := 1.18
const HUMAN_WALK_SPEED := 52.0
const HUMAN_RUN_SPEED := 152.0
const POLICE_SPEED := 118.0

const LEADER_HP := 3
const ALLY_HP := 2
const LEADER_INVULN := 0.6
const ALLY_INVULN := 0.25

# --- Contagio -----------------------------------------------------------------
## Distancia extra (además de tocarse) para iniciar la mordida.
const BITE_EXTRA := 8.0
## Duración de la mordida automática antes de transformar al humano.
const BITE_TIME := 0.16
const HUMAN_FEAR_RADIUS := 165.0
const ALLY_DETECT_RADIUS := 135.0
## Distancia máxima a la que un aliado se aleja del líder persiguiendo.
const ALLY_LEASH := 280.0
const MAX_ZOMBIES := 100

# --- Policías -----------------------------------------------------------------
## "Vida" del policía en segundos de contacto con un solo zombi.
const POLICE_TOUGHNESS := 1.8
const POLICE_MAX_ATTACKERS := 3
const POLICE_SHOOT_RANGE := 290.0
const POLICE_PREFERRED_DIST := 200.0
const POLICE_FIRE_INTERVAL := 1.25
const BULLET_SPEED := 340.0

## Contagio de enemigos armados: si al caer lo rodean al menos esta cantidad de zombis,
## se suma a la horda en vez de desaparecer. El tanque no se contagia.
const INFECT_NEED_POLICE := 5
const INFECT_NEED_SOLDIER := 10
const INFECT_NEED_SURVIVOR := 5
const INFECT_NEED_BIKER := 5
## Distancia (además del radio del enemigo) a la que un zombi cuenta como "rodeándolo".
const SURROUND_EXTRA := 62.0


static func infect_need(kind: int) -> int:
	match kind:
		ActorArt.Kind.POLICE:
			return INFECT_NEED_POLICE
		ActorArt.Kind.SOLDIER:
			return INFECT_NEED_SOLDIER
		ActorArt.Kind.SURVIVOR:
			return INFECT_NEED_SURVIVOR
		ActorArt.Kind.BIKER:
			return INFECT_NEED_BIKER
	return 0


# --- Soldados (nivel 3) -----------------------------------------------------------
const SOLDIER_RADIUS := 21.0
const SOLDIER_SPEED := 108.0
## Más resistentes que la policía (segundos de contacto con un solo zombi).
const SOLDIER_TOUGHNESS := 3.2
const SOLDIER_SHOOT_RANGE := 330.0
const SOLDIER_PREFERRED_DIST := 230.0
## Disparan ráfagas: SOLDIER_BURST tiros separados por SOLDIER_BURST_GAP segundos.
const SOLDIER_BURST := 3
const SOLDIER_BURST_GAP := 0.12
const SOLDIER_FIRE_INTERVAL := 2.0
const SOLDIER_DMG := 2
const BULLET_RADIUS := 4.5

# --- Supervivientes (nivel 4) -------------------------------------------------------
## Escopeta: abanico de perdigones de corto alcance.
const SURVIVOR_RADIUS := 19.5
const SURVIVOR_SPEED := 125.0
const SURVIVOR_TOUGHNESS := 2.4
const SURVIVOR_SHOOT_RANGE := 215.0
const SURVIVOR_PREFERRED_DIST := 165.0
const SURVIVOR_FIRE_INTERVAL := 1.9
const SURVIVOR_PELLETS := 5
const SURVIVOR_SPREAD := 0.42
const PELLET_LIFE := 0.62

## Motociclista: más rápido que la horda, la rodea y dispara en movimiento.
const BIKER_RADIUS := 22.0
const BIKER_SPEED := 245.0
const BIKER_ACCEL := 520.0
const BIKER_TOUGHNESS := 1.6
const BIKER_ORBIT := 200.0
const BIKER_SHOOT_RANGE := 300.0
const BIKER_FIRE_INTERVAL := 0.95

# --- Tanque (jefe del nivel 5) ----------------------------------------------------
const TANK_RADIUS := 46.0
const TANK_SPEED := 52.0
## "Vida" en segundos-zombi: sólo recibe daño con TANK_MIN_ATTACKERS mordiéndolo a la vez.
const TANK_TOUGHNESS := 36.0
const TANK_MIN_ATTACKERS := 5
const TANK_MAX_ATTACKERS := 14
const TANK_FIRE_INTERVAL := 4.0
const TANK_RANGE := 430.0
## Más cerca que esto el cañón no puede apuntar: rodearlo es la forma de ganarle.
const TANK_MIN_RANGE := 105.0
const SHELL_FLIGHT := 1.1
const SHELL_BLAST := 64.0
const SHELL_DMG := 2
const TANK_BONUS_ALLIES := 6

# --- Combo / Fiebre ----------------------------------------------------------
const COMBO_WINDOW := 3.0
const FEVER_COMBO := 5
const FEVER_DURATION := 5.0
const FEVER_SPEED_MULT := 1.3
const FEVER_SCORE_MULT := 2.0
const COMBO_STEP_MULT := 0.1
const COMBO_MAX_MULT := 3.0

# --- Puntuación ----------------------------------------------------------------
const SCORE_INFECT := 10
const SCORE_POLICE := 25
const SCORE_SOLDIER := 40
const SCORE_SURVIVOR := 30
const SCORE_BIKER := 35
const SCORE_TANK := 400
const SCORE_WAVE := 100

# --- Oleadas ---------------------------------------------------------------------
## humans / police: cantidades. speed: multiplicador de velocidad de civiles.
## fear: multiplicador del radio de miedo. duration: segundos.
## p_tough: resistencia policial. p_fire: multiplicador del intervalo de disparo (menor = dispara más).
## p_aim: 0 = apunta a donde está el zombi, 1 = anticipa su movimiento por completo.
## p_speed: velocidad policial. p_squad: cuántos policías llegan juntos por patrulla.
## p_dmg: daño de cada disparo (los aliados tienen 2 de vida; 2 = los elimina de un tiro).
const WAVES: Array[Dictionary] = [
	{"humans": 10, "police": 0, "speed": 0.85, "fear": 0.75, "duration": 35.0, "p_tough": 1.00, "p_fire": 1.00, "p_aim": 0.00, "p_speed": 1.00, "p_squad": 1, "p_dmg": 1},
	{"humans": 12, "police": 1, "speed": 0.92, "fear": 0.85, "duration": 35.0, "p_tough": 1.00, "p_fire": 1.00, "p_aim": 0.00, "p_speed": 1.00, "p_squad": 1, "p_dmg": 1},
	{"humans": 15, "police": 2, "speed": 1.00, "fear": 0.95, "duration": 35.0, "p_tough": 1.15, "p_fire": 0.95, "p_aim": 0.20, "p_speed": 1.05, "p_squad": 2, "p_dmg": 1},
	{"humans": 18, "police": 3, "speed": 1.02, "fear": 1.00, "duration": 36.0, "p_tough": 1.40, "p_fire": 0.88, "p_aim": 0.35, "p_speed": 1.10, "p_squad": 2, "p_dmg": 1},
	{"humans": 20, "police": 6, "speed": 1.05, "fear": 1.05, "duration": 37.0, "p_tough": 1.70, "p_fire": 0.82, "p_aim": 0.45, "p_speed": 1.15, "p_squad": 2, "p_dmg": 1},
	{"humans": 22, "police": 7, "speed": 1.08, "fear": 1.05, "duration": 38.0, "p_tough": 2.20, "p_fire": 0.74, "p_aim": 0.55, "p_speed": 1.20, "p_squad": 3, "p_dmg": 1},
	{"humans": 24, "police": 8, "speed": 1.10, "fear": 1.10, "duration": 39.0, "p_tough": 2.60, "p_fire": 0.66, "p_aim": 0.70, "p_speed": 1.25, "p_squad": 3, "p_dmg": 2},
	{"humans": 26, "police": 9, "speed": 1.12, "fear": 1.10, "duration": 40.0, "p_tough": 3.00, "p_fire": 0.62, "p_aim": 0.80, "p_speed": 1.30, "p_squad": 3, "p_dmg": 2},
	{"humans": 28, "police": 10, "speed": 1.14, "fear": 1.15, "duration": 42.0, "p_tough": 3.40, "p_fire": 0.58, "p_aim": 0.90, "p_speed": 1.35, "p_squad": 4, "p_dmg": 2},
	{"humans": 32, "police": 12, "speed": 1.16, "fear": 1.15, "duration": 45.0, "p_tough": 3.80, "p_fire": 0.54, "p_aim": 1.00, "p_speed": 1.40, "p_squad": 4, "p_dmg": 2},
]
## Enemigos armados extra según el tamaño de la horda (0.4 = +40 % con 100 zombis).
const HORDE_THREAT := 0.4
## Porcentaje de humanos que aparece apenas empieza la oleada (acción inmediata).
const WAVE_INITIAL_FRACTION := 0.4
## Fracción de la duración en la que termina de aparecer el resto.
const WAVE_SPAWN_WINDOW := 0.55
## Distancia mínima entre un punto de aparición y el líder.
const SPAWN_MIN_DIST_TO_LEADER := 260.0


static func wave_count() -> int:
	return WAVES.size()


static func get_wave(n: int) -> Dictionary:
	return WAVES[clampi(n - 1, 0, WAVES.size() - 1)]
