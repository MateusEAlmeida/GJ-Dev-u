extends Control
## Tela de Configurações: Gráficos (Mínimo/Médio/Máximo), Volume da música e Volume geral.
## ↑ ↓ escolhem a linha · ← → mudam o valor · Enter/Esc em "Voltar" volta ao menu. Mouse também funciona.
## Fontes, tamanhos e cores ficam no Inspetor (nó raiz desta cena).

const Config := preload("res://Configuracoes/config_global.gd")
const Musica := preload("res://Menu/musica_global.gd")

@export_group("Arquivos")
@export_file("*.tscn") var cena_menu: String = "res://Menu/Menu.tscn"
@export var video_fundo: VideoStream                 ## vazio = vídeo do menu
@export var som_navegar: AudioStream                 ## opcional: "tic" ao trocar de opção

@export_group("Fontes")
@export var fonte_titulo: Font                       ## vazio = CinzelDecorative-Bold
@export var fonte_texto: Font                        ## vazio = Kalam-Regular
@export var tamanho_titulo: int = 96
@export var tamanho_texto: int = 46

@export_group("Cores")
@export var cor_titulo: Color = Color(1.0, 0.84, 0.45)
@export var cor_texto: Color = Color(0.96, 0.93, 0.86)
@export var cor_apagada: Color = Color(0.60, 0.56, 0.74)
@export var cor_destaque: Color = Color(1.0, 0.82, 0.35)

var linhas: Array[Control] = []     # cada linha: HBox com nome + valor
var valores: Array[HBoxContainer] = []
var sel := 0
var saindo := false
var cortina: ColorRect
var tela := Vector2(1920, 1080)
var som: AudioStreamPlayer


func _ready() -> void:
	tela = get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Config.aplicar()
	Musica.manter(get_tree(), null)
	if fonte_titulo == null:
		fonte_titulo = _carregar("res://Fontes/Fonte Titulo/CinzelDecorative-Bold.ttf")
	if fonte_texto == null:
		fonte_texto = _carregar("res://Fontes/Fonte Opções/Kalam/Kalam-Regular.ttf")
	if video_fundo == null:
		video_fundo = _carregar("res://Menu/menu_animado.ogv")
	_criar_fundo()
	_criar_conteudo()
	if som_navegar:
		som = AudioStreamPlayer.new()
		som.stream = som_navegar
		add_child(som)
	cortina = ColorRect.new()
	cortina.color = Color.BLACK
	cortina.size = tela
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cortina)
	create_tween().tween_property(cortina, "color:a", 0.0, 0.5)
	_atualizar_valores()
	_selecionar(0, true)


func _carregar(caminho: String) -> Resource:
	return load(caminho) if ResourceLoader.exists(caminho) else null


func _criar_fundo() -> void:
	var base := ColorRect.new()
	base.color = Color(0.07, 0.04, 0.12)
	base.size = tela
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	if video_fundo and Config.graficos > 0:
		var v := VideoStreamPlayer.new()
		v.stream = video_fundo
		v.size = tela
		v.expand = true
		v.loop = true
		v.autoplay = true
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
	var escuro := ColorRect.new()
	escuro.color = Color(0.04, 0.02, 0.08, 0.72)
	escuro.size = tela
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(escuro)


func _label(texto: String, tamanho: int, cor: Color, fonte: Font) -> Label:
	var l := Label.new()
	l.text = texto
	if fonte:
		l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _criar_conteudo() -> void:
	var titulo := _label("Configurações", tamanho_titulo, cor_titulo, fonte_titulo)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size = Vector2(tela.x, 140)
	titulo.position = Vector2(0, 120)
	add_child(titulo)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 26)
	caixa.position = Vector2(tela.x / 2 - 520, 340)
	caixa.size = Vector2(1040, 500)
	add_child(caixa)
	for nome in ["Gráficos", "Música", "Som geral", "Voltar"]:
		var linha := HBoxContainer.new()
		linha.custom_minimum_size = Vector2(1040, 78)
		linha.mouse_filter = Control.MOUSE_FILTER_STOP
		caixa.add_child(linha)
		var seta := _label("›", tamanho_texto, cor_destaque, fonte_texto)
		seta.name = "Seta"
		seta.custom_minimum_size = Vector2(50, 0)
		seta.modulate.a = 0.0
		linha.add_child(seta)
		var n := _label(nome, tamanho_texto, cor_apagada, fonte_texto)
		n.name = "Nome"
		n.custom_minimum_size = Vector2(360, 0)
		linha.add_child(n)
		var v := HBoxContainer.new()                  # ‹  [blocos]  texto  ›
		v.name = "Valor"
		v.alignment = BoxContainer.ALIGNMENT_BEGIN
		v.add_theme_constant_override("separation", 14)
		v.custom_minimum_size = Vector2(620, 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(v)
		if nome != "Voltar":
			v.add_child(_label("‹", tamanho_texto, cor_destaque, fonte_texto))
			var blocos := HBoxContainer.new()
			blocos.name = "Blocos"
			blocos.add_theme_constant_override("separation", 4)
			blocos.alignment = BoxContainer.ALIGNMENT_CENTER
			blocos.mouse_filter = Control.MOUSE_FILTER_IGNORE
			blocos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for b in 10:
				var r := ColorRect.new()
				r.custom_minimum_size = Vector2(22, 30)
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				blocos.add_child(r)
			v.add_child(blocos)
			var txt := _label("", tamanho_texto, cor_texto, fonte_texto)
			txt.name = "Texto"
			txt.custom_minimum_size = Vector2(150, 0)
			txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(txt)
			v.add_child(_label("›", tamanho_texto, cor_destaque, fonte_texto))
		valores.append(v)
		linhas.append(linha)
		var idx := linhas.size() - 1
		linha.mouse_entered.connect(func(): _selecionar(idx))
		linha.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_selecionar(idx)
				if idx == 3:
					_voltar()
				elif ev.button_index == MOUSE_BUTTON_LEFT:
					# clicou na metade esquerda do valor = diminui; direita = aumenta
					var x: float = (ev as InputEventMouseButton).position.x
					_mudar(-1 if x < 410 + 310 else 1)
				elif ev.button_index == MOUSE_BUTTON_RIGHT:
					_mudar(-1))

	var dica := _label("↑ ↓ escolher   ·   ← → mudar   ·   Esc voltar", 28, cor_apagada, fonte_texto)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.size = Vector2(tela.x, 40)
	dica.position = Vector2(0, tela.y - 110)
	dica.modulate.a = 0.7
	add_child(dica)


func _mostrar(i: int, texto: String, porcento: int) -> void:
	var v := valores[i]
	(v.get_node("Texto") as Label).text = texto
	var blocos: HBoxContainer = v.get_node("Blocos")
	blocos.visible = porcento >= 0
	var cheios := int(round(maxi(porcento, 0) / 10.0))
	for b in blocos.get_child_count():
		(blocos.get_child(b) as ColorRect).color = cor_destaque if b < cheios else Color(cor_apagada, 0.35)


func _atualizar_valores() -> void:
	_mostrar(0, Config.NOMES_GRAFICOS[Config.graficos], -1)
	_mostrar(1, "%d%%" % Config.volume_musica, Config.volume_musica)
	_mostrar(2, "%d%%" % Config.volume_geral, Config.volume_geral)


func _selecionar(i: int, primeira := false) -> void:
	if saindo:
		return
	i = wrapi(i, 0, linhas.size())
	if i == sel and not primeira:
		return
	sel = i
	if not primeira:
		_som_navegar()
	for k in linhas.size():
		var on := k == sel
		var linha := linhas[k]
		var t := create_tween().set_parallel(true)
		t.tween_property(linha.get_node("Seta"), "modulate:a", 1.0 if on else 0.0, 0.15)
		(linha.get_node("Nome") as Label).add_theme_color_override("font_color", cor_destaque if on else cor_apagada)
		linha.get_node("Valor").modulate = Color.WHITE if on else Color(1, 1, 1, 0.6)
		linha.pivot_offset = Vector2(0, linha.size.y / 2.0)
		t.tween_property(linha, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _som_navegar() -> void:
	if som:
		som.play()                                     # som próprio (campo Som Navegar)
	else:
		Musica.som_navegar(get_tree())                 # som padrão do jogo


func _mudar(passo: int) -> void:
	match sel:
		0:
			Config.graficos = wrapi(Config.graficos + passo, 0, 3)
		1:
			Config.volume_musica = clampi(Config.volume_musica + passo * 10, 0, 100)
		2:
			Config.volume_geral = clampi(Config.volume_geral + passo * 10, 0, 100)
		_:
			return
	Config.salvar()
	Config.aplicar()
	_atualizar_valores()
	var v := valores[sel]
	v.pivot_offset = v.size / 2.0
	var t := create_tween()
	t.tween_property(v, "scale", Vector2.ONE * 1.08, 0.06)
	t.tween_property(v, "scale", Vector2.ONE, 0.12)
	_som_navegar()


func _unhandled_input(event: InputEvent) -> void:
	if saindo or not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_UP, KEY_W:
			_selecionar(sel - 1)
		KEY_DOWN, KEY_S:
			_selecionar(sel + 1)
		KEY_LEFT, KEY_A:
			_mudar(-1)
		KEY_RIGHT, KEY_D:
			_mudar(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if sel == 3:
				_voltar()
			elif not event.echo:
				_mudar(1)
		KEY_ESCAPE:
			_voltar()
		_:
			return
	get_viewport().set_input_as_handled()


func _voltar() -> void:
	if saindo:
		return
	saindo = true
	Config.salvar()
	var t := create_tween()
	t.tween_property(cortina, "color:a", 1.0, 0.4)
	t.tween_callback(func(): get_tree().change_scene_to_file(cena_menu))
