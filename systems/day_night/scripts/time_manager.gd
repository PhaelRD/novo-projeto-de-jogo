extends Node

# ─── Constantes ───────────────────────────────────────────────────────────────
const DAYS_PER_SEASON : int   = 28
const START_HOUR      : float = 6.0
const SLEEP_HOUR      : float = 2.0   # hora que força o novo dia (2h da manhã)

# 1 segundo real = 1 minuto in-game
# Um dia cobre 20h in-game (6h → 2h) → 20×60 = 1200 segundos = 20 min reais ✓
const TIME_SCALE : float = 1.0

const SEASON_NAMES := ["Primavera", "Verão", "Outono", "Inverno"]
const RAIN_CHANCES : Array[float] = [0.4, 0.2, 0.3, 0.1] # Chances de chuva por estação

# ─── Estado ───────────────────────────────────────────────────────────────────
var current_hour   : float = START_HOUR
var current_day    : int   = 1
var current_season : int   = 0   # 0=Primavera  1=Verão  2=Outono  3=Inverno
var current_year   : int   = 1
var is_paused      : bool  = false
var is_raining     : bool  = false

# Evita emitir hour_changed vários frames no mesmo minuto
var _last_emitted_minute : int = -1
# Evita chamar advance_day() múltiplas vezes no mesmo ciclo
var _day_advancing : bool = false

# ─── Sinais ───────────────────────────────────────────────────────────────────
signal hour_changed(hour: float)
signal day_changed(day: int, season: int, year: int)
signal season_changed(season: int, year: int)
signal time_to_sleep()
signal weather_changed(is_raining: bool)

# ─── Ciclo ────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_paused or _day_advancing:
		return

	# Avança o tempo: TIME_SCALE min/s ÷ 60 converte em horas
	current_hour += delta * TIME_SCALE / 60.0

	# Emite hour_changed uma vez por minuto in-game
	var minute_now := int(current_hour * 60.0)
	if minute_now != _last_emitted_minute:
		_last_emitted_minute = minute_now
		hour_changed.emit(current_hour)

	# Verifica se chegou às 2h da manhã (hora interna >= 26.0, pois começa às 6h)
	if current_hour >= 24.0 + SLEEP_HOUR and not _day_advancing:
		_day_advancing = true
		time_to_sleep.emit()
		await get_tree().create_timer(0.05).timeout  # frame de segurança
		advance_day()
		_day_advancing = false

# ─── API Pública ──────────────────────────────────────────────────────────────

## Avança para o próximo dia (pode ser chamado externamente por uma cama, etc.)
func advance_day() -> void:
	current_hour         = START_HOUR
	_last_emitted_minute = -1
	current_day         += 1

	if current_day > DAYS_PER_SEASON:
		current_day        = 1
		var old_season     := current_season
		current_season     = (current_season + 1) % 4
		if current_season == 0:
			current_year += 1
		if current_season != old_season:
			season_changed.emit(current_season, current_year)

	is_raining = randf() < RAIN_CHANCES[current_season]
	weather_changed.emit(is_raining)

	day_changed.emit(current_day, current_season, current_year)
	hour_changed.emit(current_hour)

## Pausa a passagem do tempo (ex: inventário aberto)
func pause() -> void:
	is_paused = true

## Retoma a passagem do tempo
func resume() -> void:
	is_paused = false

## Retorna a hora formatada — ex: "06:30"
func get_time_string() -> String:
	var h := int(current_hour) % 24
	var m := int(fmod(current_hour, 1.0) * 60.0)
	return "%02d:%02d" % [h, m]

## Retorna o nome da estação atual — ex: "Primavera"
func get_season_name() -> String:
	return SEASON_NAMES[current_season]

# ─── Save / Load ──────────────────────────────────────────────────────────────
func get_save_data() -> Dictionary:
	return {
		"hour"       : current_hour,
		"day"        : current_day,
		"season"     : current_season,
		"year"       : current_year,
		"is_raining" : is_raining,
	}

func load_save_data(d: Dictionary) -> void:
	current_hour         = d.get("hour",   START_HOUR)
	current_day          = d.get("day",    1)
	current_season       = d.get("season", 0)
	current_year         = d.get("year",   1)
	is_raining           = d.get("is_raining", false)
	_last_emitted_minute = -1
	# Re-emite os sinais para que os listeners se atualizem imediatamente
	hour_changed.emit(current_hour)
	day_changed.emit(current_day, current_season, current_year)
	weather_changed.emit(is_raining)

## Reseta o tempo para o estado inicial (Novo Jogo)
func reset() -> void:
	current_hour         = START_HOUR
	current_day          = 1
	current_season       = 0
	current_year         = 1
	is_raining           = false
	_last_emitted_minute = -1
	is_paused            = false
	_day_advancing       = false
	weather_changed.emit(is_raining)
