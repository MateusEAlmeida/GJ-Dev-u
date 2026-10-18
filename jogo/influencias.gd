extends Node2D
## Influências do cenário durante a luta contra os dragões.
## O jogo.gd cria este nó sozinho; cada dragão escolhe quais ficam ativas
## (campo "Influência no cenário" no Inspetor do dragão).
##   Fogo  -> parede de chamas na esquerda que de vez em quando avança
##   Água  -> chão escorregadio (demora para acelerar e frear)
##   Terra -> tremores: rachaduras no chão e, 1 s depois, espinhos de pedra
##   Ar    -> vento fraco para a esquerda + rajadas fortes com aviso

const FOGO := 0
const AGUA := 1
const TERRA := 2
const AR := 3
const NOMES := ["CHAMAS", "CHÃO MOLHADO", "TREMORES", "VENTANIA"]
const CORES := [Color(1.0, 0.55, 0.25), Color(0.45, 0.75, 1.0), Color(0.8, 0.62, 0.42), Color(0.85, 0.95, 1.0)]

var jogo: Node2D
var ativas: Array[int] = []
var forca := 1.0
var tela := Vector2(1920, 1080)
var _acabou_limpo := false

var lbl: Label

# ---------------------------------------------------------------- fogo
var fogo_raiz: Node2D
var fogo_brilho: ColorRect
var fogo_borda: ColorRect
var fogo_colunas: CPUParticles2D
var fogo_base: CPUParticles2D
var fogo_beira: CPUParticles2D
var fogo_miolo: ColorRect
var fogo_x := -90.0           # borda direita da parede de chamas
var fogo_estado := "fora"     # fora, repouso, aviso, avanco, segura, recua
var fogo_timer := 0.0
const FOGO_FORA := -90.0
const FOGO_REPOUSO := 120.0

# ---------------------------------------------------------------- água
var agua_brilho: ColorRect
var agua_reflexos: Array[ColorRect] = []
var agua_alfa := 0.0
var agua_gota_timer := 0.0

# ---------------------------------------------------------------- terra
var terra_timer := 3.0
var espinhos: Array = []
var tex_espinho: ImageTexture
var tex_racha: ImageTexture
const ESPINHO_AVISO := 1.0     # segundos entre a rachadura e o espinho sair
const ESPINHO_FICA := 0.9

# ---------------------------------------------------------------- ar
var vento_fraco: CPUParticles2D
var vento_forte: CPUParticles2D
var vento_estado := "calma"   # calma, aviso, rajada
var vento_timer := 4.0
var vento_atual := 0.0


func _ready() -> void:
	tela = get_viewport_rect().size
	_criar_fogo()
	_criar_agua()
	_criar_vento()
	tex_espinho = _desenhar_espinho()
	tex_racha = _desenhar_racha()
	var camada := CanvasLayer.new()
	camada.layer = 5
	add_child(camada)
	lbl = jogo._label("", 30, Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(tela.x, 40)
	lbl.position = Vector2(0, 112)
	lbl.modulate.a = 0.0
	camada.add_child(lbl)


## Liga as influências da lista (FOGO, AGUA, TERRA, AR) e desliga as outras.
func definir(lista: Array, nova_forca: float = 1.0) -> void:
	forca = maxf(nova_forca, 0.0)
	var novas: Array[int] = []
	for e in lista:
		if int(e) >= 0 and int(e) <= 3 and not novas.has(int(e)):
			novas.append(int(e))
	if novas == ativas:
		return
	var entrou := novas.filter(func(e): return not ativas.has(e))
	ativas = novas
	if ativas.has(FOGO) and fogo_estado == "fora":
		fogo_estado = "repouso"
		fogo_timer = randf_range(3.0, 4.0)
	if ativas.has(TERRA) and not entrou.is_empty() and entrou.has(TERRA):
		terra_timer = 2.0
	if ativas.has(AR) and entrou.has(AR):
		vento_estado = "calma"
		vento_timer = randf_range(3.0, 4.5)
	_atualizar_rotulo(not entrou.is_empty())


func limpar() -> void:
	definir([])


func _atualizar_rotulo(destacar: bool) -> void:
	if ativas.is_empty():
		create_tween().tween_property(lbl, "modulate:a", 0.0, 0.4)
		return
	var partes := PackedStringArray()
	for e in ativas:
		partes.append(NOMES[e])
	lbl.text = " + ".join(partes)
	lbl.add_theme_color_override("font_color", CORES[ativas[0]] if ativas.size() == 1 else Color(1, 0.55, 0.6))
	var t := create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.25)
	if destacar:
		lbl.pivot_offset = lbl.size / 2.0
		lbl.scale = Vector2.ONE * 1.35
		create_tween().tween_property(lbl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if jogo == null:
		return
	if jogo.acabou:
		if not _acabou_limpo:
			_acabou_limpo = true
			limpar()
		return
	var andou: float = jogo.velocidade * jogo.velocidade_bonus * delta
	_fogo(delta)
	_agua(delta, andou)
	_terra(delta, andou)
	_ar(delta)


## Retângulo do mago (um pouco menor que a colisão, para ser justo).
func _ret_player() -> Rect2:
	var p: Node2D = jogo.player
	var f := p.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if f and f.shape is RectangleShape2D:
		var tam: Vector2 = (f.shape as RectangleShape2D).size * f.global_scale.abs()
		return Rect2(f.global_position - tam / 2.0, tam).grow(-tam.x * 0.15)
	return Rect2(p.global_position - Vector2(25, 70), Vector2(50, 70))


func _dano(empurrao_x: float = 0.0, pulo: float = 0.0) -> void:
	var p: Node = jogo.player
	if empurrao_x != 0.0:
		p.set("empurrao", empurrao_x)
	if pulo != 0.0 and p is CharacterBody2D:
		var corpo := p as CharacterBody2D
		corpo.velocity.y = -pulo
	if jogo.invencivel <= 0.0:
		jogo.levar_dano()


# ================================================================ FOGO

func _criar_fogo() -> void:
	fogo_raiz = Node2D.new()
	fogo_raiz.z_index = 3
	add_child(fogo_raiz)
	fogo_brilho = ColorRect.new()
	fogo_brilho.color = Color(1.0, 0.38, 0.12, 0.25)
	fogo_brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fogo_raiz.add_child(fogo_brilho)
	fogo_miolo = ColorRect.new()                   # faixa mais forte perto da parede (degradê em degraus)
	fogo_miolo.color = Color(0.9, 0.2, 0.05, 0.28)
	fogo_miolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fogo_raiz.add_child(fogo_miolo)
	fogo_borda = ColorRect.new()
	fogo_borda.color = Color(1.0, 0.75, 0.3, 0.3)
	fogo_borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fogo_raiz.add_child(fogo_borda)
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	rampa.colors = PackedColorArray([Color(1, 0.95, 0.55), Color(1, 0.6, 0.18), Color(0.85, 0.2, 0.08, 0.8), Color(0.4, 0.05, 0.05, 0.0)])
	fogo_colunas = _particulas_fogo(rampa, 170, 1.1, Vector2(90, 220), 6.0, 10.0)
	fogo_base = _particulas_fogo(rampa, 150, 0.9, Vector2(300, 650), 10.0, 16.0)
	fogo_beira = _particulas_fogo(rampa, 70, 1.0, Vector2(180, 380), 9.0, 14.0)
	fogo_raiz.visible = false


func _particulas_fogo(rampa: Gradient, qtd: int, vida: float, vel: Vector2, t0: float, t1: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = qtd
	p.lifetime = vida
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.15, -1)
	p.spread = 12.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.scale_amount_min = t0
	p.scale_amount_max = t1
	p.color_ramp = rampa
	p.emitting = false
	fogo_raiz.add_child(p)
	return p


func _fogo(delta: float) -> void:
	var ligado := ativas.has(FOGO)
	var avanco_x := FOGO_REPOUSO + 230.0 * forca
	var alvo := FOGO_FORA
	if ligado:
		fogo_timer -= delta
		match fogo_estado:
			"fora", "repouso":
				fogo_estado = "repouso"
				alvo = FOGO_REPOUSO
				if fogo_timer <= 0.0:
					fogo_estado = "aviso"
					fogo_timer = 0.9
			"aviso":                         # chamas crescem e piscam: vai avançar!
				alvo = FOGO_REPOUSO + 18.0
				if fogo_timer <= 0.0:
					fogo_estado = "avanco"
			"avanco":
				alvo = avanco_x
				if fogo_x >= avanco_x - 1.0:
					fogo_estado = "segura"
					fogo_timer = 1.0
			"segura":
				alvo = avanco_x
				if fogo_timer <= 0.0:
					fogo_estado = "recua"
			"recua":
				alvo = FOGO_REPOUSO
				if fogo_x <= FOGO_REPOUSO + 1.0:
					fogo_estado = "repouso"
					fogo_timer = randf_range(3.5, 5.5) / maxf(forca, 0.5)
	else:
		fogo_estado = "fora"
	var rapidez := 700.0 if fogo_estado == "avanco" else 260.0
	fogo_x = move_toward(fogo_x, alvo, rapidez * delta)

	var visivel := fogo_x > FOGO_FORA + 1.0
	fogo_raiz.visible = visivel
	fogo_colunas.emitting = visivel
	fogo_base.emitting = visivel
	fogo_beira.emitting = visivel
	if not visivel:
		return
	var largura := maxf(fogo_x, 1.0)
	var chao: float = jogo.chao_y
	fogo_brilho.position = Vector2(0, 0)
	fogo_brilho.size = Vector2(largura, chao)
	fogo_miolo.position = Vector2(0, 0)
	fogo_miolo.size = Vector2(largura * 0.6, chao)
	fogo_borda.position = Vector2(largura - 26.0, 0)
	fogo_borda.size = Vector2(26, chao)
	var aviso := fogo_estado == "aviso"
	fogo_borda.color.a = (0.55 if int(Time.get_ticks_msec() / 90) % 2 == 0 else 0.25) if aviso else 0.3
	fogo_colunas.position = Vector2(largura / 2.0, chao / 2.0)
	fogo_colunas.emission_rect_extents = Vector2(largura / 2.0, chao / 2.0)
	fogo_base.position = Vector2(largura / 2.0, chao - 16.0)
	fogo_base.emission_rect_extents = Vector2(largura / 2.0, 16.0)
	fogo_beira.position = Vector2(largura - 14.0, chao * 0.55)
	fogo_beira.emission_rect_extents = Vector2(14.0, chao * 0.45)
	var vel := 1.7 if aviso or fogo_estado == "avanco" else 1.0
	fogo_colunas.speed_scale = vel
	fogo_base.speed_scale = vel
	fogo_beira.speed_scale = vel

	# encostou nas chamas: dano e empurrão para a direita
	if ligado and fogo_x > 40.0 and _ret_player().position.x < fogo_x - 12.0:
		_dano(950.0, 0.0)


# ================================================================ ÁGUA

func _criar_agua() -> void:
	agua_brilho = ColorRect.new()
	agua_brilho.color = Color(0.45, 0.75, 1.0, 0.0)
	agua_brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agua_brilho.z_index = 1
	add_child(agua_brilho)
	for i in 16:
		var r := ColorRect.new()
		r.color = Color(0.85, 0.95, 1.0, 0.0)
		r.size = Vector2(randi_range(3, 6) * 5, 5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.z_index = 1
		r.set_meta("x", randf_range(0, tela.x))
		add_child(r)
		agua_reflexos.append(r)


func _agua(delta: float, andou: float) -> void:
	var ligado := ativas.has(AGUA)
	var p: Node = jogo.player
	p.set("escorregadio", clampf(0.95 * forca, 0.0, 0.98) if ligado else 0.0)
	agua_alfa = move_toward(agua_alfa, 1.0 if ligado else 0.0, delta * 1.5)
	var chao: float = jogo.chao_y
	agua_brilho.visible = agua_alfa > 0.0
	for r in agua_reflexos:
		r.visible = agua_alfa > 0.0
	if agua_alfa <= 0.0:
		return
	agua_brilho.position = Vector2(0, chao - 5)
	agua_brilho.size = Vector2(tela.x, 10)
	agua_brilho.color.a = 0.45 * agua_alfa
	for r in agua_reflexos:                      # reflexos andam com o chão
		var x: float = r.get_meta("x") - andou
		if x < -40:
			x += tela.x + 80
		r.set_meta("x", x)
		r.position = Vector2(floorf(x / 5.0) * 5.0, chao - 5)
		r.color.a = 0.55 * agua_alfa * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004 + x * 0.05))
	# gotas saindo dos pés quando ele anda/derrapa
	agua_gota_timer -= delta
	var vx: float = (p as CharacterBody2D).velocity.x if p is CharacterBody2D else 0.0
	if ligado and agua_gota_timer <= 0.0 and absf(vx) > 90.0 and p.is_on_floor():
		agua_gota_timer = 0.07
		var pe := Vector2((p as Node2D).global_position.x, chao - 4)
		jogo._soltar_particula(pe, Color(0.6, 0.85, 1.0, 0.95), 5, 170.0, Vector2(-signf(vx) * 0.6, -1.0).normalized(),
				30.0, 700.0, 0.4, 3.0, 5.0, 1.0, 6)


# ================================================================ TERRA

func _terra(delta: float, andou: float) -> void:
	if ativas.has(TERRA):
		terra_timer -= delta
		if terra_timer <= 0.0:
			terra_timer = randf_range(4.5, 6.5) / maxf(forca, 0.5)
			_tremor()
	var ret := _ret_player()
	espinhos = espinhos.filter(func(x): return is_instance_valid(x))
	for item in espinhos:
		var e: Node2D = item
		e.position.x -= andou                        # anda junto com o chão
		var t: float = e.get_meta("t") + delta
		e.set_meta("t", t)
		var pico: Node2D = e.get_node("Pico")
		var racha: Node2D = e.get_node("Racha")
		if t < ESPINHO_AVISO:                        # rachadura tremendo + pedrinhas pulando
			racha.position.x = (2.0 if int(t * 30) % 2 == 0 else -2.0)
			racha.modulate.a = 0.6 + 0.4 * (t / ESPINHO_AVISO)
			if int(t * 10) != int((t - delta) * 10):
				jogo._soltar_particula(e.position + Vector2(randf_range(-20, 20), -6), Color(0.55, 0.42, 0.3), 3, 160.0,
						Vector2(0, -1), 30.0, 900.0, 0.35, 4.0, 5.0, 1.0, 7)
		elif not e.get_meta("saiu"):
			e.set_meta("saiu", true)
			racha.position.x = 0.0
			var tw: Tween = e.create_tween()
			tw.tween_property(pico, "scale:y", 1.15, 0.07).set_ease(Tween.EASE_OUT)
			tw.tween_property(pico, "scale:y", 1.0, 0.08)
			jogo.explosao(e.position + Vector2(0, -10), Color(0.6, 0.46, 0.32), 14, 300.0)
		elif t > ESPINHO_AVISO + ESPINHO_FICA and not e.get_meta("descendo"):
			e.set_meta("descendo", true)
			var tw: Tween = e.create_tween()
			tw.tween_property(pico, "scale:y", 0.0, 0.25).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(racha, "modulate:a", 0.0, 0.4)
			tw.tween_callback(e.queue_free)
		# dano: só com o espinho bem para fora
		if e.get_meta("saiu") and pico.scale.y > 0.45:
			var alt: float = e.get_meta("altura") * pico.scale.y
			var larg: float = e.get_meta("largura") * 0.6
			var r := Rect2(e.position.x - larg / 2.0, e.position.y - alt, larg, alt)
			if r.intersects(ret):
				_dano(0.0, 520.0)


func _tremor() -> void:
	jogo._tremer_tela()
	var vel: float = jogo.velocidade * jogo.velocidade_bonus
	var xs: Array[float] = []
	# um espinho nasce exatamente onde o mago vai estar quando ele sair (se ficar parado)
	xs.append(minf(jogo.player.global_position.x + vel * ESPINHO_AVISO, tela.x - 60.0))
	var extra := 1 + (1 if randf() < 0.35 * forca else 0)
	var tentativas := 0
	while xs.size() < 1 + extra and tentativas < 30:
		tentativas += 1
		var x := randf_range(260.0, tela.x + vel * ESPINHO_AVISO * 0.5)
		var longe := true
		for o in xs:
			if absf(o - x) < 240.0:
				longe = false
		if longe:
			xs.append(minf(x, tela.x + 200.0))
	for x in xs:
		_criar_espinho(x)


func _criar_espinho(x: float) -> void:
	var escala := 5.0
	var e := Node2D.new()
	e.position = Vector2(x, jogo.chao_y)
	e.z_index = 2
	var racha := Sprite2D.new()
	racha.name = "Racha"
	racha.texture = tex_racha
	racha.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	racha.scale = Vector2.ONE * escala
	racha.position = Vector2.ZERO
	racha.offset = Vector2(0, -tex_racha.get_height() / 2.0 + 1)
	e.add_child(racha)
	var pico := Node2D.new()
	pico.name = "Pico"
	pico.scale = Vector2(1, 0)
	e.add_child(pico)
	var s := Sprite2D.new()
	s.texture = tex_espinho
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.scale = Vector2.ONE * escala
	s.position = Vector2(-tex_espinho.get_width() * escala / 2.0, -tex_espinho.get_height() * escala)
	pico.add_child(s)
	e.set_meta("t", 0.0)
	e.set_meta("saiu", false)
	e.set_meta("descendo", false)
	e.set_meta("altura", tex_espinho.get_height() * escala)
	e.set_meta("largura", tex_espinho.get_width() * escala)
	add_child(e)
	espinhos.append(e)


func _desenhar_espinho() -> ImageTexture:
	var w := 13
	var h := 22
	var cont := Color8(40, 30, 26)
	var esc := Color8(92, 70, 52)
	var med := Color8(128, 98, 70)
	var cla := Color8(168, 132, 94)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var meia := 0.5 + 6.0 * pow(float(y) / (h - 1), 0.85)    # fino em cima, largo embaixo
		for x in w:
			var dx := float(x) - (w - 1) / 2.0
			if absf(dx) <= meia:
				var c := med
				if dx < -meia * 0.25:
					c = cla
				elif dx > meia * 0.35:
					c = esc
				if absf(dx) > meia - 1.0 or y == 0:
					c = cont
				img.set_pixel(x, y, c)
	# rachadurinhas
	for p in [Vector2i(5, 12), Vector2i(6, 13), Vector2i(7, 16), Vector2i(4, 18)]:
		img.set_pixelv(p, esc)
	return ImageTexture.create_from_image(img)


func _desenhar_racha() -> ImageTexture:
	var desenho := ["...X....X.....", "XXXXX.XXXXX.XX", "..X..XX...XX..", ".X.......X...."]
	var img := Image.create(desenho[0].length(), desenho.size(), false, Image.FORMAT_RGBA8)
	for y in desenho.size():
		for x in desenho[y].length():
			if desenho[y][x] == "X":
				img.set_pixel(x, y, Color8(30, 20, 16))
	return ImageTexture.create_from_image(img)


# ================================================================ AR

func _criar_vento() -> void:
	vento_fraco = _particulas_vento(22, Vector2(900, 1200), Color(1, 1, 1, 0.3), 8)
	vento_forte = _particulas_vento(90, Vector2(1600, 2200), Color(0.9, 0.97, 1, 0.6), 16)


func _particulas_vento(qtd: int, vel: Vector2, c: Color, comprimento: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = qtd
	p.lifetime = 2.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = Vector2(tela.x + 60, 0)
	p.emission_rect_extents = Vector2(10, 10)
	p.direction = Vector2(-1, 0.03)
	p.spread = 3.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.scale_amount_min = 3.0
	p.scale_amount_max = 3.0
	p.color = c
	var img := Image.create(comprimento, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.z_index = 5
	p.emitting = false
	add_child(p)
	return p


func _ar(delta: float) -> void:
	var ligado := ativas.has(AR)
	var alvo := 0.0
	if ligado:
		vento_timer -= delta
		match vento_estado:
			"calma":
				alvo = -85.0 * forca
				if vento_timer <= 0.0:
					vento_estado = "aviso"
					vento_timer = 1.0
					jogo._mostrar_aviso("RAJADA DE VENTO!", CORES[AR])
			"aviso":
				alvo = -85.0 * forca
				if vento_timer <= 0.0:
					vento_estado = "rajada"
					vento_timer = 2.2
			"rajada":
				alvo = -360.0 * forca
				if vento_timer <= 0.0:
					vento_estado = "calma"
					vento_timer = randf_range(4.0, 6.5) / maxf(forca, 0.5)
	vento_atual = move_toward(vento_atual, alvo, 900.0 * delta)
	jogo.player.set("vento", vento_atual)
	var chao: float = jogo.chao_y
	vento_fraco.position = Vector2(tela.x + 60, chao / 2.0)
	vento_fraco.emission_rect_extents = Vector2(10, chao / 2.0)
	vento_forte.position = vento_fraco.position
	vento_forte.emission_rect_extents = vento_fraco.emission_rect_extents
	vento_fraco.emitting = ligado
	vento_forte.emitting = ligado and vento_estado != "calma"
