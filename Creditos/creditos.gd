extends Control
## Créditos que sobem pela tela com a música do menu.
## Enter/Espaço (segurar) = acelera · Esc = volta ao menu. No fim volta sozinho.
## Os nomes e títulos ficam em _montar_creditos(), fácil de editar.

signal terminou                                    ## usado quando os créditos passam no fim do jogo

const Musica := preload("res://Menu/musica_global.gd")
const Config := preload("res://Configuracoes/config_global.gd")

@export_group("Arquivos")
@export_file("*.tscn") var cena_menu: String = "res://Menu/Menu.tscn"
@export var musica: AudioStream                    ## vazio = música do menu
@export var video_fundo: VideoStream               ## vazio = vídeo do menu (escurecido)
@export_range(-40.0, 6.0, 0.5) var volume_musica_db: float = -21.5

@export var nome_do_jogo: String = "Immutable Roots"   ## vazio = usa o nome do projeto (Configurações do Projeto)

@export var voltar_ao_menu_no_fim: bool = true      ## false = no fim só avisa (o jogo mostra as estatísticas)

@export_group("Fontes e cores")
@export var fonte_titulo: Font                     ## vazio = CinzelDecorative-Bold
@export var fonte_texto: Font                      ## vazio = Kalam-Regular
@export var cor_titulo: Color = Color(1.0, 0.84, 0.45)
@export var cor_texto: Color = Color(0.96, 0.93, 0.86)
@export var cor_apagada: Color = Color(0.62, 0.58, 0.76)

@export_group("Rolagem")
@export var velocidade: float = 70.0               ## pixels por segundo
@export var velocidade_rapida: float = 420.0       ## segurando Enter/Espaço

var tela := Vector2(1920, 1080)
var lista: VBoxContainer
var cortina: ColorRect
var saindo := false


func _ready() -> void:
	tela = get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Config.aplicar()
	if fonte_titulo == null:
		fonte_titulo = _carregar("res://Fontes/Fonte Titulo/CinzelDecorative-Bold.ttf")
	if fonte_texto == null:
		fonte_texto = _carregar("res://Fontes/Fonte Opções/Kalam/Kalam-Regular.ttf")
	if musica == null:
		musica = _carregar("res://Menu/musica_menu.ogg")
	if video_fundo == null:
		video_fundo = _carregar("res://Menu/menu_animado.ogv")
	Musica.tocar(get_tree(), musica, volume_musica_db, 2.0)

	_criar_fundo()
	lista = VBoxContainer.new()
	lista.alignment = BoxContainer.ALIGNMENT_BEGIN
	lista.add_theme_constant_override("separation", 14)
	lista.custom_minimum_size = Vector2(tela.x, 0)
	add_child(lista)
	_montar_creditos()
	lista.position = Vector2(0, tela.y + 40)

	var faixa := ColorRect.new()                 # faixa escura embaixo, para a dica não ficar por cima dos nomes
	faixa.color = Color(0.03, 0.01, 0.06, 0.92)
	faixa.size = Vector2(tela.x, 80)
	faixa.position = Vector2(0, tela.y - 80)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)
	var dica := _texto("Segure Enter para acelerar   ·   Esc para " + ("sair" if voltar_ao_menu_no_fim else "pular"), 24, cor_apagada)
	dica.size = Vector2(tela.x, 36)
	dica.position = Vector2(0, tela.y - 50)
	dica.modulate.a = 0.6
	add_child(dica)

	cortina = ColorRect.new()
	cortina.color = Color.BLACK
	cortina.size = tela
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cortina)
	create_tween().tween_property(cortina, "color:a", 0.0, 0.8)


func _carregar(caminho: String) -> Resource:
	return load(caminho) if ResourceLoader.exists(caminho) else null


func _criar_fundo() -> void:
	var base := ColorRect.new()
	base.color = Color(0.06, 0.03, 0.10)
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
	escuro.color = Color(0.03, 0.01, 0.06, 0.8)
	escuro.size = tela
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(escuro)


func _titulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	if fonte_titulo:
		l.add_theme_font_override("font", fonte_titulo)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(tela.x - 200, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _texto(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	if fonte_texto:
		l.add_theme_font_override("font", fonte_texto)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(tela.x - 200, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _espaco(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	lista.add_child(c)


func _centralizar(c: Control) -> void:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(tela.x, 0)
	cc.add_child(c)
	lista.add_child(cc)


## Uma pessoa: título "de fantasia" em dourado, nome grande, função de verdade embaixo.
func _pessoa(titulo_fantasia: String, nome: String, funcao: String) -> void:
	_centralizar(_texto(titulo_fantasia, 30, cor_titulo))
	_centralizar(_titulo(nome, 56, cor_texto))
	_centralizar(_texto(funcao, 28, cor_apagada))
	_espaco(50)


# ================================================================ CRÉDITOS (edite aqui)

func _montar_creditos() -> void:
	var nome := nome_do_jogo if nome_do_jogo != "" else String(ProjectSettings.get_setting("application/config/name", ""))
	if nome != "" and nome != "nome do jogo":
		_centralizar(_titulo(nome, 96, cor_titulo))
		_centralizar(_texto("um jogo de", 30, cor_apagada))
	_centralizar(_titulo("Amantes de Valorant, Minecraft e Overcooked 2 Productions", 44, cor_texto))
	_espaco(140)

	_centralizar(_titulo("A Guilda", 64, cor_titulo))
	_espaco(40)
	_pessoa("Arquimago do Código e Grão-Mestre das Regras", "Mateus Eduardo",
			"Lead de Programação · Lead de Game Design")
	_pessoa("Pintor de Dragões e Guardião das Cores", "Christian Ferreira",
			"Diretor de Arte")
	_pessoa("Bardo da Guilda, Encantador de Ouvidos", "Thiago Amaral",
			"Compositor Musical e Designer de Som")
	_pessoa("Alquimista de Ideias", "Matheus Soriano",
			"Co-designer")
	_pessoa("Sábio Conselheiro do Reino", "Daniel Sene",
			"Conselheiro")
	_espaco(90)

	_centralizar(_titulo("Agradecimentos", 52, cor_titulo))
	_espaco(10)
	_centralizar(_texto("A todos que tentaram só mais uma vez.", 32, cor_texto))
	_centralizar(_texto("Feito em um fim de semana para a Dev-U Gamejam+", 30, cor_apagada))
	_centralizar(_texto("Tema: \"One More Time\"  ·  Feito com Godot Engine", 30, cor_apagada))
	_espaco(260)

	_centralizar(_titulo("Obrigado por jogar!", 80, cor_titulo))
	_espaco(30)
	_centralizar(_texto("...e se perder, tente só mais uma vez.", 32, cor_texto))


func _process(delta: float) -> void:
	if saindo or lista == null:
		return
	var rapido := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_KP_ENTER)
	lista.position.y -= (velocidade_rapida if rapido else velocidade) * delta
	# o "Obrigado por jogar!" para no meio da tela; depois de um tempo volta ao menu
	var fim := tela.y / 2.0 - lista.size.y + 120.0
	if lista.position.y <= fim:
		lista.position.y = fim
		if not has_meta("terminou"):
			set_meta("terminou", true)
			get_tree().create_timer(3.0 if not voltar_ao_menu_no_fim else 4.0).timeout.connect(_voltar)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_voltar()


func _voltar() -> void:
	if saindo:
		return
	saindo = true
	var t := create_tween()
	t.tween_property(cortina, "color:a", 1.0, 0.8)
	if voltar_ao_menu_no_fim:
		t.tween_callback(func(): get_tree().change_scene_to_file(cena_menu))
	else:
		t.tween_callback(func(): terminou.emit())
