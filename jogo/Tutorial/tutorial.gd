extends Control
## Mini tutorial antes do jogo (Menu -> Jogar -> Tutorial -> Jogo).
## Uma tela só, com 4 quadros: elementos, como lutar, os dragões e cuidado com os cenários.
## Botão "Pular tutorial" (ou Esc / Enter / Espaço) vai para o jogo.
## Os textos estão na função _montar_quadros, para editar fácil.

@export_group("Arquivos")
@export_file("*.tscn") var cena_do_jogo: String = "res://jogo/jogo.tscn"
@export var imagem_elementos: Texture2D          ## a imagem do ciclo dos elementos
@export var fonte_titulo: Font                   ## vazio = CinzelDecorative-Bold
@export var fonte_texto: Font                    ## vazio = Kalam-Regular
@export var video_fundo: VideoStream             ## vazio = vídeo do menu (escurecido)
@export var musica: AudioStream                  ## vazio = música do menu
@export_range(-40.0, 6.0, 0.5) var volume_musica_db: float = -10.0

@export_group("Cores")
@export var cor_titulo: Color = Color(1.0, 0.84, 0.45)
@export var cor_texto: Color = Color(0.95, 0.92, 0.86)
@export var cor_destaque: Color = Color(1.0, 0.72, 0.35)
@export var cor_apagada: Color = Color(0.62, 0.58, 0.74)

const ICONES := ["res://icones/fogo.png", "res://icones/agua.png", "res://icones/terra.png", "res://icones/vento.png"]
const NOMES := ["Fogo", "Água", "Terra", "Ar"]
const TECLAS := ["Q", "W", "E", "R"]
const CORES_EL := [Color(1.0, 0.5, 0.25), Color(0.4, 0.7, 1.0), Color(0.72, 0.52, 0.34), Color(0.85, 0.94, 1.0)]

var quadros: Array[Control] = []
var saindo := false
var tela := Vector2(1920, 1080)
var tex_icones: Array[Texture2D] = []
const Musica := preload("res://Menu/musica_global.gd")
var cortina: ColorRect


func _ready() -> void:
	tela = get_viewport_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if fonte_titulo == null:
		fonte_titulo = _carregar("res://Fontes/Fonte Titulo/CinzelDecorative-Bold.ttf")
	if fonte_texto == null:
		fonte_texto = _carregar("res://Fontes/Fonte Opções/Kalam/Kalam-Regular.ttf")
	if imagem_elementos == null:
		imagem_elementos = _carregar((get_script() as Script).resource_path.get_base_dir().path_join("elementos.png"))
	if video_fundo == null:
		video_fundo = _carregar("res://Menu/menu_animado.ogv")
	if musica == null:
		musica = _carregar("res://Menu/musica_menu.ogg")
	for p in ICONES:
		tex_icones.append(_carregar(p))

	_criar_fundo()
	_montar_quadros()
	_criar_rodape()

	cortina = ColorRect.new()
	cortina.color = Color.BLACK
	cortina.size = tela
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cortina)
	create_tween().tween_property(cortina, "color:a", 0.0, 0.6)
	for i in quadros.size():                       # os quadros entram um depois do outro
		var q := quadros[i]
		var y := q.position.y
		q.modulate.a = 0.0
		q.position.y = y + 40
		var t := create_tween().set_parallel(true)
		t.tween_property(q, "modulate:a", 1.0, 0.4).set_delay(0.3 + i * 0.15)
		t.tween_property(q, "position:y", y, 0.5).set_delay(0.3 + i * 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	Musica.manter(get_tree(), musica, volume_musica_db)   # mesma música do menu, sem recomeçar


func _carregar(caminho: String) -> Resource:
	return load(caminho) if ResourceLoader.exists(caminho) else null


# ================================================================ fundo

func _criar_fundo() -> void:
	var base := ColorRect.new()
	base.color = Color(0.07, 0.04, 0.12)
	base.size = tela
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	if video_fundo:
		var v := VideoStreamPlayer.new()
		v.stream = video_fundo
		v.size = tela
		v.expand = true
		v.loop = true
		v.autoplay = true
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
	var escuro := ColorRect.new()
	escuro.color = Color(0.04, 0.02, 0.08, 0.78)
	escuro.size = tela
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(escuro)
	# brasinhas subindo devagar
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = Vector2(tela.x / 2, tela.y + 20)
	p.emission_rect_extents = Vector2(tela.x / 2, 10)
	p.direction = Vector2(0, -1)
	p.spread = 15.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.85, 0.6, 1.0, 0.0))
	rampa.add_point(0.2, Color(0.85, 0.6, 1.0, 0.7))
	rampa.set_color(rampa.get_point_count() - 1, Color(1.0, 0.7, 0.4, 0.0))
	p.color_ramp = rampa
	add_child(p)


# ================================================================ peças de texto

func _titulo(texto: String, tamanho: int = 72, cor: Color = Color(-1, 0, 0)) -> Label:
	var l := Label.new()
	l.text = texto
	if fonte_titulo:
		l.add_theme_font_override("font", fonte_titulo)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor_titulo if cor.r < 0 else cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Texto com destaques: use [b]palavra[/b] para a cor de destaque.
func _texto(bb: String, tamanho: int = 34, largura: float = 900.0, centro: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(largura, 0)
	r.size = Vector2(largura, 10)
	if fonte_texto:
		r.add_theme_font_override("normal_font", fonte_texto)
		r.add_theme_font_override("bold_font", fonte_texto)
	r.add_theme_font_size_override("normal_font_size", tamanho)
	r.add_theme_font_size_override("bold_font_size", tamanho)
	r.add_theme_color_override("default_color", cor_texto)
	r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	r.add_theme_constant_override("shadow_offset_x", 2)
	r.add_theme_constant_override("shadow_offset_y", 2)
	r.add_theme_constant_override("line_separation", 2)
	var hex := cor_destaque.to_html(false)
	var txt := bb.replace("[b]", "[color=#" + hex + "]").replace("[/b]", "[/color]")
	r.text = ("[center]" + txt + "[/center]") if centro else txt
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _icone(i: int, tam: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex_icones[i] if i < tex_icones.size() else null
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(tam, tam)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _painel(tamanho: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.05, 0.15, 0.82)
	st.border_color = Color(0.55, 0.4, 0.8, 0.8)
	st.set_border_width_all(3)
	st.set_corner_radius_all(14)
	st.content_margin_left = 50
	st.content_margin_right = 50
	st.content_margin_top = 34
	st.content_margin_bottom = 34
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = tamanho
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Página = título em cima + painel no meio (o conteúdo vai dentro do painel).


## Um quadro = título + painel. Devolve o painel (o conteúdo vai dentro dele).
func _quadro(titulo: String, pos: Vector2, tam: Vector2) -> PanelContainer:
	var q := Control.new()
	q.position = pos
	q.size = tam
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(q)
	var t := _titulo(titulo, 40)
	t.size = Vector2(tam.x, 56)
	q.add_child(t)
	var painel := _painel(Vector2(tam.x, tam.y - 62))
	painel.position = Vector2(0, 62)
	var st: StyleBoxFlat = painel.get_theme_stylebox("panel")
	st.content_margin_left = 30
	st.content_margin_right = 30
	st.content_margin_top = 20
	st.content_margin_bottom = 20
	q.add_child(painel)
	quadros.append(q)
	return painel


# ================================================================ QUADROS (textos aqui)

func _montar_quadros() -> void:
	var m := 40.0                                   # margem
	var w := (tela.x - m * 3) / 2.0                 # largura de cada quadro
	var h := 465.0
	var y0 := 18.0
	var y1 := y0 + h + 16.0

	# ---------------------------------------------------------- os elementos
	var p1 := _quadro("Os Elementos", Vector2(m, y0), Vector2(w, h))
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 30)
	h1.alignment = BoxContainer.ALIGNMENT_CENTER
	p1.add_child(h1)
	var img := TextureRect.new()
	img.texture = imagem_elementos
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(290, 290)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h1.add_child(img)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	h1.add_child(col)
	col.add_child(_texto("Cada elemento [b]vence[/b] o próximo, seguindo a seta:", 24, 500))
	for par in [[0, 3], [3, 2], [2, 1], [1, 0]]:      # fogo>ar, ar>terra, terra>água, água>fogo
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 12)
		linha.add_child(_icone(par[0], 36))
		linha.add_child(_texto("[b]%s[/b] vence [b]%s[/b]" % [NOMES[par[0]], NOMES[par[1]]], 25, 215))
		linha.add_child(_icone(par[1], 36))
		col.add_child(linha)
	var teclas := HBoxContainer.new()
	teclas.add_theme_constant_override("separation", 8)
	for i in 4:
		teclas.add_child(_icone(i, 36))
		teclas.add_child(_texto("[b]%s[/b]" % TECLAS[i], 28, 50))
	col.add_child(teclas)
	col.add_child(_texto("Teclas [b]Q W E R[/b] (ou [b]1 2 3 4[/b])", 22, 500))

	# ---------------------------------------------------------- como lutar
	var p2 := _quadro("Como Lutar", Vector2(m * 2 + w, y0), Vector2(w, h))
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 4)
	lista.alignment = BoxContainer.ALIGNMENT_CENTER
	p2.add_child(lista)
	var itens := [
		["Corrida:", "pule as pedras com [b]Espaço[/b] e ande com [b]← →[/b]."],
		["Sequências:", "os elementos que o dragão vai lançar. Aperte, na ordem, o que [b]vence[/b] cada um para [b]bloquear[/b] o ataque."],
		["Errou?", "a sequência [b]recomeça[/b], mas o tempo continua correndo."],
		["Perfeito!", "rápido e sem errar: o ataque [b]volta no dragão[/b]."],
		["Vulnerável:", "o dragão abre a guarda. Lance [b]magias[/b] nele — a fraqueza dele dói mais!"],
		["Bênçãos:", "ao derrotar um dragão, escolha [b]1 de 3 cartas[/b]."],
	]
	for it in itens:
		lista.add_child(_texto("[b]%s[/b]  %s" % [it[0], it[1]], 23, w - 60))

	# ---------------------------------------------------------- os dragões
	var p3 := _quadro("Os Dragões", Vector2(m, y1), Vector2(w, h))
	var grade := VBoxContainer.new()
	grade.add_theme_constant_override("separation", 4)
	grade.alignment = BoxContainer.ALIGNMENT_CENTER
	p3.add_child(grade)
	var dragoes := [
		[[0], "Fogo", "sequências aparecem [b]mais rápido[/b]."],
		[[1], "Água", "os elementos [b]somem[/b]: memorize!"],
		[[2], "Terra", "cada erro tira [b]2 corações[/b]."],
		[[3], "Ar", "leia [b]de trás para frente[/b] e cuidado com [b]ataques duplos[/b]."],
		[[0, 1, 2, 3], "Ancestral", "usa o jeito de [b]todos[/b] e resiste a tudo."],
		[[], "???", "ninguém voltou para contar..."],
	]
	for d in dragoes:
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 12)
		var icones := HBoxContainer.new()
		icones.custom_minimum_size = Vector2(150, 44)
		icones.alignment = BoxContainer.ALIGNMENT_CENTER
		icones.add_theme_constant_override("separation", 1)
		for e in d[0]:
			icones.add_child(_icone(e, 44 if (d[0] as Array).size() == 1 else 34))
		if (d[0] as Array).is_empty():
			icones.add_child(_titulo("?", 36, Color(0.9, 0.2, 0.25)))
		linha.add_child(icones)
		var nome := _titulo(d[1], 28, Color(0.9, 0.2, 0.25) if d[1] == "???" else cor_titulo)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nome.custom_minimum_size = Vector2(210, 0)
		linha.add_child(nome)
		linha.add_child(_texto(d[2], 23, w - 440))
		grade.add_child(linha)

	# ---------------------------------------------------------- cuidado
	var p4 := _quadro("Cuidado!", Vector2(m * 2 + w, y1), Vector2(w, h))
	var c4 := VBoxContainer.new()
	c4.add_theme_constant_override("separation", 22)
	c4.alignment = BoxContainer.ALIGNMENT_CENTER
	p4.add_child(c4)
	c4.add_child(_texto("Os [b]cenários se adaptam[/b] com base no dragão enfrentado.", 32, w - 60, true))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 14)
	for ef in [[0, "Chamas avançam pela esquerda"], [1, "O chão fica escorregadio"],
			[2, "Tremores e espinhos de pedra"], [3, "Rajadas de vento te empurram"]]:
		var l := HBoxContainer.new()
		l.add_theme_constant_override("separation", 10)
		l.add_child(_icone(ef[0], 40))
		l.add_child(_texto(ef[1], 23, 340))
		g.add_child(l)
	var centro := CenterContainer.new()
	centro.add_child(g)
	c4.add_child(centro)
	c4.add_child(_texto("Fique de olho nos avisos e se adapte!", 26, w - 60, true))


# ================================================================ rodapé: botão de pular

func _criar_rodape() -> void:
	var y := tela.y - 92.0
	var pular := Button.new()
	pular.text = "Pular tutorial  ››"
	pular.flat = true
	pular.focus_mode = Control.FOCUS_NONE
	if fonte_texto:
		pular.add_theme_font_override("font", fonte_texto)
	pular.add_theme_font_size_override("font_size", 40)
	pular.add_theme_color_override("font_color", cor_titulo)
	pular.add_theme_color_override("font_hover_color", Color.WHITE)
	pular.add_theme_color_override("font_pressed_color", cor_destaque)
	pular.position = Vector2(tela.x - 380, y - 6)
	pular.pressed.connect(_ir_para_jogo)
	pular.mouse_entered.connect(func():
		pular.pivot_offset = pular.size / 2.0
		create_tween().tween_property(pular, "scale", Vector2.ONE * 1.08, 0.1))
	pular.mouse_exited.connect(func(): create_tween().tween_property(pular, "scale", Vector2.ONE, 0.1))
	add_child(pular)
	# pulsa devagar para chamar atenção
	var tp := create_tween().set_loops()
	tp.tween_property(pular, "modulate:a", 0.65, 0.9)
	tp.tween_property(pular, "modulate:a", 1.0, 0.9)


func _unhandled_input(event: InputEvent) -> void:
	if saindo or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		_ir_para_jogo()


func _ir_para_jogo() -> void:
	if saindo:
		return
	saindo = true
	var t := create_tween().set_parallel(true)
	t.tween_property(cortina, "color:a", 1.0, 0.6)
	Musica.parar(get_tree(), 0.6)                  # o jogo tem as próprias músicas
	t.chain().tween_callback(func(): get_tree().change_scene_to_file(cena_do_jogo))
