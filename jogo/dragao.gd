extends Node2D
## Dragão chefe. Um script só para todos os dragões: cada um é uma cena com valores diferentes
## no Inspetor (elemento, resistências, arte, sons, "jeito de atacar"...). Padrão = Dragão de Fogo.
##
## Como funciona a luta:
##  - Ele mostra uma sequência de ícones. Para cada ícone, aperte o elemento que VENCE aquele
##    ícone (água vence fogo, terra vence água, ar vence terra, fogo vence ar).
##    Teclas: Q = fogo, W = água, E = terra, R = ar (ou 1, 2, 3, 4).
##  - Errou ou o tempo acabou: leva dano. Acertou tudo rápido: PERFEITO, o ataque volta nele.
##  - A cada alguns ataques ele fica ABERTO: aperte elementos para lançar magias nele.

signal derrotado

enum Elemento { FOGO, AGUA, TERRA, AR }
const NOMES := ["Fogo", "Água", "Terra", "Ar"]
const CORES := [Color(1.0, 0.45, 0.2), Color(0.3, 0.62, 1.0), Color(0.62, 0.44, 0.26), Color(0.82, 0.94, 1.0)]
const TECLAS := [KEY_Q, KEY_W, KEY_E, KEY_R]
const LETRAS := ["Q", "W", "E", "R"]

## Qual elemento vence o elemento "e".
static func vence(e: int) -> int:
	return [Elemento.AGUA, Elemento.TERRA, Elemento.AR, Elemento.FOGO][e]

@export_group("Identidade")
@export var nome: String = "Dragão de Fogo"
@export var elemento_principal: Elemento = Elemento.FOGO
@export_range(0.0, 1.0) var chance_principal: float = 0.6   ## quanto da sequência é do elemento dele
@export var resistencias: Array[Elemento] = [Elemento.FOGO]  ## toma metade do dano
@export var fraquezas: Array[Elemento] = [Elemento.AGUA]     ## toma o dobro
@export var cor: Color = Color(1.0, 0.42, 0.22)              ## cor da barra de vida e efeitos

@export_group("Arte do dragão")
## Animações (só "idle" é obrigatória; as que faltarem usam a "idle"):
## idle, ataque, dano, aberto, morte. Desenhe o dragão olhando para a ESQUERDA.
@export var sprite_frames: Resource      ## SpriteFrames (animado) ou só uma imagem PNG
@export var escala: float = 5.0
@export var deslocamento_sprite: Vector2 = Vector2.ZERO   ## move o desenho sem mexer no resto
@export var espelhar_sprite: bool = false                 ## marque se o desenho olha para a direita
@export var pintar_com_cor: bool = false                  ## pinta o sprite com a "cor" (um sprite para vários dragões)
@export var tamanho_hitbox: Vector2 = Vector2.ZERO        ## área que dá dano ao encostar (0 = automático)
@export var posicao_sequencia: Vector2 = Vector2(-330, -330)  ## onde aparecem os ícones, em relação ao dragão

@export_group("Arte dos ataques e ícones")
@export var icones: Array[Texture2D] = []          ## 4 ícones, nesta ordem: fogo, água, terra, ar
## Todos estes aceitam uma imagem PNG ou um SpriteFrames (animado).
@export var projetil_dragao: Resource              ## o ataque que o dragão lança
@export var projetil_dragao_aponta_para_esquerda: bool = false   ## marque se o desenho "vai" para a esquerda
@export var projeteis_jogador: Array[Resource] = []  ## magias do mago, nesta ordem: fogo, água, terra, ar
@export var magias_apontam_para_esquerda: bool = false           ## marque se os desenhos "vão" para a esquerda
@export var efeito_impacto: Resource               ## explosão quando algo acerta
@export var escala_efeitos: float = 5.0

@export_group("Cenário e música")
@export var cenario: Resource              ## arraste aqui o Cenario do dragão (ex.: CenarioFogo.tres)
@export var musica_luta: AudioStream       ## trilha da luta: entra no lugar da música da corrida

@export_group("Sons")
@export var som_entrada: AudioStream       ## rugido quando ele aparece
@export var som_sequencia: AudioStream     ## quando os ícones aparecem
@export var som_acerto: AudioStream        ## cada tecla certa
@export var som_erro: AudioStream          ## tecla errada
@export var som_ataque: AudioStream        ## dragão lança o ataque
@export var som_defendido: AudioStream
@export var som_perfeito: AudioStream
@export var som_mago_atingido: AudioStream
@export var som_aberto: AudioStream        ## quando ele fica vulnerável
@export var som_magia: AudioStream         ## mago lança magia
@export var som_dragao_atingido: AudioStream
@export var som_morte: AudioStream
@export_range(-30.0, 6.0, 0.5) var volume_sons_db: float = -4.0

@export_group("Luta")
@export var vida_maxima: float = 160.0
@export var tamanho_sequencia: int = 3
@export var tamanho_sequencia_furioso: int = 4    ## quando a vida cai abaixo da metade
@export var tempo_resposta: float = 2.8
@export var intervalo_ataques: float = 1.0
@export var ataques_ate_abrir: int = 3
@export var tempo_aberto: float = 3.0
@export var magias_por_abertura: int = 4
@export var dano_magia: float = 6.0
@export var dano_reflexo: float = 10.0
@export var parte_do_tempo_para_perfeito: float = 0.6

@export_group("Jeito de atacar")
@export var sequencia_some: bool = false          ## (Água) os ícones somem e você responde de memória
@export var tempo_ate_sumir: float = 1.4
@export var sequencia_invertida: bool = false     ## (Ar) ler da direita para a esquerda
@export var erro_pesado: bool = false             ## (Terra) qualquer erro tira 2 corações
@export var erro_no_principal_tira_2: bool = false ## errar um ícone do elemento dele tira 2 corações
@export_range(0.0, 1.0) var chance_ataque_duplo: float = 0.0   ## (Ar) chance de emendar uma 2ª sequência na hora
@export var jeito_aleatorio: bool = false         ## (Ancestral/Demônio) cada ataque sorteia um jeito diferente
@export var tempo_extra_por_icone: float = 0.4    ## tempo a mais por ícone além de 3

@export_group("Defesa do dragão")
@export_range(0.1, 1.0, 0.05) var resistencia_geral: float = 1.0  ## multiplica o dano de TODAS as magias (Ancestral)
@export var roleta: bool = false                  ## (Demônio) sorteia um elemento que REFLETE as magias
@export var ataques_por_roleta: int = 3           ## a cada quantos ataques a roleta gira de novo
@export var som_roleta: AudioStream               ## "tic" de cada passo da roleta
@export var som_reflexo: AudioStream              ## magia refletida no mago

@export_group("Mundo durante a luta")
@export_range(1.0, 2.0, 0.05) var acelerar_mundo: float = 1.0      ## obstáculos mais rápidos enquanto ele está vivo

var jogo: Node2D          # o jogo.gd define isto antes de colocar o dragão na cena
var vida := 0.0
var estado := "entrando"  # entrando, pausa, atacando, aberto, morrendo
var timer := 0.0
var tempo := 0.0
var base_y := 0.0

var seq: Array[int] = []
var pos_seq := 0
var erros := 0
var errou_principal := false
var tempo_total := 0.0
var tempo_restante := 0.0
var ataques_feitos := 0
var magias_restantes := 0
var ataques_desde_roleta := 0

# "jeito" do ataque atual (vem das opções acima, ou sorteado no Ancestral/Demônio)
var atual_some := false
var atual_invertida := false
var atual_pesado := false
var duplo_pendente := false
var elemento_proibido := -1      # roleta do Demônio
var painel_roleta: Control
var icone_roleta: TextureRect

var corpo: Node2D
var anim: AnimatedSprite2D
var hitbox: Area2D
var caixa_seq: Control
var linha_icones: HBoxContainer
var barra_tempo: ColorRect
var lbl_status: Label
var ui: CanvasLayer
var barra_vida: ColorRect
var barra_vida_atraso: ColorRect
var tex_icones: Array[Texture2D] = []
var players_som: Array[AudioStreamPlayer] = []


func _ready() -> void:
	vida = vida_maxima
	_preparar_icones()
	_criar_corpo()
	_criar_hitbox()
	_criar_ui_sequencia()
	_criar_ui_tela()
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = volume_sons_db
		add_child(p)
		players_som.append(p)

	var largura: float = jogo.largura_tela
	base_y = jogo.chao_y - 330
	position = Vector2(largura + 320, base_y)
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:x", largura - 290, 1.4)
	t.tween_callback(func(): _ir_para("pausa", 0.8))
	jogo._mostrar_aviso(nome.to_upper(), cor.lightened(0.3))
	_som(som_entrada)
	if musica_luta and jogo.has_method("trocar_musica"):
		jogo.trocar_musica(musica_luta)
	if acelerar_mundo != 1.0:
		jogo.set("velocidade_bonus", acelerar_mundo)
	if roleta:
		_criar_ui_roleta()


func _process(delta: float) -> void:
	if jogo.acabou:
		caixa_seq.visible = false
		return
	tempo += delta
	if estado != "morrendo":
		corpo.position.y = sin(tempo * 2.2) * 14.0       # voando
	_checar_contato()

	match estado:
		"pausa":
			timer -= delta
			if timer <= 0.0:
				if roleta and (elemento_proibido < 0 or ataques_desde_roleta >= ataques_por_roleta):
					_girar_roleta()
				elif ataques_feitos >= ataques_ate_abrir:
					_abrir()
				else:
					_novo_ataque()
		"atacando":
			tempo_restante -= delta
			barra_tempo.size.x = 300.0 * maxf(tempo_restante / tempo_total, 0.0)
			barra_tempo.color = CORES[elemento_principal].lerp(Color(1, 0.25, 0.25), 1.0 - tempo_restante / tempo_total)
			if atual_some and tempo_total - tempo_restante > tempo_ate_sumir:
				for i in seq.size():
					if i >= pos_seq:
						linha_icones.get_child(_indice_visual(i)).modulate.a = 0.0
			if tempo_restante <= 0.0:
				_resolver_ataque(false)
		"aberto":
			timer -= delta
			barra_tempo.size.x = 300.0 * maxf(timer / tempo_aberto, 0.0)
			if timer <= 0.0 or magias_restantes <= 0:
				_fechar()


func _ir_para(novo: String, espera: float = 0.0) -> void:
	estado = novo
	timer = espera


# ================================================================ entrada do jogador

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or jogo.acabou:
		return
	var e := -1
	for i in 4:
		if event.keycode == TECLAS[i] or event.keycode == KEY_1 + i:
			e = i
	if e < 0:
		return
	get_viewport().set_input_as_handled()
	if estado == "atacando":
		_responder(e)
	elif estado == "aberto":
		_lancar_magia(e)


# ================================================================ ataques do dragão

func _novo_ataque(e_duplo: bool = false) -> void:
	var n := tamanho_sequencia_furioso if vida < vida_maxima / 2.0 else tamanho_sequencia
	if e_duplo:
		n = maxi(3, n - 1)           # a 2ª sequência do ataque duplo é um pouco menor
	seq.clear()
	for i in n:
		seq.append(elemento_principal if randf() < chance_principal else randi() % 4)
	pos_seq = 0
	erros = 0
	errou_principal = false

	# Jeito deste ataque
	atual_some = sequencia_some
	atual_invertida = sequencia_invertida
	atual_pesado = erro_pesado
	var chance_duplo := chance_ataque_duplo
	if jeito_aleatorio:
		atual_some = false
		atual_invertida = false
		atual_pesado = false
		chance_duplo = 0.0
		match randi() % 5:
			0: pass                       # normal
			1: atual_some = true
			2: atual_invertida = true
			3: atual_pesado = true
			4: chance_duplo = 1.0
	duplo_pendente = not e_duplo and randf() < chance_duplo

	tempo_total = tempo_resposta + tempo_extra_por_icone * (n - 3)
	tempo_restante = tempo_total
	if not e_duplo:
		ataques_feitos += 1
		ataques_desde_roleta += 1

	_limpar_linha(linha_icones)
	var ordem := range(n)
	if atual_invertida:
		ordem.reverse()      # mostra ao contrário: o jogador lê da direita para a esquerda
	for i in ordem:
		linha_icones.add_child(_icone(seq[i], 72 if n <= 6 else 58))
	var avisos := PackedStringArray()
	if atual_invertida:
		avisos.append("<<< leia da direita")
	if atual_some and jeito_aleatorio:
		avisos.append("memorize!")
	if atual_pesado:
		avisos.append("PESADO: erro tira 2")
	if duplo_pendente:
		avisos.append("ATAQUE DUPLO")
	if e_duplo:
		avisos.append("de novo!")
	lbl_status.text = "   ".join(avisos)
	caixa_seq.visible = true
	_pop(caixa_seq)
	_som(som_sequencia)
	estado = "atacando"


func _indice_visual(i: int) -> int:
	return seq.size() - 1 - i if atual_invertida else i


func _responder(e: int) -> void:
	var alvo := seq[pos_seq]
	var icone := linha_icones.get_child(_indice_visual(pos_seq))
	icone.modulate.a = 1.0
	if e == vence(alvo):
		icone.modulate = Color(0.55, 1.0, 0.6, 0.35)
		_pop(icone)
		_som(som_acerto, 1.0 + pos_seq * 0.08)       # cada acerto um pouco mais agudo
	else:
		erros += 1
		if alvo == elemento_principal:
			errou_principal = true
		icone.modulate = Color(1.0, 0.3, 0.3, 0.9)
		_tremer(icone)
		_som(som_erro)
	pos_seq += 1
	if pos_seq >= seq.size():
		_resolver_ataque(true)


func _resolver_ataque(completou: bool) -> void:
	var falhou := erros > 0 or not completou
	if not completou:
		for i in range(pos_seq, seq.size()):
			if seq[i] == elemento_principal:
				errou_principal = true
	var perfeito := not falhou and (tempo_total - tempo_restante) <= tempo_total * parte_do_tempo_para_perfeito
	var acertados := seq.size()
	caixa_seq.visible = false
	var faz_duplo := duplo_pendente
	duplo_pendente = false
	if faz_duplo:
		estado = "duplo"
		get_tree().create_timer(0.45).timeout.connect(func():
			if estado == "duplo" and not jogo.acabou:
				_novo_ataque(true))
	else:
		_ir_para("pausa", intervalo_ataques)
	_animar("ataque")
	_som(som_ataque)

	var bola := _projetil(projetil_dragao, CORES[elemento_principal], 26, true, projetil_dragao_aponta_para_esquerda)
	bola.global_position = global_position + Vector2(-110, -20)
	var alvo: Vector2 = jogo.player.global_position + Vector2(0, -30)
	var t := create_tween()
	if falhou:
		t.tween_property(bola, "global_position", alvo, 0.35)
		t.tween_callback(func():
			_impacto(bola.global_position, CORES[elemento_principal])
			bola.queue_free()
			if jogo.acabou or jogo.invencivel > 0.0:
				return
			_som(som_mago_atingido)
			jogo.levar_dano()
			if (atual_pesado or (errou_principal and erro_no_principal_tira_2)) and not jogo.acabou:
				jogo.invencivel = 0.0
				jogo.levar_dano())
	else:
		var meio := global_position.lerp(alvo, 0.55)
		t.tween_property(bola, "global_position", meio, 0.22)
		jogo._somar_combo()
		if perfeito:
			_som(som_perfeito)
			jogo._mostrar_aviso("PERFEITO!", Color(1.0, 0.85, 0.35))
			t.tween_callback(func(): _virar_projetil(bola, false, projetil_dragao_aponta_para_esquerda))
			t.tween_property(bola, "global_position", global_position + Vector2(-40, 0), 0.2)
			t.tween_callback(func():
				_impacto(bola.global_position, CORES[elemento_principal])
				bola.queue_free()
				_receber_dano(dano_reflexo * (1.0 + 0.25 * (acertados - 3))))
		else:
			t.tween_callback(func():
				_som(som_defendido)
				_impacto(bola.global_position, Color(0.7, 0.9, 1.0))
				_numero("DEFENDIDO", meio, Color(0.7, 0.9, 1.0))
				bola.queue_free())


# ================================================================ ataque do jogador

func _abrir() -> void:
	estado = "aberto"
	timer = tempo_aberto
	magias_restantes = magias_por_abertura
	_limpar_linha(linha_icones)
	if roleta and elemento_proibido >= 0:
		lbl_status.text = "ABERTO! ATAQUE!   NÃO use:"
		var proibido := _icone(elemento_proibido, 56)
		proibido.add_child(_x_vermelho(56))
		linha_icones.add_child(proibido)
	elif fraquezas.is_empty():
		lbl_status.text = "ABERTO! ATAQUE!   sem fraqueza"
	else:
		lbl_status.text = "ABERTO! ATAQUE!   fraco contra:"
		for f in fraquezas:
			linha_icones.add_child(_icone(f, 56))
	caixa_seq.visible = true
	_pop(caixa_seq)
	_animar("aberto")
	_som(som_aberto)
	var t := create_tween()
	t.tween_property(corpo, "modulate", Color(1.6, 1.6, 1.6), 0.1)
	t.tween_property(corpo, "modulate", Color.WHITE, 0.25)


func _fechar() -> void:
	ataques_feitos = 0
	caixa_seq.visible = false
	lbl_status.text = ""
	_animar("idle")
	_ir_para("pausa", 0.9)


func _lancar_magia(e: int) -> void:
	magias_restantes -= 1
	if roleta and e == elemento_proibido:
		_magia_refletida(e)
		return
	var mult := 1.0
	if e in fraquezas:
		mult = 2.0
	elif e in resistencias:
		mult = 0.5
	mult *= resistencia_geral
	var arte: Resource = projeteis_jogador[e] if e < projeteis_jogador.size() else null
	var bola := _projetil(arte, CORES[e], 20, false, magias_apontam_para_esquerda)
	bola.global_position = jogo.player.global_position + Vector2(30, -40)
	_som(som_magia, randf_range(0.95, 1.08))
	var t := create_tween()
	t.tween_property(bola, "global_position", global_position + Vector2(-60, randf_range(-50, 30)), 0.25)
	t.tween_callback(func():
		_impacto(bola.global_position, CORES[e])
		bola.queue_free()
		_receber_dano(dano_magia * mult, mult))


func _receber_dano(valor: float, mult: float = 1.0) -> void:
	if estado == "morrendo":
		return
	vida -= valor
	var cor_num := Color(1, 0.85, 0.35) if mult > 1.0 else (Color(0.6, 0.6, 0.7) if mult < 1.0 else Color.WHITE)
	var texto := "%d" % ceili(valor) + ("!" if mult > 1.0 else "")
	_numero(texto, global_position + Vector2(randf_range(-60, 40), -120), cor_num)
	_som(som_dragao_atingido, randf_range(0.92, 1.08))
	if estado != "aberto":
		_animar("dano")
	var t := create_tween()
	t.tween_property(corpo, "modulate", Color(2, 2, 2), 0.05)
	t.tween_property(corpo, "modulate", Color.WHITE, 0.15)
	_atualizar_barra_vida()
	if vida <= 0.0:
		_morrer()


func _morrer() -> void:
	estado = "morrendo"
	caixa_seq.visible = false
	if acelerar_mundo != 1.0:
		jogo.set("velocidade_bonus", 1.0)
	hitbox.set_deferred("monitoring", false)
	_animar("morte")
	_som(som_morte)
	if jogo.has_method("voltar_musica_corrida"):
		jogo.voltar_musica_corrida()          # já leva para o cenário e a música do próximo dragão
	jogo._mostrar_aviso(nome.to_upper() + " DERROTADO!", Color(1.0, 0.85, 0.35))
	var t := create_tween()
	for i in 10:
		t.tween_property(corpo, "position", Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.05)
	t.tween_property(corpo, "modulate", Color(3, 3, 3, 1), 0.1)
	t.tween_property(self, "position:y", base_y + 500, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	for c in ui.get_children():                  # barra de vida e legenda somem juntas
		t.parallel().tween_property(c, "modulate:a", 0.0, 0.5)
	t.tween_interval(0.3)   # deixa o som da morte terminar
	t.tween_callback(func():
		derrotado.emit()
		queue_free())


func _checar_contato() -> void:
	if estado == "morrendo" or jogo.invencivel > 0.0 or jogo.acabou:
		return
	if hitbox.overlaps_body(jogo.player):
		_som(som_mago_atingido)
		jogo.levar_dano()


# ================================================================ som e animação

func _som(stream: AudioStream, tom: float = 1.0) -> void:
	if stream == null:
		return
	for p in players_som:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = tom
			p.play()
			return
	players_som[0].stream = stream          # todos ocupados: reaproveita o primeiro
	players_som[0].pitch_scale = tom
	players_som[0].play()


func _animar(nome_anim: String) -> void:
	if anim == null:
		return
	var a := nome_anim if anim.sprite_frames.has_animation(nome_anim) else "idle"
	if not anim.sprite_frames.has_animation(a):
		return
	anim.play(a)
	# Animações de uma vez só (ataque, dano) voltam para a base quando terminam.
	if a in ["ataque", "dano"]:
		var duracao := anim.sprite_frames.get_frame_count(a) / maxf(anim.sprite_frames.get_animation_speed(a), 0.1)
		get_tree().create_timer(duracao).timeout.connect(func():
			if is_instance_valid(anim) and anim.animation == a and estado != "morrendo":
				anim.play("aberto" if estado == "aberto" and anim.sprite_frames.has_animation("aberto") else "idle"))


# ================================================================ visual

func _preparar_icones() -> void:
	for i in 4:
		if i < icones.size() and icones[i]:
			tex_icones.append(icones[i])
		else:
			tex_icones.append(_icone_provisorio(i))


func _icone(e: int, tamanho: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex_icones[e]
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(tamanho, tamanho)
	r.pivot_offset = Vector2(tamanho, tamanho) / 2.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _icone_provisorio(e: int) -> ImageTexture:
	var desenhos := [
		["...X....", "..XX....", "..XXX.X.", ".XXXXXX.", ".XXOOXX.", "XXOOOOXX", "XXOOOOXX", ".XXXXXX."],
		["...XX...", "...XX...", "..XXXX..", ".XXXXXX.", ".XOXXXX.", ".XOXXXX.", "..XXXX..", "........"],
		["........", "...X....", "..XXX...", "..XXXX..", ".XXOXXX.", ".XXXXOXX", "XXXXXXXX", "........"],
		["........", ".XXXXX..", "......X.", "XXXXXX..", "........", "..XXXXXX", ".X......", "..XXX..."]]
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var c: String = desenhos[e][y][x]
			if c == "X":
				img.set_pixel(x, y, CORES[e])
			elif c == "O":
				img.set_pixel(x, y, CORES[e].lightened(0.55))
	return ImageTexture.create_from_image(img)


func _criar_corpo() -> void:
	corpo = Node2D.new()
	add_child(corpo)
	if sprite_frames is Texture2D:            # uma imagem só: vira um SpriteFrames de 1 quadro
		var sf := SpriteFrames.new()
		sf.add_frame("default", sprite_frames)
		sf.rename_animation("default", "idle")
		sprite_frames = sf
	if sprite_frames is SpriteFrames:
		anim = AnimatedSprite2D.new()
		anim.sprite_frames = sprite_frames
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim.scale = Vector2.ONE * escala
		anim.position = deslocamento_sprite
		anim.flip_h = espelhar_sprite
		if pintar_com_cor:
			anim.modulate = cor
		corpo.add_child(anim)
		_animar("idle")
		return
	# Dragão provisório (olhando para a esquerda) até o Christian desenhar o de verdade.
	var e := escala
	var escuro := cor.darkened(0.45)
	var partes := [
		[escuro, [Vector2(-4, -10), Vector2(10, -34), Vector2(26, -36), Vector2(18, -12), Vector2(30, -6), Vector2(6, -2)]],
		[cor, [Vector2(-14, -2), Vector2(-6, -12), Vector2(12, -12), Vector2(22, -4), Vector2(34, 2), Vector2(44, -2), Vector2(38, 8), Vector2(20, 10), Vector2(-4, 10)]],
		[cor, [Vector2(-26, -14), Vector2(-14, -18), Vector2(-8, -12), Vector2(-10, -4), Vector2(-18, -2), Vector2(-28, -6)]],
		[escuro, [Vector2(-14, -18), Vector2(-10, -26), Vector2(-9, -16)]],
		[cor.lightened(0.15), [Vector2(0, -10), Vector2(8, -30), Vector2(20, -28), Vector2(12, -10), Vector2(22, -6), Vector2(4, -4)]],
		[escuro, [Vector2(-6, 10), Vector2(-2, 10), Vector2(-3, 16), Vector2(-7, 16)]],
		[escuro, [Vector2(10, 10), Vector2(14, 10), Vector2(13, 16), Vector2(9, 16)]],
		[Color(1, 0.9, 0.3), [Vector2(-20, -12), Vector2(-17, -12), Vector2(-17, -9), Vector2(-20, -9)]]]
	for p in partes:
		var poly := Polygon2D.new()
		poly.color = p[0]
		var pts := PackedVector2Array()
		for v in p[1]:
			pts.append(v * e)
		poly.polygon = pts
		corpo.add_child(poly)


func _criar_hitbox() -> void:
	hitbox = Area2D.new()
	var forma := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	if tamanho_hitbox != Vector2.ZERO:
		r.size = tamanho_hitbox
		forma.position = deslocamento_sprite
	elif anim:
		var tex := anim.sprite_frames.get_frame_texture(anim.animation, 0)
		r.size = (tex.get_size() * escala * 0.7) if tex else Vector2(230, 120)
		forma.position = deslocamento_sprite
	else:
		r.size = Vector2(46, 24) * escala
		forma.position = Vector2(0, -2) * escala
	forma.shape = r
	hitbox.add_child(forma)
	corpo.add_child(hitbox)


func _criar_ui_sequencia() -> void:
	caixa_seq = VBoxContainer.new()
	caixa_seq.position = posicao_sequencia
	caixa_seq.custom_minimum_size = Vector2(420, 0)
	caixa_seq.add_theme_constant_override("separation", 6)
	caixa_seq.visible = false
	add_child(caixa_seq)

	lbl_status = _label("", 26, Color(1, 0.9, 0.7))
	caixa_seq.add_child(lbl_status)
	linha_icones = HBoxContainer.new()
	linha_icones.add_theme_constant_override("separation", 10)
	caixa_seq.add_child(linha_icones)
	var fundo_barra := ColorRect.new()
	fundo_barra.custom_minimum_size = Vector2(300, 8)
	fundo_barra.color = Color(0, 0, 0, 0.5)
	caixa_seq.add_child(fundo_barra)
	barra_tempo = ColorRect.new()
	barra_tempo.size = Vector2(300, 8)
	fundo_barra.add_child(barra_tempo)


func _criar_ui_tela() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var largura: float = jogo.largura_tela

	var titulo := _label(nome.to_upper(), 30, cor.lightened(0.35))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(largura / 2 - 400, 28)
	titulo.size = Vector2(800, 40)
	ui.add_child(titulo)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.position = Vector2(largura / 2 - 400, 74)
	fundo.size = Vector2(800, 18)
	ui.add_child(fundo)
	barra_vida_atraso = ColorRect.new()
	barra_vida_atraso.color = Color(1, 1, 1, 0.6)
	barra_vida_atraso.position = fundo.position + Vector2(3, 3)
	barra_vida_atraso.size = Vector2(794, 12)
	ui.add_child(barra_vida_atraso)
	barra_vida = ColorRect.new()
	barra_vida.color = cor
	barra_vida.position = fundo.position + Vector2(3, 3)
	barra_vida.size = Vector2(794, 12)
	ui.add_child(barra_vida)

	# Legenda: teclas e quem vence quem
	var legenda := HBoxContainer.new()
	legenda.position = Vector2(largura / 2 - 470, 1010)
	legenda.add_theme_constant_override("separation", 14)
	ui.add_child(legenda)
	for i in 4:
		legenda.add_child(_icone(i, 40))
		legenda.add_child(_label(LETRAS[i] + "    ", 28, Color(0.95, 0.92, 0.85)))
	legenda.add_child(_label("|   ", 28, Color(0.6, 0.56, 0.72)))
	for i in 4:
		legenda.add_child(_icone(vence(i), 30))
		legenda.add_child(_label(">", 24, Color(0.6, 0.56, 0.72)))
		legenda.add_child(_icone(i, 30))
		legenda.add_child(_label("  ", 24, Color.WHITE))


func _atualizar_barra_vida() -> void:
	var w := 794.0 * maxf(vida / vida_maxima, 0.0)
	barra_vida.size.x = w
	create_tween().tween_property(barra_vida_atraso, "size:x", w, 0.5).set_delay(0.25)


func _label(texto: String, tamanho: int, c: Color) -> Label:
	var l := Label.new()
	l.text = texto
	if jogo.fonte_hud:
		l.add_theme_font_override("font", jogo.fonte_hud)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _limpar_linha(linha: Container) -> void:
	for c in linha.get_children():
		linha.remove_child(c)
		c.queue_free()


func _projetil(arte: Resource, c: Color, tamanho: float, para_esquerda: bool, desenho_esquerda: bool) -> Node2D:
	var n := Node2D.new()
	var s: Node2D = _sprite_de(arte)
	if s:
		s.name = "Sprite"
		s.scale = Vector2.ONE * escala_efeitos
		s.set("flip_h", para_esquerda != desenho_esquerda)
		n.add_child(s)
	else:
		var brilho := ColorRect.new()
		brilho.color = Color(c, 0.35)
		brilho.size = Vector2(tamanho, tamanho) * 1.8
		brilho.position = -brilho.size / 2
		n.add_child(brilho)
		var nucleo := ColorRect.new()
		nucleo.color = c.lightened(0.3)
		nucleo.size = Vector2(tamanho, tamanho)
		nucleo.position = -nucleo.size / 2
		n.add_child(nucleo)
	jogo.add_child(n)
	return n


func _virar_projetil(bola: Node2D, para_esquerda: bool, desenho_esquerda: bool) -> void:
	if bola.has_node("Sprite"):
		bola.get_node("Sprite").set("flip_h", para_esquerda != desenho_esquerda)


## Cria o desenho certo para uma imagem (Sprite2D) ou um SpriteFrames (AnimatedSprite2D).
func _sprite_de(arte: Resource) -> Node2D:
	if arte is Texture2D:
		var sp := Sprite2D.new()
		sp.texture = arte
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return sp
	if arte is SpriteFrames:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = arte
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		a.play()
		return a
	return null


func _impacto(pos: Vector2, c: Color) -> void:
	if efeito_impacto:
		var s: Node2D = _sprite_de(efeito_impacto)
		s.scale = Vector2.ONE * escala_efeitos
		s.global_position = pos
		jogo.add_child(s)
		var duracao := 0.25
		if efeito_impacto is SpriteFrames:
			var a: StringName = s.animation
			duracao = efeito_impacto.get_frame_count(a) / maxf(efeito_impacto.get_animation_speed(a), 0.1)
		else:                                   # imagem parada: cresce e some
			var t := s.create_tween().set_parallel(true)
			t.tween_property(s, "scale", s.scale * 1.6, duracao)
			t.tween_property(s, "modulate:a", 0.0, duracao)
		get_tree().create_timer(duracao).timeout.connect(s.queue_free)
	else:
		var r := ColorRect.new()
		r.color = Color(c, 0.8)
		r.size = Vector2(40, 40)
		r.position = pos - r.size / 2
		r.pivot_offset = r.size / 2
		jogo.add_child(r)
		var t := r.create_tween().set_parallel(true)
		t.tween_property(r, "scale", Vector2.ONE * 2.2, 0.2)
		t.tween_property(r, "modulate:a", 0.0, 0.2)
		t.chain().tween_callback(r.queue_free)


func _numero(texto: String, pos: Vector2, c: Color) -> void:
	var l := _label(texto, 40, c)
	l.global_position = pos
	jogo.add_child(l)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "global_position:y", pos.y - 70, 0.7).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


func _pop(c: CanvasItem) -> void:
	if c is Control:
		c.pivot_offset = c.size / 2.0
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE * 1.18, 0.07)
	t.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)


func _tremer(c: Control) -> void:
	var x := c.position.x
	var t := create_tween()
	for i in 4:
		t.tween_property(c, "position:x", x + (8 if i % 2 == 0 else -8), 0.03)
	t.tween_property(c, "position:x", x, 0.03)


# ================================================================ roleta do Demônio

func _criar_ui_roleta() -> void:
	painel_roleta = VBoxContainer.new()
	painel_roleta.position = Vector2(jogo.largura_tela / 2 + 430, 24)
	painel_roleta.add_theme_constant_override("separation", 2)
	ui.add_child(painel_roleta)
	painel_roleta.add_child(_label("PROIBIDO", 22, Color(1, 0.4, 0.4)))
	icone_roleta = _icone(0, 64)
	icone_roleta.add_child(_x_vermelho(64))
	painel_roleta.add_child(icone_roleta)
	painel_roleta.modulate.a = 0.0


func _girar_roleta() -> void:
	estado = "roleta"
	ataques_desde_roleta = 0
	var anterior := elemento_proibido
	var novo := randi() % 4
	while novo == anterior:
		novo = randi() % 4
	jogo._mostrar_aviso("A ROLETA GIRA...", Color(1, 0.4, 0.4))
	painel_roleta.modulate.a = 1.0
	var x := icone_roleta.get_child(0)
	x.visible = false
	# gira mostrando os elementos, cada vez mais devagar
	var t := create_tween()
	var passos := 12 + (novo - anterior + 4) % 4
	var espera := 0.05
	for i in passos:
		var mostrar := (anterior + 1 + i) % 4 if anterior >= 0 else i % 4
		t.tween_callback(func():
			icone_roleta.texture = tex_icones[mostrar]
			_som(som_roleta, 1.0 + i * 0.02))
		t.tween_interval(espera)
		espera *= 1.14
	t.tween_callback(func():
		elemento_proibido = novo
		icone_roleta.texture = tex_icones[novo]
		x.visible = true
		_pop(icone_roleta)
		jogo._mostrar_aviso("NÃO USE " + NOMES[novo].to_upper() + "!", CORES[novo].lightened(0.2))
		_ir_para("pausa", 1.2))


func _magia_refletida(e: int) -> void:
	var arte: Resource = projeteis_jogador[e] if e < projeteis_jogador.size() else null
	var bola := _projetil(arte, CORES[e], 20, false, magias_apontam_para_esquerda)
	bola.global_position = jogo.player.global_position + Vector2(30, -40)
	_som(som_magia)
	var bate := global_position + Vector2(-80, 0)
	var t := create_tween()
	t.tween_property(bola, "global_position", bate, 0.22)
	t.tween_callback(func():
		_som(som_reflexo)
		_numero("REFLETIDO!", bate + Vector2(-40, -80), Color(1, 0.35, 0.35))
		_virar_projetil(bola, true, magias_apontam_para_esquerda))
	t.tween_property(bola, "global_position", jogo.player.global_position + Vector2(0, -30), 0.25)
	t.tween_callback(func():
		_impacto(bola.global_position, Color(1, 0.3, 0.3))
		bola.queue_free()
		if not jogo.acabou and jogo.invencivel <= 0.0:
			_som(som_mago_atingido)
			jogo.levar_dano())


func _x_vermelho(tamanho: int) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(tamanho, tamanho)
	c.size = Vector2(tamanho, tamanho)
	var passo := maxi(3, tamanho / 10)
	var n := tamanho / passo
	for i in n:
		for j in [i, n - 1 - i]:
			var r := ColorRect.new()
			r.color = Color(0.95, 0.15, 0.2, 0.9)
			r.size = Vector2(passo, passo)
			r.position = Vector2(i * passo, j * passo)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(r)
	return c
