extends Node2D


signal marco_de_pontos(numero: int)   ## a cada 5000 pontos (para trocar o cenário depois)

@export_group("Cenas")
@export_file("*.tscn") var cena_menu: String = "res://Menu/Menu.tscn"

@export_group("Arte (opcional)")
@export var texturas_obstaculos: Array[Texture2D] = []   ## vazio = obstáculos provisórios
@export var escala_pixel_art: float = 5.0                ## mesma escala do mago
@export var textura_coracao: Texture2D                   ## vazio = coração provisório (talvez mudar pra barra de vida)
@export var fonte_hud: Font

@export_group("Dificuldade")
@export var velocidade_inicial: float = 480.0
@export var velocidade_maxima: float = 1150.0
@export var aceleracao: float = 9.0          ## quanto a velocidade sobe por segundo
@export var vidas_maximas: int = 3
@export var tempo_invencivel: float = 1.2   ##tempo de invencibilidade
@export var acertos_por_multiplicador: int = 5
@export var multiplicador_maximo: int = 5
@export var pontos_por_marco: int = 5000

@export_group("Limites do jogador")
@export var x_minimo: float = 80.0
@export var x_maximo: float = 1100.0

const ARQUIVO_RECORDE := "user://recorde.cfg"
const COR_TEXTO := Color(0.96, 0.93, 0.86)
const COR_APAGADA := Color(0.62, 0.58, 0.76)
const COR_DESTAQUE := Color(1.0, 0.82, 0.35)

@onready var player: CharacterBody2D = $player

var velocidade := 0.0
var pontos := 0.0
var recorde := 0
var recorde_no_inicio := 0
var bateu_recorde := false
var combo := 0
var multiplicador := 1
var vidas := 3
var invencivel := 0.0
var distancia_ate_proximo := 600.0
var marco_atual := 0
var acabou := false
var pode_reiniciar := false
var chao_y := 1000.0
var largura_tela := 1920.0

var obstaculos: Node2D
var pedrinhas: Array[ColorRect] = []

var hud: CanvasLayer
var lbl_pontos: Label
var lbl_recorde: Label
var lbl_combo: Label
var lbl_aviso: Label
var caixa_vidas: HBoxContainer
var painel_fim: Control
var lbl_fim_pontos: Label
var lbl_fim_recorde: Label
var painel_pausa: Control


func _ready() -> void:
	randomize()
	# O Jogo continua recebendo teclas mesmo pausado; o player e os obstáculos pausam.
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	largura_tela = get_viewport_rect().size.x

	vidas = vidas_maximas
	velocidade = velocidade_inicial
	_carregar_recorde()
	recorde_no_inicio = recorde
	chao_y = _detectar_chao()

	obstaculos = Node2D.new()
	obstaculos.name = "Obstaculos"
	obstaculos.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(obstaculos)

	_criar_pedrinhas()
	_criar_hud()
	distancia_ate_proximo = largura_tela * 0.6
	_mostrar_aviso("CORRA!", COR_TEXTO)


func _physics_process(delta: float) -> void:
	if get_tree().paused or acabou:
		return

	velocidade = minf(velocidade_maxima, velocidade + aceleracao * delta)
	var andou := velocidade * delta

	# Pontos (o multiplicador do combo entra aqui)
	pontos += andou * 0.1 * multiplicador
	_checar_marcos()

	# Novos obstáculos: espaçados pela distância do pulo, para sempre dar para passar
	distancia_ate_proximo -= andou
	if distancia_ate_proximo <= 0.0:
		var largura := _criar_obstaculo()
		distancia_ate_proximo = largura + _distancia_do_pulo() * _fator_espaco()

	# Move os obstáculos e conta os que o mago já passou
	for o in obstaculos.get_children():
		o.position.x -= andou
		if not o.get_meta("passou") and o.position.x + o.get_meta("largura") < player.global_position.x:
			o.set_meta("passou", true)
			_somar_combo()
		if o.position.x < -400:
			o.queue_free()

	# Pedrinhas do chão dão a sensação de velocidade
	for p in pedrinhas:
		p.position.x -= andou * p.get_meta("parallax")
		if p.position.x < -20:
			p.position.x += largura_tela + 40

	# Mantém o mago dentro da área jogável
	player.global_position.x = clampf(player.global_position.x, x_minimo, x_maximo)
	if player.global_position.y > chao_y + 600:
		_fim_de_jogo()

	# Animação acompanha a velocidade do mundo
	player.get_node("AnimatedSprite2D").speed_scale = clampf(velocidade / velocidade_inicial, 1.0, 1.8)

	# Piscando enquanto invencível
	if invencivel > 0.0:
		invencivel -= delta
		player.modulate.a = 0.3 if int(invencivel * 14.0) % 2 == 0 else 1.0
	else:
		player.modulate.a = 1.0

	_atualizar_hud()


# ================================================================ obstáculos

func _distancia_do_pulo() -> float:
	# Quanto o mago anda no ar durante um pulo completo, na velocidade atual.
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity") * float(player.get("gravidade_extra"))
	var tempo_no_ar: float = 2.0 * float(player.get("forca_pulo")) / g
	return tempo_no_ar * velocidade


func _fator_espaco() -> float:
	# No começo os obstáculos vêm mais espaçados; com a velocidade, mais juntos.
	var progresso := (velocidade - velocidade_inicial) / maxf(velocidade_maxima - velocidade_inicial, 1.0)
	return randf_range(lerpf(1.25, 1.05, progresso), lerpf(2.6, 1.7, progresso))


func _criar_obstaculo() -> float:
	var area := Area2D.new()
	var tamanho: Vector2
	if not texturas_obstaculos.is_empty():
		var tex: Texture2D = texturas_obstaculos.pick_random()
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * escala_pixel_art
		tamanho = tex.get_size() * escala_pixel_art
		s.position = Vector2(0, -tamanho.y)
		area.add_child(s)
	else:
		tamanho = Vector2(randi_range(9, 22), randi_range(9, 24)) * escala_pixel_art
		area.add_child(_pedra_provisoria(tamanho))

	# Caixa de colisão um pouco menor que o desenho: parece justo para o jogador.
	var forma := CollisionShape2D.new()
	var ret := RectangleShape2D.new()
	ret.size = tamanho * Vector2(0.78, 0.85)
	forma.shape = ret
	forma.position = Vector2(tamanho.x / 2.0, -tamanho.y * 0.85 / 2.0)
	area.add_child(forma)

	area.position = Vector2(largura_tela + 40, chao_y)
	area.set_meta("largura", tamanho.x)
	area.set_meta("passou", false)
	area.body_entered.connect(_ao_tocar_obstaculo.bind(area))
	obstaculos.add_child(area)
	return tamanho.x


func _pedra_provisoria(t: Vector2) -> Node2D:
	# Cristal/pedra simples até o Christian desenhar os obstáculos de verdade.
	var n := Node2D.new()
	var e := escala_pixel_art
	var corpo := Polygon2D.new()
	corpo.color = Color(0.28, 0.20, 0.38)
	corpo.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(0, -t.y * 0.55), Vector2(t.x * 0.25, -t.y),
		Vector2(t.x * 0.7, -t.y * 0.92), Vector2(t.x, -t.y * 0.5), Vector2(t.x, 0)])
	n.add_child(corpo)
	var brilho := Polygon2D.new()
	brilho.color = Color(0.55, 0.42, 0.75)
	brilho.polygon = PackedVector2Array([
		Vector2(t.x * 0.25, -t.y + e), Vector2(t.x * 0.62, -t.y * 0.92 + e),
		Vector2(t.x * 0.45, -t.y * 0.6), Vector2(t.x * 0.2, -t.y * 0.62)])
	n.add_child(brilho)
	return n


func _ao_tocar_obstaculo(corpo: Node2D, obstaculo: Area2D) -> void:
	if corpo != player or acabou:
		return
	obstaculo.set_meta("passou", true)     # obstáculo que acertou não conta no combo
	if invencivel > 0.0:
		return
	levar_dano()


# ================================================================ vida, combo e pontos

func levar_dano() -> void:
	vidas -= 1
	combo = 0
	multiplicador = 1
	invencivel = tempo_invencivel
	_tremer_tela()
	_atualizar_vidas()
	if vidas <= 0:
		_fim_de_jogo()


func _somar_combo() -> void:
	combo += 1
	var novo := mini(multiplicador_maximo, 1 + combo / acertos_por_multiplicador)
	if novo != multiplicador:
		multiplicador = novo
		_pulsar(lbl_combo)
		_mostrar_aviso("COMBO x%d!" % multiplicador, COR_DESTAQUE)


func _checar_marcos() -> void:
	var marco := int(pontos) / pontos_por_marco
	if marco > marco_atual:
		marco_atual = marco
		marco_de_pontos.emit(marco)
		_mostrar_aviso("%d PONTOS!" % (marco * pontos_por_marco), COR_TEXTO)
	if not bateu_recorde and recorde_no_inicio > 0 and int(pontos) > recorde_no_inicio:
		bateu_recorde = true
		_mostrar_aviso("NOVO RECORDE!", COR_DESTAQUE)


# ================================================================ fim de jogo, pausa, recorde

func _fim_de_jogo() -> void:
	if acabou:
		return
	acabou = true
	player.morrer()
	var final := int(pontos)
	var novo_recorde := final > recorde
	if novo_recorde:
		recorde = final
		_salvar_recorde()

	lbl_fim_pontos.text = "%d pontos" % final
	if novo_recorde and recorde_no_inicio > 0:
		lbl_fim_recorde.text = "NOVO RECORDE!"
		lbl_fim_recorde.add_theme_color_override("font_color", COR_DESTAQUE)
	elif novo_recorde:
		lbl_fim_recorde.text = "Primeiro recorde marcado!"
	else:
		lbl_fim_recorde.text = "Faltaram %d pontos para o seu recorde (%d)" % [recorde - final, recorde]

	await get_tree().create_timer(0.45).timeout
	painel_fim.visible = true
	painel_fim.modulate.a = 0.0
	create_tween().tween_property(painel_fim, "modulate:a", 1.0, 0.25)
	pode_reiniciar = true


func _unhandled_input(event: InputEvent) -> void:
	if acabou:
		if not pode_reiniciar:
			return
		var apertou_r: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_up") or apertou_r:
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()          # recomeça na hora
		elif event.is_action_pressed("ui_cancel"):
			_ir_para_menu()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_pausar(not get_tree().paused)
	elif get_tree().paused and event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_ir_para_menu()


func _pausar(pausar: bool) -> void:
	get_tree().paused = pausar
	painel_pausa.visible = pausar


func _ir_para_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(cena_menu)


func _carregar_recorde() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO_RECORDE) == OK:
		recorde = int(cfg.get_value("jogo", "recorde", 0))


func _salvar_recorde() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("jogo", "recorde", recorde)
	cfg.save(ARQUIVO_RECORDE)


# ================================================================ cenário

func _detectar_chao() -> float:
	# Usa o topo da colisão do StaticBody2D como linha do chão.
	for filho in get_children():
		if filho is StaticBody2D:
			for f in filho.get_children():
				if f is CollisionShape2D and f.shape is RectangleShape2D:
					return f.global_position.y - f.shape.size.y / 2.0 * absf(f.global_scale.y)
	push_warning("Não achei o chão (StaticBody2D com CollisionShape2D retangular). Usando y = 1000.")
	return 1000.0


func _criar_pedrinhas() -> void:
	var cores := [Color(0.22, 0.17, 0.30), Color(0.30, 0.24, 0.40), Color(0.18, 0.13, 0.24)]
	for i in 40:
		var p := ColorRect.new()
		var lado := escala_pixel_art * randi_range(1, 2)
		p.size = Vector2(lado, escala_pixel_art)
		p.color = cores.pick_random()
		p.position = Vector2(randf_range(0, largura_tela), chao_y + randf_range(8, 60))
		p.set_meta("parallax", 1.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		pedrinhas.append(p)


func _tremer_tela() -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(self, "position", Vector2(randf_range(-10, 10), randf_range(-6, 6)), 0.03)
	t.tween_property(self, "position", Vector2.ZERO, 0.04)


# ================================================================ HUD

func _label(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	if fonte_hud:
		l.add_theme_font_override("font", fonte_hud)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _criar_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var w := largura_tela

	caixa_vidas = HBoxContainer.new()
	caixa_vidas.position = Vector2(40, 32)
	caixa_vidas.add_theme_constant_override("separation", 10)
	hud.add_child(caixa_vidas)
	_atualizar_vidas()

	lbl_pontos = _label("0", 56, COR_TEXTO)
	lbl_pontos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_pontos.position = Vector2(w - 540, 20)
	lbl_pontos.size = Vector2(500, 70)
	hud.add_child(lbl_pontos)

	lbl_recorde = _label("REC %d" % recorde, 26, COR_APAGADA)
	lbl_recorde.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_recorde.position = Vector2(w - 540, 92)
	lbl_recorde.size = Vector2(500, 36)
	hud.add_child(lbl_recorde)

	lbl_combo = _label("", 34, COR_DESTAQUE)
	lbl_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_combo.position = Vector2(w - 540, 132)
	lbl_combo.size = Vector2(500, 44)
	hud.add_child(lbl_combo)

	lbl_aviso = _label("", 64, COR_TEXTO)
	lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_aviso.position = Vector2(0, 260)
	lbl_aviso.size = Vector2(w, 90)
	lbl_aviso.modulate.a = 0.0
	hud.add_child(lbl_aviso)

	# Tela de fim de jogo
	painel_fim = _painel_escuro()
	var caixa := _caixa_central(painel_fim)
	caixa.add_child(_centralizado(_label("FIM DE JOGO", 96, COR_TEXTO)))
	lbl_fim_pontos = _centralizado(_label("", 56, COR_TEXTO))
	caixa.add_child(lbl_fim_pontos)
	lbl_fim_recorde = _centralizado(_label("", 34, COR_APAGADA))
	caixa.add_child(lbl_fim_recorde)
	caixa.add_child(_centralizado(_label("Espaço: tentar de novo     ·     Esc: menu", 28, COR_APAGADA)))

	# Tela de pausa
	painel_pausa = _painel_escuro()
	var caixa_p := _caixa_central(painel_pausa)
	caixa_p.add_child(_centralizado(_label("PAUSADO", 96, COR_TEXTO)))
	caixa_p.add_child(_centralizado(_label("Esc: continuar     ·     M: menu", 28, COR_APAGADA)))


func _painel_escuro() -> Control:
	var p := ColorRect.new()
	p.color = Color(0.03, 0.02, 0.07, 0.72)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	hud.add_child(p)
	return p


func _caixa_central(pai: Control) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", 22)
	pai.add_child(c)
	return c


func _centralizado(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _atualizar_hud() -> void:
	lbl_pontos.text = "%06d" % int(pontos)
	lbl_recorde.text = "REC %06d" % maxi(recorde, int(pontos))
	lbl_combo.text = ("COMBO %d   x%d" % [combo, multiplicador]) if combo > 0 else ""


func _atualizar_vidas() -> void:
	if caixa_vidas == null:
		return
	var tex: Texture2D = textura_coracao if textura_coracao else _coracao_provisorio()
	for c in caixa_vidas.get_children():
		c.queue_free()
	for i in vidas_maximas:
		var r := TextureRect.new()
		r.texture = tex
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.custom_minimum_size = Vector2(56, 48)
		r.modulate = Color.WHITE if i < vidas else Color(0.25, 0.2, 0.3, 0.6)
		caixa_vidas.add_child(r)


var _cache_coracao: ImageTexture
func _coracao_provisorio() -> ImageTexture:
	if _cache_coracao:
		return _cache_coracao
	var desenho := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
	var img := Image.create(7, 6, false, Image.FORMAT_RGBA8)
	for y in desenho.size():
		for x in 7:
			if desenho[y][x] == "X":
				img.set_pixel(x, y, Color(0.86, 0.22, 0.32) if y > 0 or x % 3 != 1 else Color(1, 0.6, 0.65))
	_cache_coracao = ImageTexture.create_from_image(img)
	return _cache_coracao


func _mostrar_aviso(texto: String, cor: Color) -> void:
	lbl_aviso.text = texto
	lbl_aviso.add_theme_color_override("font_color", cor)
	lbl_aviso.pivot_offset = lbl_aviso.size / 2.0
	lbl_aviso.scale = Vector2.ONE * 1.3
	var t := create_tween().set_parallel(true)
	t.tween_property(lbl_aviso, "modulate:a", 1.0, 0.12)
	t.tween_property(lbl_aviso, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.9)
	t.chain().tween_property(lbl_aviso, "modulate:a", 0.0, 0.35)


func _pulsar(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE * 1.25, 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
