extends RefCounted
## Música que continua tocando quando troca de cena (menu, biblioteca, tutorial, configurações).
## Ela fica num nó "MusicaGlobal" preso na raiz do jogo, que não some com a troca de cena.
##
## Uso em qualquer cena:
##   const Musica := preload("res://Menu/musica_global.gd")
##   Musica.tocar(get_tree(), minha_musica, -6.0)   # se já estiver tocando, só continua
##   Musica.manter(get_tree(), reserva)              # continua o que estiver tocando (ou toca a reserva)
##   Musica.pausar(get_tree())  /  Musica.continuar(get_tree())
##   Musica.parar(get_tree())                        # ex.: ao entrar no jogo
##   Musica.som_navegar(get_tree())                  # "tic" ao trocar de opção em qualquer tela

const NOME := "MusicaGlobal"
const MUDO := -40.0

static var _player: AudioStreamPlayer
static var _volume := -6.0
static var _tween: Tween


static func _obter(tree: SceneTree) -> AudioStreamPlayer:
	if _player and is_instance_valid(_player):
		return _player
	var achado := tree.root.get_node_or_null(NOME)
	if achado is AudioStreamPlayer:
		_player = achado
		return _player
	_player = AudioStreamPlayer.new()
	_player.name = NOME
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.volume_db = MUDO
	_player.bus = preload("res://Configuracoes/config_global.gd").bus_musica()   # volume de música das Configurações
	tree.root.add_child.call_deferred(_player)       # a raiz pode estar ocupada montando a cena
	return _player


static func _fade(tree: SceneTree, para_db: float, duracao: float, depois: Callable = Callable()) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = tree.create_tween()                     # tween da árvore: não morre ao trocar de cena
	_tween.tween_property(_player, "volume_db", para_db, maxf(duracao, 0.01))
	if depois.is_valid():
		_tween.tween_callback(depois)


static func _play(p: AudioStreamPlayer) -> void:
	if p.is_inside_tree():
		p.play()
	else:
		p.autoplay = true                            # vai tocar assim que entrar na árvore


## Toca a música. Se essa mesma música já estiver tocando, só continua (sem recomeçar).
static func tocar(tree: SceneTree, stream: AudioStream, volume_db: float = -6.0, fade: float = 1.5) -> void:
	if stream == null:
		return
	var p := _obter(tree)
	stream.set("loop", true)
	var tocando := p.stream == stream and (p.playing or p.autoplay) and not p.stream_paused
	if tocando:
		if p.volume_db < _volume - 0.5:              # estava abaixando: volta ao volume normal
			_fade(tree, _volume, fade * 0.5)
		return
	_volume = volume_db
	if p.stream != stream:
		p.stream = stream
		p.volume_db = MUDO
		_play(p)
	elif p.stream_paused:
		p.stream_paused = false
	elif not p.playing:
		p.volume_db = MUDO
		_play(p)
	_fade(tree, _volume, fade)


## Se já tem música tocando (vindo do menu), só continua do mesmo jeito e no mesmo volume.
## Se não tiver nada tocando (abriu a cena direto), toca a música reserva.
static func manter(tree: SceneTree, reserva: AudioStream, volume_db: float = -6.0) -> void:
	var p := _obter(tree)
	if p.stream and (p.playing or p.autoplay or p.stream_paused):
		continuar(tree, 0.6)
		return
	tocar(tree, reserva, volume_db)


## Abaixa até sumir e pausa (ex.: biblioteca tocando outra música por cima).
static func pausar(tree: SceneTree, fade: float = 0.4) -> void:
	var p := _obter(tree)
	if not p.playing:
		return
	_fade(tree, MUDO, fade, func(): p.stream_paused = true)


## Volta de onde parou.
static func continuar(tree: SceneTree, fade: float = 1.0) -> void:
	var p := _obter(tree)
	if p.stream == null:
		return
	p.stream_paused = false
	if not p.playing:
		_play(p)
	_fade(tree, _volume, fade)


## Para de vez (ex.: começou o jogo, que tem as próprias músicas).
static func parar(tree: SceneTree, fade: float = 0.8) -> void:
	var p := _obter(tree)
	p.autoplay = false
	if not p.playing:
		return
	_fade(tree, MUDO, fade, func():
		p.stop()
		p.stream_paused = false)


# ================================================================ som de navegação dos menus

const SOM_NAVEGAR := "res://Menu/sfx_menu_select.wav"   ## troque o arquivo aqui se quiser outro som
const VOLUME_NAVEGAR_DB := -2.0                          ## mais alto: aumente / mais baixo: diminua
static var _som: AudioStreamPlayer


## Toca o "tic" de trocar de opção (menu, configurações, pausa, fim de jogo, vitória, cartas...).
static func som_navegar(tree: SceneTree) -> void:
	if _som == null or not is_instance_valid(_som):
		_som = AudioStreamPlayer.new()
		_som.name = "SomNavegacao"
		_som.process_mode = Node.PROCESS_MODE_ALWAYS
		_som.max_polyphony = 4
		_som.volume_db = VOLUME_NAVEGAR_DB
		if ResourceLoader.exists(SOM_NAVEGAR):
			_som.stream = load(SOM_NAVEGAR)
		tree.root.add_child.call_deferred(_som)
	if _som.stream == null:
		return
	if _som.is_inside_tree():
		_som.play()
	else:
		_som.play.call_deferred()
