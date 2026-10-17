extends Control

@export_group("Arquivos")
@export var video_fundo: VideoStream
@export var fonte_titulo: Font
@export var fonte_opcoes: Font
@export_file("*.tscn") var cena_do_jogo: String = ""
@export_file("*.tscn") var cena_biblioteca: String = "res://Biblioteca.tscn"
@export var musica_menu: AudioStream
@export_range(-40.0, 6.0, 0.5) var volume_musica_db: float = -6.0

@export_group("Aparência")
@export var tamanho_titulo: int = 110
@export var tamanho_opcoes: int = 44
@export var espaco_entre_opcoes: int = 14
@export var cor_texto: Color = Color(0.96, 0.93, 0.86)
@export var cor_apagada: Color = Color(0.60, 0.56, 0.74)
@export var cor_fundo_provisorio: Color = Color(0.10, 0.07, 0.17)
@export var escala_selecionada: float = 1.08

@onready var fundo_provisorio: ColorRect = $FundoProvisorio
@onready var fundo: VideoStreamPlayer = $Fundo
@onready var titulo: Label = $Titulo
@onready var opcoes: VBoxContainer = $Opcoes
@onready var seta: Control = $Seta
@onready var sublinhado: ColorRect = $Sublinhado
@onready var fade: ColorRect = $Fade

var botoes: Array[Button] = []
var selecionado: Button = null
var pos_seta := Vector2.ZERO
var tempo := 0.0
var tween_selecao: Tween
var saindo := false
var musica: AudioStreamPlayer

func _ready() -> void:
	_configurar_fundo()
	_configurar_textos()
	_configurar_musica()

	for no in [fundo, fundo_provisorio, titulo, seta, sublinhado, fade]:
		no.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for filho in opcoes.get_children():
		if filho is Button:
			_configurar_botao(filho)
			botoes.append(filho)

	$Opcoes/Iniciar.pressed.connect(_on_iniciar)
	$Opcoes/Config.pressed.connect(_on_config)
	$Opcoes/Sair.pressed.connect(_on_sair)
	if has_node("Opcoes/Biblioteca"):
		$Opcoes/Biblioteca.pressed.connect(_on_biblioteca)

	await get_tree().process_frame
	_animacao_de_entrada()


func _process(delta: float) -> void:
	tempo += delta
	seta.global_position = pos_seta + Vector2(sin(tempo * 4.0) * 4.0, 0.0)



func _configurar_fundo() -> void:
	for no in [fundo_provisorio, fundo, fade]:
		no.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo_provisorio.color = cor_fundo_provisorio
	fade.color = Color.BLACK
	fundo.expand = true
	if video_fundo:
		fundo.stream = video_fundo
		fundo.set("loop", true)              
		fundo.finished.connect(fundo.play)  
		fundo.play()
		fundo_provisorio.visible = false
	else:
		fundo.visible = false             


func _configurar_musica() -> void:
	if musica_menu == null:
		return
	musica_menu.set("loop", true)         
	musica = AudioStreamPlayer.new()
	musica.name = "Musica"
	musica.stream = musica_menu
	musica.volume_db = -40.0
	add_child(musica)
	musica.play()
	create_tween().tween_property(musica, "volume_db", volume_musica_db, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _abaixar_musica(duracao: float) -> void:
	if musica:
		create_tween().tween_property(musica, "volume_db", -40.0, duracao) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _configurar_textos() -> void:
	if fonte_titulo:
		titulo.add_theme_font_override("font", fonte_titulo)
	titulo.add_theme_font_size_override("font_size", tamanho_titulo)
	titulo.add_theme_color_override("font_color", cor_texto)
	titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	titulo.add_theme_constant_override("shadow_offset_x", 4)
	titulo.add_theme_constant_override("shadow_offset_y", 5)

	opcoes.add_theme_constant_override("separation", espaco_entre_opcoes)

	if seta is Label:
		if fonte_opcoes:
			seta.add_theme_font_override("font", fonte_opcoes)
		seta.add_theme_font_size_override("font_size", tamanho_opcoes)
		seta.add_theme_color_override("font_color", cor_texto)

	sublinhado.color = cor_texto
	sublinhado.size = Vector2(0, 3)


func _configurar_botao(b: Button) -> void:
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if fonte_opcoes:
		b.add_theme_font_override("font", fonte_opcoes)
	b.add_theme_font_size_override("font_size", tamanho_opcoes)
	for nome in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(nome, Color.WHITE)
	var vazio := StyleBoxEmpty.new()
	for nome in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(nome, vazio)
	b.self_modulate = cor_apagada
	b.focus_entered.connect(_selecionar.bind(b))
	b.mouse_entered.connect(b.grab_focus)


func _animacao_de_entrada() -> void:
	fade.modulate.a = 1.0
	titulo.modulate.a = 0.0
	seta.modulate.a = 0.0
	sublinhado.modulate.a = 0.0
	for b in botoes:
		b.modulate.a = 0.0
	var y_final := titulo.position.y
	titulo.position.y += 30

	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(fade, "modulate:a", 0.0, 0.9)
	t.parallel().tween_property(titulo, "modulate:a", 1.0, 1.1).set_delay(0.3)
	t.parallel().tween_property(titulo, "position:y", y_final, 1.1).set_delay(0.3)
	for i in botoes.size():
		t.parallel().tween_property(botoes[i], "modulate:a", 1.0, 0.5).set_delay(0.8 + i * 0.12)
	t.tween_callback(func():
		if selecionado == null:
			botoes[0].grab_focus())

func _selecionar(b: Button) -> void:
	if b == selecionado:
		return
	var primeira_vez := selecionado == null
	selecionado = b
	_tocar("SomNavegar")

	if tween_selecao:
		tween_selecao.kill()
	tween_selecao = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for outro in botoes:
		var e_ele := outro == b
		outro.pivot_offset = Vector2(0, outro.size.y / 2.0)
		tween_selecao.tween_property(outro, "self_modulate",
			cor_texto if e_ele else cor_apagada, 0.25)
		tween_selecao.tween_property(outro, "scale",
			Vector2.ONE * (escala_selecionada if e_ele else 1.0), 0.3)

	var alvo := Vector2(
		b.global_position.x - seta.size.x - 22,
		b.global_position.y + (b.size.y - seta.size.y) / 2.0)
	if primeira_vez:
		pos_seta = alvo - Vector2(40, 0)
	tween_selecao.tween_property(self, "pos_seta", alvo, 0.35)
	tween_selecao.tween_property(seta, "modulate:a", 1.0, 0.25)

	var meio_y := b.global_position.y + b.size.y / 2.0
	sublinhado.global_position = Vector2(
		b.global_position.x, meio_y + b.size.y / 2.0 * escala_selecionada - 6)
	sublinhado.size.x = 0
	sublinhado.modulate.a = 1.0
	tween_selecao.tween_property(sublinhado, "size:x",
		(_largura_texto(b) + 30) * escala_selecionada, 0.4) \
		.set_trans(Tween.TRANS_CUBIC)


func _pulsar(b: Button) -> void:
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE * (escala_selecionada + 0.08), 0.08)
	t.tween_property(b, "scale", Vector2.ONE * escala_selecionada, 0.2)


func _largura_texto(b: Button) -> float:
	var fonte := b.get_theme_font("font")
	var tamanho := b.get_theme_font_size("font_size")
	return fonte.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


func _tocar(nome_do_no: String) -> void:
	if has_node(nome_do_no):
		get_node(nome_do_no).play()

func _on_iniciar() -> void:
	if saindo:
		return
	_pulsar($Opcoes/Iniciar)
	_tocar("SomConfirmar")
	if cena_do_jogo == "":
		push_warning("Escolha a cena do jogo no campo 'Cena Do Jogo' do nó Menu.")
		return
	saindo = true
	_abaixar_musica(0.6)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.6)
	t.tween_callback(func(): get_tree().change_scene_to_file(cena_do_jogo))


func _on_biblioteca() -> void:
	if saindo:
		return
	_pulsar($Opcoes/Biblioteca)
	_tocar("SomConfirmar")
	saindo = true
	_abaixar_musica(0.5)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.5)
	t.tween_callback(func(): get_tree().change_scene_to_file(cena_biblioteca))


func _on_config() -> void:
	_pulsar($Opcoes/Config)
	_tocar("SomConfirmar")
	print("Configurações: ainda não feito")


func _on_sair() -> void:
	if saindo:
		return
	saindo = true
	_pulsar($Opcoes/Sair)
	_tocar("SomConfirmar")
	_abaixar_musica(0.4)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.4)
	t.tween_callback(get_tree().quit)
