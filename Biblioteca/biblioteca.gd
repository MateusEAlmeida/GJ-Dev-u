extends Control

@export_group("Arquivos")
@export var video_fundo: VideoStream
@export var musica_fundo: AudioStream  
@export var fonte_titulo: Font
@export var fonte_texto: Font
@export_dir var pasta_musicas: String = "res://biblioteca/musicas"
@export_dir var pasta_artes: String = "res://biblioteca/artes"
@export_file("*.tscn") var cena_menu: String = "res://Menu.tscn"

@export_group("Créditos")
@export var nome_musico: String = "Thiago Amaral"
@export var nome_artista: String = "Christian Ferreira"

@export_group("Aparência")
@export var tamanho_titulo: int = 84
@export var tamanho_texto: int = 40
@export var cor_texto: Color = Color(0.96, 0.93, 0.86)
@export var cor_apagada: Color = Color(0.60, 0.56, 0.74)
@export var cor_fundo: Color = Color(0.10, 0.07, 0.17)
@export var colunas_galeria: int = 5
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -6.0

const EXT_MUSICA := ["ogg", "mp3", "wav"]
const EXT_ARTE := ["png", "jpg", "jpeg", "webp", "svg"]
const MUDO := -60.0

enum Tela { INICIO, PLAYLIST, ARTES }

var tela_atual: Tela = Tela.INICIO
var telas := {}
var titulo: Label
var subtitulo: Label
var dica: Label
var seta: Label
var fade: ColorRect
var player_fundo: AudioStreamPlayer
const Musica := preload("res://Menu/musica_global.gd")   # mesma música do menu, sem recomeçar
var player_musica: AudioStreamPlayer

var botoes_inicio: Array[Button] = []
var botao_voltar_playlist: Button
var botao_voltar_artes: Button

var musicas: Array[AudioStream] = []
var nomes_musicas := PackedStringArray()
var botoes_musicas: Array[Button] = []
var musica_atual := -1
var nome_tocando: Label
var barra_fundo: ColorRect
var barra: ColorRect
var equalizador: Array[ColorRect] = []

var artes: Array[Texture2D] = []
var nomes_artes := PackedStringArray()
var miniaturas: Array[Button] = []
var overlay: ColorRect
var arte_grande: TextureRect
var arte_nome: Label
var arte_aberta := -1

var pos_seta := Vector2.ZERO
var tempo := 0.0
var ocupado := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_criar_fundo()
	_criar_cabecalho()
	_criar_tela_inicio()
	_criar_tela_playlist()
	_criar_tela_artes()
	_criar_seta()
	_criar_overlay()
	_criar_fade()
	_criar_audio()

	for k in telas:
		telas[k].visible = k == Tela.INICIO
	_atualizar_textos()
	await get_tree().process_frame
	botoes_inicio[0].grab_focus()
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	tempo += delta
	_atualizar_seta(delta)
	_atualizar_tocando(delta)


func _cheio(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _label(texto: String, tamanho: int, cor: Color, fonte: Font = null) -> Label:
	var l := Label.new()
	l.text = texto
	var f := fonte if fonte else fonte_texto
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _sem_caixa(b: Button) -> void:
	var vazio := StyleBoxEmpty.new()
	for nome in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(nome, vazio)


func _botao(texto: String, tamanho: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if fonte_texto:
		b.add_theme_font_override("font", fonte_texto)
	b.add_theme_font_size_override("font_size", tamanho)
	for nome in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(nome, Color.WHITE)
	_sem_caixa(b)
	b.self_modulate = cor_apagada
	b.focus_entered.connect(_ao_focar_item.bind(b))
	b.focus_exited.connect(_destacar_item.bind(b, false))
	b.mouse_entered.connect(b.grab_focus)
	return b


func _criar_fundo() -> void:
	var cor := ColorRect.new()
	cor.color = cor_fundo
	add_child(cor)
	_cheio(cor)
	cor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if video_fundo:
		var v := VideoStreamPlayer.new()
		v.expand = true
		v.stream = video_fundo
		add_child(v)
		_cheio(v)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set("loop", true)
		v.finished.connect(v.play)
		v.play()
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.55)
	add_child(escuro)
	_cheio(escuro)
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _criar_cabecalho() -> void:
	titulo = _label("", tamanho_titulo, cor_texto, fonte_titulo)
	titulo.position = Vector2(100, 60)
	add_child(titulo)
	subtitulo = _label("", int(tamanho_texto * 0.7), cor_apagada)
	subtitulo.position = Vector2(106, 80 + tamanho_titulo * 1.25)
	add_child(subtitulo)
	dica = _label("", int(tamanho_texto * 0.55), Color(cor_apagada, 0.8))
	dica.position = Vector2(100, 1020)
	add_child(dica)


func _nova_tela(qual: Tela) -> Control:
	var tela := Control.new()
	add_child(tela)
	_cheio(tela)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	telas[qual] = tela
	return tela


func _botao_voltar(tela: Control) -> Button:
	var b := _botao("Voltar", int(tamanho_texto * 0.75))
	b.position = Vector2(1680, 1000)
	tela.add_child(b)
	b.pressed.connect(_mostrar_tela.bind(Tela.INICIO))
	return b


func _criar_tela_inicio() -> void:
	var tela := _nova_tela(Tela.INICIO)
	var lista := VBoxContainer.new()
	lista.position = Vector2(170, 380)
	lista.add_theme_constant_override("separation", 16)
	tela.add_child(lista)
	var b1 := _botao("Playlist " + nome_musico, tamanho_texto)
	var b2 := _botao("Artes " + nome_artista, tamanho_texto)
	var b3 := _botao("Voltar", tamanho_texto)
	for b in [b1, b2, b3]:
		lista.add_child(b)
		botoes_inicio.append(b)
	b1.pressed.connect(_mostrar_tela.bind(Tela.PLAYLIST))
	b2.pressed.connect(_mostrar_tela.bind(Tela.ARTES))
	b3.pressed.connect(_voltar_ao_menu)


func _criar_tela_playlist() -> void:
	var tela := _nova_tela(Tela.PLAYLIST)
	var achados := _carregar(pasta_musicas, EXT_MUSICA)
	musicas.assign(achados[0])
	nomes_musicas = achados[1]

	if musicas.is_empty():
		var aviso := _label("Ainda não tem músicas aqui.\nColoque os arquivos em:\n" + pasta_musicas,
			int(tamanho_texto * 0.7), cor_apagada)
		aviso.position = Vector2(170, 380)
		tela.add_child(aviso)
	else:
		var rolagem := ScrollContainer.new()
		rolagem.position = Vector2(150, 300)
		rolagem.size = Vector2(980, 660)
		rolagem.follow_focus = true
		rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tela.add_child(rolagem)
		var margem := MarginContainer.new()
		margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for lado in ["left", "top", "bottom"]:
			margem.add_theme_constant_override("margin_" + lado, 10)
		rolagem.add_child(margem)
		var lista := VBoxContainer.new()
		lista.add_theme_constant_override("separation", 8)
		margem.add_child(lista)
		for i in musicas.size():
			var b := _botao("%02d    %s" % [i + 1, nomes_musicas[i]], int(tamanho_texto * 0.9))
			lista.add_child(b)
			botoes_musicas.append(b)

	var x := 1200.0
	tela.add_child(_posicionado(_label("TOCANDO AGORA", int(tamanho_texto * 0.5), cor_apagada), Vector2(x, 700)))
	nome_tocando = _label("-", int(tamanho_texto * 0.95), cor_texto)
	nome_tocando.position = Vector2(x, 740)
	nome_tocando.size = Vector2(620, 0)
	nome_tocando.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tela.add_child(nome_tocando)
	barra_fundo = ColorRect.new()
	barra_fundo.color = Color(cor_apagada, 0.35)
	barra_fundo.position = Vector2(x, 880)
	barra_fundo.size = Vector2(620, 4)
	tela.add_child(barra_fundo)
	barra = ColorRect.new()
	barra.color = cor_texto
	barra.position = barra_fundo.position
	barra.size = Vector2(0, 4)
	tela.add_child(barra)
	for i in 5:
		var e := ColorRect.new()
		e.color = cor_texto
		e.size = Vector2(8, 4)
		tela.add_child(e)
		equalizador.append(e)

	botao_voltar_playlist = _botao_voltar(tela)


func _posicionado(c: Control, pos: Vector2) -> Control:
	c.position = pos
	return c


func _criar_tela_artes() -> void:
	var tela := _nova_tela(Tela.ARTES)
	var achados := _carregar(pasta_artes, EXT_ARTE)
	artes.assign(achados[0])
	nomes_artes = achados[1]

	if artes.is_empty():
		var aviso := _label("Ainda não tem artes aqui.\nColoque os arquivos em:\n" + pasta_artes,
			int(tamanho_texto * 0.7), cor_apagada)
		aviso.position = Vector2(170, 380)
		tela.add_child(aviso)
	else:
		var rolagem := ScrollContainer.new()
		rolagem.position = Vector2(84, 280)
		rolagem.size = Vector2(1752, 700)
		rolagem.follow_focus = true
		rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tela.add_child(rolagem)
		var margem := MarginContainer.new()
		margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for lado in ["left", "top", "right", "bottom"]:
			margem.add_theme_constant_override("margin_" + lado, 16)
		rolagem.add_child(margem)
		var grade := GridContainer.new()
		grade.columns = colunas_galeria
		grade.add_theme_constant_override("h_separation", 24)
		grade.add_theme_constant_override("v_separation", 24)
		margem.add_child(grade)
		var largura := (1752.0 - 32 - 24 * (colunas_galeria - 1)) / colunas_galeria - 4
		for i in artes.size():
			var m := _miniatura(artes[i], Vector2(largura, largura * 0.66))
			grade.add_child(m)
			miniaturas.append(m)
			m.pressed.connect(_abrir_arte.bind(i))

	botao_voltar_artes = _botao_voltar(tela)


func _miniatura(textura: Texture2D, tamanho: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = tamanho
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	_sem_caixa(b)
	var fundo_m := ColorRect.new()
	fundo_m.color = Color(0, 0, 0, 0.4)
	b.add_child(fundo_m)
	_cheio(fundo_m)
	var imagem := TextureRect.new()
	imagem.texture = textura
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	b.add_child(imagem)
	_cheio(imagem)
	var borda := ReferenceRect.new()
	borda.editor_only = false
	borda.border_color = cor_texto
	borda.border_width = 4.0
	borda.visible = false
	b.add_child(borda)
	_cheio(borda)
	for c in [fundo_m, imagem, borda]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.modulate = Color(0.72, 0.70, 0.80)
	b.focus_entered.connect(_destacar_miniatura.bind(b, borda, true))
	b.focus_exited.connect(_destacar_miniatura.bind(b, borda, false))
	b.mouse_entered.connect(b.grab_focus)
	return b


func _criar_seta() -> void:
	seta = _label("»", tamanho_texto, cor_texto)
	seta.modulate.a = 0.0
	add_child(seta)


func _criar_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.01, 0.05, 0.92)
	overlay.visible = false
	add_child(overlay)
	_cheio(overlay)
	overlay.gui_input.connect(_ao_clicar_overlay)

	arte_grande = TextureRect.new()
	arte_grande.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arte_grande.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arte_grande.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(arte_grande)
	arte_grande.position = Vector2(160, 70)
	arte_grande.size = Vector2(1600, 860)

	arte_nome = _label("", int(tamanho_texto * 0.8), cor_texto)
	arte_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arte_nome.position = Vector2(0, 950)
	arte_nome.size = Vector2(1920, 60)
	overlay.add_child(arte_nome)

	var dica_o := _label("Setas: navegar    ·    Clique ou Esc: fechar",
		int(tamanho_texto * 0.5), cor_apagada)
	dica_o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica_o.position = Vector2(0, 1020)
	dica_o.size = Vector2(1920, 40)
	overlay.add_child(dica_o)

	for lado in [-1, 1]:
		var b := _botao("‹" if lado < 0 else "›", tamanho_texto * 2)
		b.focus_mode = Control.FOCUS_NONE
		b.self_modulate = cor_apagada
		b.position = Vector2(50 if lado < 0 else 1820, 440)
		b.mouse_entered.disconnect(b.grab_focus)
		b.mouse_entered.connect(func(): b.self_modulate = cor_texto)
		b.mouse_exited.connect(func(): b.self_modulate = cor_apagada)
		b.pressed.connect(_navegar_arte.bind(lado))
		overlay.add_child(b)


func _criar_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color.BLACK
	add_child(fade)
	_cheio(fade)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _criar_audio() -> void:
	player_musica = AudioStreamPlayer.new()
	player_musica.bus = preload("res://Configuracoes/config_global.gd").bus_musica()
	add_child(player_musica)
	player_musica.finished.connect(_proxima_musica)
	Musica.manter(get_tree(), musica_fundo, volume_db)   # continua a música do menu, sem recomeçar

func _carregar(pasta: String, extensoes: Array) -> Array:
	var recursos: Array = []
	var nomes := PackedStringArray()
	if not DirAccess.dir_exists_absolute(pasta):
		return [recursos, nomes]
	var arquivos := Array(ResourceLoader.list_directory(pasta))
	arquivos.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	var numero_inicial := RegEx.new()
	numero_inicial.compile("^\\d+[\\s._-]*")
	for arquivo in arquivos:
		if arquivo.ends_with("/") or not extensoes.has(arquivo.get_extension().to_lower()):
			continue
		var recurso = load(pasta.path_join(arquivo))
		if recurso == null:
			continue
		recursos.append(recurso)
		var nome: String = numero_inicial.sub(arquivo.get_basename(), "").replace("_", " ").strip_edges()
		nomes.append(nome if nome != "" else arquivo.get_basename())
	return [recursos, nomes]


func _destacar_item(b: Button, ligado: bool) -> void:
	if ligado:
		Musica.som_navegar(get_tree())
	b.pivot_offset = Vector2(0, b.size.y / 2.0)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "self_modulate", cor_texto if ligado else cor_apagada, 0.22)
	t.tween_property(b, "scale", Vector2.ONE * (1.07 if ligado else 1.0), 0.28)


func _ao_focar_item(b: Button) -> void:
	_destacar_item(b, true)
	var i := botoes_musicas.find(b)
	if i >= 0:
		_tocar_musica(i)


func _atualizar_seta(delta: float) -> void:
	var foco := get_viewport().gui_get_focus_owner()
	var mostrar := foco is Button and foco.get_parent() is VBoxContainer and arte_aberta < 0
	if mostrar:
		var alvo := Vector2(foco.global_position.x - seta.size.x - 22,
			foco.global_position.y + (foco.size.y - seta.size.y) / 2.0)
		if seta.modulate.a < 0.05:
			pos_seta = alvo - Vector2(30, 0)
		pos_seta = pos_seta.lerp(alvo, 1.0 - exp(-delta * 14.0))
	seta.modulate.a = move_toward(seta.modulate.a, 1.0 if mostrar else 0.0, delta * 6.0)
	seta.global_position = pos_seta + Vector2(sin(tempo * 4.0) * 4.0, 0.0)


func _destacar_miniatura(b: Button, borda: ReferenceRect, ligado: bool) -> void:
	if ligado:
		Musica.som_navegar(get_tree())
	borda.visible = ligado
	b.pivot_offset = b.size / 2.0
	b.z_index = 1 if ligado else 0
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE * (1.05 if ligado else 1.0), 0.25)
	t.tween_property(b, "modulate", Color.WHITE if ligado else Color(0.72, 0.70, 0.80), 0.2)


func _mostrar_tela(qual: Tela) -> void:
	if ocupado or qual == tela_atual:
		return
	ocupado = true
	var anterior := tela_atual
	var t := create_tween().set_parallel(true)
	for c in [telas[anterior], titulo, subtitulo, dica]:
		t.tween_property(c, "modulate:a", 0.0, 0.2)
	await t.finished

	tela_atual = qual
	for k in telas:
		telas[k].visible = k == qual
	_atualizar_textos()

	if qual == Tela.PLAYLIST:
		Musica.pausar(get_tree(), 0.4)
		musica_atual = -1
	elif anterior == Tela.PLAYLIST:
		_fade_audio(player_musica, MUDO, 0.4)
		Musica.continuar(get_tree(), 1.0)

	match qual:
		Tela.INICIO:
			botoes_inicio[0 if anterior == Tela.PLAYLIST else 1].grab_focus()
		Tela.PLAYLIST:
			if botoes_musicas.is_empty():
				botao_voltar_playlist.grab_focus()
			else:
				botoes_musicas[0].grab_focus() 
		Tela.ARTES:
			if miniaturas.is_empty():
				botao_voltar_artes.grab_focus()
			else:
				miniaturas[0].grab_focus()

	t = create_tween().set_parallel(true)
	for c in [telas[qual], titulo, subtitulo, dica]:
		t.tween_property(c, "modulate:a", 1.0, 0.3)
	await t.finished
	ocupado = false


func _atualizar_textos() -> void:
	match tela_atual:
		Tela.INICIO:
			titulo.text = "Biblioteca"
			subtitulo.text = "Uma homenagem ao que nossos amigos criaram"
		Tela.PLAYLIST:
			titulo.text = "Playlist"
			subtitulo.text = "Músicas de %s  —  %d faixas" % [nome_musico, musicas.size()]
		Tela.ARTES:
			titulo.text = "Artes"
			subtitulo.text = "Artes de %s  —  %d obras" % [nome_artista, artes.size()]

func _unhandled_input(event: InputEvent) -> void:
	if ocupado:
		return
	if arte_aberta >= 0:
		if event.is_action_pressed("ui_left"):
			_navegar_arte(-1)
		elif event.is_action_pressed("ui_right"):
			_navegar_arte(1)
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			_fechar_arte()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if tela_atual == Tela.INICIO:
			_voltar_ao_menu()
		else:
			_mostrar_tela(Tela.INICIO)


func _voltar_ao_menu() -> void:
	if ocupado:
		return
	ocupado = true
	_fade_audio(player_musica, MUDO, 0.5)
	Musica.continuar(get_tree(), 0.8)          # se estava pausada na playlist, volta para o menu tocando
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.5)
	t.tween_callback(func(): get_tree().change_scene_to_file(cena_menu))


func _tocar_musica(i: int) -> void:
	if i == musica_atual:
		return
	musica_atual = i
	var s := musicas[i]
	s.set("loop", false)          
	player_musica.stream = s
	player_musica.volume_db = volume_db - 18.0
	player_musica.play()
	_fade_audio(player_musica, volume_db, 0.25)
	nome_tocando.text = nomes_musicas[i]


func _proxima_musica() -> void:
	if tela_atual != Tela.PLAYLIST or musicas.is_empty():
		return
	var proxima := (musica_atual + 1) % musicas.size()
	if proxima == musica_atual:
		player_musica.play()
	else:
		botoes_musicas[proxima].grab_focus()  


func _atualizar_tocando(_delta: float) -> void:
	if tela_atual != Tela.PLAYLIST or barra == null:
		return
	var tocando := player_musica.playing and player_musica.stream != null
	if tocando:
		var duracao := player_musica.stream.get_length()
		if duracao > 0.0:
			barra.size.x = barra_fundo.size.x * clampf(player_musica.get_playback_position() / duracao, 0.0, 1.0)
	for i in equalizador.size():
		var alvo := 6.0
		if tocando:
			alvo = 8.0 + 34.0 * absf(sin(tempo * (3.1 + i * 1.7) + i * 1.3)) * absf(sin(tempo * 1.3 + i))
		var e := equalizador[i]
		e.size.y = lerpf(e.size.y, alvo, 0.25)
		e.position = Vector2(1200.0 + i * 14.0, 680.0 - e.size.y)


func _fade_audio(p: AudioStreamPlayer, para_db: float, duracao: float, pausar := false) -> void:
	var t := create_tween()
	t.tween_property(p, "volume_db", para_db, duracao)
	if pausar:
		t.tween_callback(func(): p.stream_paused = true)
	elif para_db <= MUDO:
		t.tween_callback(p.stop)


func _abrir_arte(i: int) -> void:
	if arte_aberta >= 0:
		return
	arte_aberta = i
	get_viewport().gui_release_focus()
	_mostrar_arte(i)
	overlay.visible = true
	overlay.modulate.a = 0.0
	arte_grande.pivot_offset = arte_grande.size / 2.0
	arte_grande.scale = Vector2.ONE * 0.85
	var t := create_tween().set_parallel(true)
	t.tween_property(overlay, "modulate:a", 1.0, 0.25)
	t.tween_property(arte_grande, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _mostrar_arte(i: int) -> void:
	arte_grande.texture = artes[i]
	arte_nome.text = "%s     %d / %d" % [nomes_artes[i], i + 1, artes.size()]


func _navegar_arte(direcao: int) -> void:
	if arte_aberta < 0:
		return
	arte_aberta = posmod(arte_aberta + direcao, artes.size())
	_mostrar_arte(arte_aberta)
	arte_grande.modulate.a = 0.0
	arte_grande.position.x = 160 + direcao * 60
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(arte_grande, "modulate:a", 1.0, 0.25)
	t.tween_property(arte_grande, "position:x", 160.0, 0.3)


func _fechar_arte() -> void:
	if arte_aberta < 0:
		return
	var voltar_para := miniaturas[arte_aberta]
	arte_aberta = -1
	var t := create_tween()
	t.tween_property(overlay, "modulate:a", 0.0, 0.2)
	t.tween_callback(func(): overlay.visible = false)
	voltar_para.grab_focus()


func _ao_clicar_overlay(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fechar_arte()
