extends RefCounted
## Configurações do jogador (gráficos e volumes), salvas em user://configuracoes.cfg.
## Uso:  const Config := preload("res://Configuracoes/config_global.gd")
##        Config.aplicar()                 # carrega (1ª vez) e aplica volumes
##        Config.graficos                  # 0 = Mínimo, 1 = Médio, 2 = Máximo
##        Config.fator_particulas()        # 0.0 / 0.5 / 1.0 para partículas de enfeite

const ARQUIVO := "user://configuracoes.cfg"
const BUS_MUSICA := "Musica"
const NOMES_GRAFICOS := ["Mínimo", "Médio", "Máximo"]

static var graficos := 2
static var volume_musica := 80        # 0 a 100
static var volume_geral := 100        # 0 a 100
static var _carregado := false


static func carregar() -> void:
	_carregado = true
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		return
	graficos = clampi(int(cfg.get_value("config", "graficos", graficos)), 0, 2)
	volume_musica = clampi(int(cfg.get_value("config", "volume_musica", volume_musica)), 0, 100)
	volume_geral = clampi(int(cfg.get_value("config", "volume_geral", volume_geral)), 0, 100)


static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("config", "graficos", graficos)
	cfg.set_value("config", "volume_musica", volume_musica)
	cfg.set_value("config", "volume_geral", volume_geral)
	cfg.save(ARQUIVO)


## Garante que existe o canal de áudio "Musica" (as músicas tocam nele; os efeitos no Master).
static func bus_musica() -> StringName:
	if AudioServer.get_bus_index(BUS_MUSICA) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS_MUSICA)
		AudioServer.set_bus_send(i, "Master")
	return BUS_MUSICA


static func aplicar() -> void:
	if not _carregado:
		carregar()
	var musica := AudioServer.get_bus_index(bus_musica())
	AudioServer.set_bus_volume_db(0, _db(volume_geral))
	AudioServer.set_bus_mute(0, volume_geral <= 0)
	AudioServer.set_bus_volume_db(musica, _db(volume_musica))
	AudioServer.set_bus_mute(musica, volume_musica <= 0)


static func _db(porcento: int) -> float:
	return linear_to_db(maxf(porcento / 100.0, 0.0001))


## Quanto das partículas "de enfeite" aparece (cenário, estouros): Mínimo 0, Médio 0.5, Máximo 1.
static func fator_particulas() -> float:
	if not _carregado:
		carregar()
	return [0.0, 0.5, 1.0][graficos]


## Para efeitos que precisam aparecer (ex.: estouro ao acertar), só ficam menores.
static func fator_efeitos() -> float:
	if not _carregado:
		carregar()
	return [0.4, 0.7, 1.0][graficos]
