extends Node
## Sistema de cartas: tela de escolha (3 cartas que viram), fileira de cartas no HUD e os efeitos.
## O jogo.gd cria este nó sozinho. As cartas são os arquivos .tres da pasta "dados".
## Os efeitos são lidos pelo jogo/dragão/mago com: valor("id") e quantas("id").

signal carta_escolhida(carta: Resource)

const ESCALA := 4.0                                       # pixel art das cartas
const PESO_RARIDADE := [60.0, 30.0, 10.0]                 # chance de Comum / Rara / Lendária
const CORES_RARIDADE := [Color(0.35, 0.6, 1.0), Color(0.72, 0.45, 1.0), Color(1.0, 0.82, 0.3)]
const NOMES_RARIDADE := ["Comum", "Rara", "Lendária"]
const COR_TEXTO := Color(0.28, 0.15, 0.06)

var jogo: Node2D
var todas: Array[Resource] = []
var minhas := {}                 # id -> quantidade
var escolhendo := false

# estado de alguns efeitos
var cargas_quebra := 0
var escudo_pronto := false
var escudo_espera := 0.0
var fenix_usada := false

var _base := ""
var _tex := {}
var camada_hud: CanvasLayer
var fileira: HFlowContainer
var _slots := {}                 # id -> Control
var _bolha_escudo: Sprite2D

# tela de escolha
var camada_escolha: CanvasLayer
var _fundo: ColorRect
var _titulo: Label
var _dica: Label
var _cartas_ui: Array[Control] = []
var _ofertas: Array[Resource] = []
var _sel := 0
var _pode_escolher := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base = (get_script() as Script).resource_path.get_base_dir()
	for n in ["carta_comum", "carta_rara", "carta_lendaria", "carta_verso", "mini_comum", "mini_rara", "mini_lendaria"]:
		var p := _base.path_join("arte/" + n + ".png")
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	_carregar_cartas()
	_criar_hud()


func _carregar_cartas() -> void:
	var pasta := _base.path_join("dados")
	var nomes: PackedStringArray = ResourceLoader.list_directory(pasta)
	nomes.sort()
	for n in nomes:
		if n.ends_with(".tres") or n.ends_with(".res"):
			var c := load(pasta.path_join(n))
			if c and c.get("id") != null and c.get("ativa"):
				todas.append(c)


# ================================================================ consultas usadas pelo jogo

func quantas(id: String) -> int:
	return int(minhas.get(id, 0))


func valor(id: String) -> float:
	for c in todas:
		if c.id == id:
			return float(c.valor) * quantas(id)
	return 0.0


func mult_magia(elemento: int) -> float:
	var ids := ["chama_viva", "mare_alta", "punho_de_pedra", "olho_do_tufao"]
	var m := 1.0
	if elemento >= 0 and elemento < 4:
		m += valor(ids[elemento])
	if quantas("canhao_vidro") > 0:
		m *= 2.0
	return m


## Escudo: se estiver pronto, gasta e evita o dano.
func absorver_dano() -> bool:
	escudo_espera = 0.0
	if quantas("escudo") > 0 and escudo_pronto:
		escudo_pronto = false
		jogo.explosao(jogo.player.global_position + Vector2(0, -40), Color(0.5, 0.8, 1.0), 22, 340.0)
		jogo._mostrar_aviso("ESCUDO!", Color(0.6, 0.85, 1.0))
		jogo.invencivel = 0.8
		_atualizar_slot("escudo")
		return true
	return false


## Quebra-Pedras: encostou numa pedra com carga -> ela explode e não tira vida.
func usar_quebra(obstaculo: Node2D) -> bool:
	if cargas_quebra <= 0:
		return false
	cargas_quebra -= 1
	jogo.explosao(obstaculo.global_position + Vector2(40, -40), Color(0.7, 0.7, 0.75), 20, 360.0)
	jogo.pausa_impacto(0.04)
	obstaculo.queue_free()
	_atualizar_slot("quebra_pedras")
	return true


## Só Mais Uma Vez: na hora de morrer, volta com 2 corações (uma vez por partida).
func tentar_reviver() -> bool:
	if quantas("so_mais_uma_vez") <= 0 or fenix_usada:
		return false
	fenix_usada = true
	jogo.vidas = mini(int(valor("so_mais_uma_vez")), jogo.vidas_maximas)
	jogo.invencivel = 2.5
	jogo._atualizar_vidas()
	jogo._mostrar_aviso("SÓ MAIS UMA VEZ!", CORES_RARIDADE[2])
	for i in 3:
		jogo.explosao(jogo.player.global_position + Vector2(randf_range(-40, 40), -40 - i * 30), Color(1, 0.6, 0.2), 22, 380.0)
	jogo.flash_mago(Color(1, 0.8, 0.3), 1.0, 0.8)
	_atualizar_slot("so_mais_uma_vez")
	return true


func ao_derrotar_dragao() -> void:
	cargas_quebra = int(valor("quebra_pedras"))
	_atualizar_slot("quebra_pedras")


func _process(delta: float) -> void:
	if jogo == null or escolhendo or get_tree().paused:
		return
	# escudo recarrega depois de um tempo sem levar dano
	if quantas("escudo") > 0 and not escudo_pronto:
		escudo_espera += delta
		if escudo_espera >= valor("escudo") / maxf(quantas("escudo"), 1):
			escudo_pronto = true
			_atualizar_slot("escudo")
	if _bolha_escudo:
		_bolha_escudo.visible = escudo_pronto and quantas("escudo") > 0 and not jogo.acabou
		if _bolha_escudo.visible:
			_bolha_escudo.global_position = jogo.player.global_position + Vector2(0, -42)
			_bolha_escudo.modulate.a = 0.45 + 0.2 * sin(Time.get_ticks_msec() * 0.006)


# ================================================================ aplicar uma carta

func adicionar(c: Resource) -> void:
	minhas[c.id] = quantas(c.id) + 1
	var p: Node = jogo.player
	match String(c.id):
		"coracao_extra":
			jogo.vidas_maximas += int(c.valor)
			jogo.vidas = mini(jogo.vidas + int(c.valor), jogo.vidas_maximas)
			jogo._atualizar_vidas()
		"pocao":
			jogo.vidas = jogo.vidas_maximas
			jogo._atualizar_vidas()
		"canhao_vidro":
			jogo.vidas_maximas = int(c.valor)
			jogo.vidas = mini(jogo.vidas, jogo.vidas_maximas)
			jogo._atualizar_vidas()
		"quebra_pedras":
			cargas_quebra += int(c.valor)
		"escudo":
			escudo_pronto = true
			_criar_bolha()
		"pulo_duplo":
			p.set("pulos_extras", 1)
	if c.id != "pocao":                 # a poção é usada na hora, não fica na fileira
		_adicionar_slot(c)
	carta_escolhida.emit(c)


# ================================================================ fileira de cartas no HUD

func _criar_hud() -> void:
	camada_hud = CanvasLayer.new()
	camada_hud.layer = 4
	add_child(camada_hud)
	fileira = HFlowContainer.new()
	fileira.position = Vector2(40, 136)
	fileira.size = Vector2(700, 140)
	fileira.add_theme_constant_override("h_separation", 8)
	fileira.add_theme_constant_override("v_separation", 8)
	fileira.mouse_filter = Control.MOUSE_FILTER_PASS
	camada_hud.add_child(fileira)


func _adicionar_slot(c: Resource) -> void:
	if _slots.has(c.id):
		_atualizar_slot(c.id)
		_pulsar(_slots[c.id])
		return
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(60, 60)
	slot.tooltip_text = c.nome + "\n" + c.descricao
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var moldura := TextureRect.new()
	moldura.texture = _tex.get(["mini_comum", "mini_rara", "mini_lendaria"][c.raridade])
	moldura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moldura.stretch_mode = TextureRect.STRETCH_SCALE
	moldura.size = Vector2(60, 60)
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(moldura)
	var ic := TextureRect.new()
	ic.name = "Icone"
	ic.texture = c.icone
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.stretch_mode = TextureRect.STRETCH_SCALE
	ic.position = Vector2(6, 6)
	ic.size = Vector2(48, 48)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(ic)
	var n := jogo._label("", 22, Color.WHITE) as Label
	n.name = "Numero"
	n.position = Vector2(30, 34)
	n.size = Vector2(34, 30)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slot.add_child(n)
	fileira.add_child(slot)
	_slots[c.id] = slot
	_atualizar_slot(c.id)
	slot.pivot_offset = Vector2(30, 30)
	slot.scale = Vector2.ZERO
	create_tween().tween_property(slot, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _atualizar_slot(id: String) -> void:
	if not _slots.has(id):
		return
	var slot: Control = _slots[id]
	var n: Label = slot.get_node("Numero")
	var ic: TextureRect = slot.get_node("Icone")
	ic.modulate = Color.WHITE
	n.text = ("x%d" % quantas(id)) if quantas(id) > 1 else ""
	match id:
		"quebra_pedras":
			n.text = str(cargas_quebra)
			ic.modulate = Color.WHITE if cargas_quebra > 0 else Color(0.4, 0.4, 0.45)
		"escudo":
			ic.modulate = Color.WHITE if escudo_pronto else Color(0.4, 0.4, 0.45)
		"so_mais_uma_vez":
			ic.modulate = Color(0.35, 0.3, 0.3) if fenix_usada else Color.WHITE


func posicao_slot(id: String) -> Vector2:
	if _slots.has(id):
		return (_slots[id] as Control).global_position + Vector2(30, 30)
	var n := fileira.get_child_count()
	return fileira.global_position + Vector2(30 + n * 68, 30)


func _pulsar(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE * 1.3, 0.1)
	t.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _criar_bolha() -> void:
	if _bolha_escudo:
		return
	var tam := 26
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := (tam - 1) / 2.0
	for y in tam:
		for x in tam:
			var d := Vector2(x - c, y - c).length()
			if d <= c and d > c - 1.6:
				img.set_pixel(x, y, Color(0.6, 0.85, 1.0, 0.9))
			elif d <= c - 1.6 and (x + y) % 7 == 0:
				img.set_pixel(x, y, Color(0.7, 0.9, 1.0, 0.35))
	_bolha_escudo = Sprite2D.new()
	_bolha_escudo.texture = ImageTexture.create_from_image(img)
	_bolha_escudo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bolha_escudo.scale = Vector2.ONE * 4.0
	_bolha_escudo.z_index = 30
	jogo.add_child(_bolha_escudo)


# ================================================================ sorteio

func _disponiveis() -> Array[Resource]:
	var lista: Array[Resource] = []
	for c in todas:
		if not c.acumula and quantas(c.id) > 0:
			continue
		if c.id == "pocao" and jogo.vidas >= jogo.vidas_maximas:
			continue
		lista.append(c)
	return lista


func sortear(n: int) -> Array[Resource]:
	var livres := _disponiveis()
	var escolhidas: Array[Resource] = []
	while escolhidas.size() < n and not livres.is_empty():
		var r := randf() * (PESO_RARIDADE[0] + PESO_RARIDADE[1] + PESO_RARIDADE[2])
		var rar := 0 if r < PESO_RARIDADE[0] else (1 if r < PESO_RARIDADE[0] + PESO_RARIDADE[1] else 2)
		var da_rar := livres.filter(func(c): return c.raridade == rar)
		var c: Resource = (da_rar if not da_rar.is_empty() else livres).pick_random()
		escolhidas.append(c)
		livres.erase(c)
	return escolhidas


# ================================================================ tela de escolha

func oferecer(n: int = 3) -> void:
	if escolhendo or jogo.acabou:
		return
	_ofertas = sortear(n)
	if _ofertas.is_empty():
		return
	escolhendo = true
	_pode_escolher = false
	Engine.time_scale = 1.0
	get_tree().paused = true
	_sel = 0
	_criar_tela()
	var tela: Vector2 = jogo.get_viewport_rect().size
	var tw := create_tween()
	tw.tween_property(_fundo, "color:a", 0.72, 0.3)
	tw.parallel().tween_property(_titulo, "modulate:a", 1.0, 0.3)
	var largura := 288.0
	var espaco := 70.0
	var total := _ofertas.size() * largura + (_ofertas.size() - 1) * espaco
	for i in _ofertas.size():
		var ui := _carta_ui(_ofertas[i])
		camada_escolha.add_child(ui)
		_cartas_ui.append(ui)
		var destino := Vector2((tela.x - total) / 2.0 + i * (largura + espaco), tela.y / 2.0 - 200.0 + 30.0)
		ui.set_meta("base", destino)
		ui.position = destino + Vector2(0, 900)
		ui.rotation = randf_range(-0.25, 0.25)
		var t := create_tween()
		t.tween_interval(0.12 * i)
		t.tween_property(ui, "position", destino, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(ui, "rotation", 0.0, 0.45)
		t.tween_interval(0.1 + 0.08 * (_ofertas.size() - i))
		t.tween_callback(_virar.bind(ui))
	var fim := create_tween()
	fim.tween_interval(0.12 * _ofertas.size() + 1.0)
	fim.tween_callback(func():
		_pode_escolher = true
		_dica.modulate.a = 1.0
		_destacar())


func _criar_tela() -> void:
	camada_escolha = CanvasLayer.new()
	camada_escolha.layer = 30
	add_child(camada_escolha)
	var tela: Vector2 = jogo.get_viewport_rect().size
	_fundo = ColorRect.new()
	_fundo.color = Color(0.04, 0.02, 0.08, 0.0)
	_fundo.size = tela
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	camada_escolha.add_child(_fundo)
	_titulo = jogo._label("ESCOLHA UMA BÊNÇÃO", 64, Color(1, 0.9, 0.6)) as Label
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.size = Vector2(tela.x, 90)
	_titulo.position = Vector2(0, 90)
	_titulo.modulate.a = 0.0
	camada_escolha.add_child(_titulo)
	_dica = jogo._label("1  2  3   ou   ←  →  e  Enter   ·   ou clique", 28, Color(0.8, 0.75, 0.9)) as Label
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.size = Vector2(tela.x, 40)
	_dica.position = Vector2(0, tela.y - 130)
	_dica.modulate.a = 0.0
	camada_escolha.add_child(_dica)


## Monta a carta: verso (aparece primeiro) e frente (moldura + título + ícone + descrição).
func _carta_ui(c: Resource) -> Control:
	var raiz := Control.new()
	raiz.size = Vector2(72, 100) * ESCALA
	raiz.pivot_offset = raiz.size / 2.0
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	var brilho := ColorRect.new()                 # contorno brilhante quando selecionada
	brilho.name = "Brilho"
	brilho.color = Color(CORES_RARIDADE[c.raridade], 0.0)
	brilho.position = Vector2(-10, -10)
	brilho.size = raiz.size + Vector2(20, 20)
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(brilho)

	var frente := Control.new()
	frente.name = "Frente"
	frente.size = raiz.size
	frente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frente.visible = false
	raiz.add_child(frente)
	var mold := TextureRect.new()
	mold.texture = _tex.get(["carta_comum", "carta_rara", "carta_lendaria"][c.raridade])
	mold.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mold.stretch_mode = TextureRect.STRETCH_SCALE
	mold.size = raiz.size
	mold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frente.add_child(mold)
	var tam_titulo := 30 if c.nome.length() <= 13 else (26 if c.nome.length() <= 15 else 23)
	var titulo := jogo._label(c.nome, tam_titulo, COR_TEXTO) as Label
	titulo.remove_theme_color_override("font_shadow_color")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.position = Vector2(36, 38)
	titulo.size = Vector2(216, 36)
	titulo.add_theme_constant_override("shadow_offset_x", 0)
	titulo.add_theme_constant_override("shadow_offset_y", 0)
	frente.add_child(titulo)
	var tem := quantas(c.id)
	var sub := jogo._label(NOMES_RARIDADE[c.raridade] + ("   ·   você tem %d" % tem if tem > 0 else ""), 17,
			Color(CORES_RARIDADE[c.raridade].darkened(0.45))) as Label
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(36, 70)
	sub.size = Vector2(216, 22)
	sub.add_theme_constant_override("shadow_offset_x", 0)
	sub.add_theme_constant_override("shadow_offset_y", 0)
	frente.add_child(sub)
	var ic := TextureRect.new()
	ic.name = "Icone"
	ic.texture = c.icone
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.stretch_mode = TextureRect.STRETCH_SCALE
	ic.size = Vector2(64, 64)
	ic.position = Vector2(144 - 32, 144 - 32)
	ic.pivot_offset = Vector2(32, 32)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frente.add_child(ic)
	var n_letras: int = c.descricao.length()
	var tam_desc := 22 if n_letras <= 45 else (20 if n_letras <= 62 else 18)
	var desc := jogo._label(c.descricao, tam_desc, COR_TEXTO) as Label
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.position = Vector2(46, 218)
	desc.size = Vector2(196, 134)
	desc.add_theme_constant_override("shadow_offset_x", 0)
	desc.add_theme_constant_override("shadow_offset_y", 0)
	desc.add_theme_constant_override("line_spacing", -4)
	frente.add_child(desc)

	var verso := TextureRect.new()
	verso.name = "Verso"
	verso.texture = _tex.get("carta_verso")
	verso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	verso.stretch_mode = TextureRect.STRETCH_SCALE
	verso.size = raiz.size
	verso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(verso)

	raiz.mouse_entered.connect(func():
		if _pode_escolher:
			_sel = _cartas_ui.find(raiz)
			_destacar())
	raiz.gui_input.connect(func(ev: InputEvent):
		if _pode_escolher and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_sel = _cartas_ui.find(raiz)
			_confirmar())
	return raiz


## Vira a carta: achata (scale.x -> 0), troca verso por frente, volta a abrir com um "pulinho".
func _virar(ui: Control) -> void:
	var c: Resource = _ofertas[_cartas_ui.find(ui)]
	var t := create_tween()
	t.tween_property(ui, "scale", Vector2(0.0, 1.08), 0.12).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		ui.get_node("Verso").visible = false
		ui.get_node("Frente").visible = true)
	t.tween_property(ui, "scale", Vector2(1.08, 1.08), 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(ui, "scale", Vector2.ONE, 0.12)
	if c.raridade >= 1:                            # rara/lendária: brilho na hora de virar
		t.tween_callback(func():
			var b: ColorRect = ui.get_node("Brilho")
			var tb := create_tween()
			tb.tween_property(b, "color:a", 0.9, 0.08)
			tb.tween_property(b, "color:a", 0.0, 0.5))
	if c.raridade == 2:
		t.tween_callback(func(): _faiscas(ui, CORES_RARIDADE[2], 26))


func _faiscas(ui: Control, cor: Color, qtd: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = qtd
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = ui.size / 2.0
	p.position = ui.size / 2.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 5.0
	p.scale_amount_max = 8.0
	p.color = cor
	ui.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _destacar() -> void:
	for i in _cartas_ui.size():
		var ui := _cartas_ui[i]
		var base: Vector2 = ui.get_meta("base")
		var sel := i == _sel
		var t := create_tween().set_parallel(true)
		t.tween_property(ui, "position", base + (Vector2(0, -28) if sel else Vector2.ZERO), 0.15).set_trans(Tween.TRANS_QUAD)
		t.tween_property(ui, "scale", Vector2.ONE * (1.06 if sel else 0.96), 0.15)
		t.tween_property(ui, "modulate", Color.WHITE if sel else Color(0.75, 0.72, 0.8), 0.15)
		var b: ColorRect = ui.get_node("Brilho")
		b.color.a = 0.55 if sel else 0.0
		if sel:
			var ic: Control = ui.get_node("Frente/Icone")
			var ti := create_tween()
			ti.tween_property(ic, "scale", Vector2.ONE * 1.2, 0.08)
			ti.tween_property(ic, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)


func _input(event: InputEvent) -> void:
	if not escolhendo or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()      # teclas não passam para o jogo enquanto escolhe
	if not _pode_escolher or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _cartas_ui.size():
		_sel = k - KEY_1
		_destacar()
		_confirmar()
	elif k == KEY_LEFT or k == KEY_A:
		_sel = (_sel - 1 + _cartas_ui.size()) % _cartas_ui.size()
		_destacar()
	elif k == KEY_RIGHT or k == KEY_D:
		_sel = (_sel + 1) % _cartas_ui.size()
		_destacar()
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		_confirmar()


func _confirmar() -> void:
	if not _pode_escolher:
		return
	_pode_escolher = false
	var c: Resource = _ofertas[_sel]
	var ui := _cartas_ui[_sel]
	ui.z_index = 5
	# as outras caem e somem
	for i in _cartas_ui.size():
		if i != _sel:
			var o := _cartas_ui[i]
			var t := create_tween().set_parallel(true)
			t.tween_property(o, "position:y", o.position.y + 700, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.tween_property(o, "rotation", randf_range(-0.5, 0.5), 0.4)
			t.tween_property(o, "modulate:a", 0.0, 0.4)
	_faiscas(ui, CORES_RARIDADE[c.raridade], 30)
	# a escolhida pisca, encolhe e voa até a fileira do HUD
	var destino := posicao_slot(c.id) - ui.size / 2.0
	var tw := create_tween()
	tw.tween_property(ui, "scale", Vector2.ONE * 1.18, 0.1)
	tw.tween_property(ui, "scale", Vector2.ONE * 1.1, 0.1)
	tw.tween_interval(0.25)
	tw.tween_property(ui, "position", destino, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(ui, "scale", Vector2.ONE * 0.2, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ui, "rotation", -0.3, 0.45)
	tw.parallel().tween_property(_fundo, "color:a", 0.0, 0.45)
	tw.parallel().tween_property(_titulo, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_dica, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		adicionar(c)
		jogo._mostrar_aviso(c.nome.to_upper() + "!", CORES_RARIDADE[c.raridade])
		camada_escolha.queue_free()
		_cartas_ui.clear()
		escolhendo = false
		get_tree().paused = false)
