extends CharacterBody2D
## Mago: movimento, pulo e animações.
## Os números do pulo e da velocidade podem ser ajustados no Inspetor (nó player).

@export var velocidade: float = 420.0
@export var forca_pulo: float = 820.0
@export var gravidade_extra: float = 1.6     ## acima de 1 = pulo mais "seco", cai mais rápido
@export var corte_pulo: float = 0.45         ## soltar o botão cedo = pulo mais baixo
@export var modo_runner: bool = true         ## no runner ele está sempre correndo para a direita

@export_group("Desenho do mago")
## Quantos pixels da tela cada pixel do desenho ocupa. O mago novo (32x32) fica do tamanho
## do antigo com 3. Coloque 0 para não mexer no tamanho/posição que estiver na cena.
@export var tamanho_do_pixel: float = 3.0
@export var tempo_pouso: float = 0.16         ## quanto tempo ele fica "amassado" ao cair no chão

@export_group("Impacto (amassar e esticar)")
@export var amassar_no_pouso: float = 0.35    ## 0 = desliga. Quanto ele achata ao cair (0.35 = 35%)
@export var esticar_no_pulo: float = 0.25     ## 0 = desliga. Quanto ele estica ao pular
@export var tempo_volta: float = 0.32         ## quanto demora para voltar ao normal (com um "boing")
@export var queda_forte: float = 1100.0       ## velocidade de queda que dá o impacto máximo

const COYOTE := 0.10   ## ainda dá para pular logo depois de sair da beirada
const BUFFER := 0.12   ## apertar pulo um pouco antes de tocar o chão também vale

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var olhando_esquerda := false
var controle_ativo := true
var tempo_no_ar := 0.0
var pulo_guardado := 0.0
var _estava_no_chao := true
var _pousando := 0.0
var _escala_base := Vector2.ONE
var _tween_impacto: Tween
var _vel_queda := 0.0

# Influências do cenário (o jogo/dragão mexe nestes valores durante a luta)
var escorregadio := 0.0   ## 0 = normal, perto de 1 = gelo (Água)
var vento := 0.0          ## empurra para os lados o tempo todo, em px/s (Ar: negativo = esquerda)
var empurrao := 0.0       ## tranco que vai sumindo (ex.: encostou nas chamas)
var _vx := 0.0            ## velocidade "das pernas", sem vento nem tranco


func _ready() -> void:
	_ajustar_desenho()


## Deixa o desenho do tamanho certo e com os pés encostando no chão da colisão,
## não importa o tamanho do quadro (16x16 antigo, 40x32 novo) nem a escala do nó.
func _ajustar_desenho() -> void:
	if tamanho_do_pixel <= 0.0 or sprite.sprite_frames == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	if tex == null:
		return
	var escala_no := absf(global_scale.y) if absf(global_scale.y) > 0.0 else 1.0
	sprite.scale = Vector2.ONE * tamanho_do_pixel / escala_no
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	var pe := 0.0
	var forma := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma and forma.shape is RectangleShape2D:
		pe = forma.position.y + (forma.shape as RectangleShape2D).size.y / 2.0 * forma.scale.y
	elif forma and forma.shape:
		pe = forma.position.y + forma.shape.get_rect().end.y * forma.scale.y
	# o "pivô" do desenho fica nos pés: assim ele amassa/estica sem afundar no chão
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	sprite.position = Vector2(0, pe)
	_escala_base = sprite.scale


func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity += get_gravity() * gravidade_extra * delta
		tempo_no_ar += delta
	else:
		tempo_no_ar = 0.0

	var direcao := 0.0
	if controle_ativo:
		# Pulo (Espaço, Enter ou seta para cima)
		pulo_guardado = maxf(pulo_guardado - delta, 0.0)
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
			pulo_guardado = BUFFER
		if pulo_guardado > 0.0 and tempo_no_ar <= COYOTE and velocity.y >= 0.0:
			velocity.y = -forca_pulo
			_deformar(Vector2(1.0 - esticar_no_pulo * 0.7, 1.0 + esticar_no_pulo))
			pulo_guardado = 0.0
			tempo_no_ar = COYOTE + 1.0
		# Soltou o botão no meio da subida: pulo mais curto
		if velocity.y < 0.0 and (Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")):
			velocity.y *= corte_pulo

		direcao = Input.get_axis("ui_left", "ui_right")

	if direcao:
		olhando_esquerda = direcao < 0
	elif modo_runner:
		olhando_esquerda = false
	var alvo := direcao * velocidade
	if escorregadio > 0.0:
		# chão molhado: demora para acelerar e para frear (no ar escorrega um pouco menos)
		var aderencia := lerpf(18.0, 0.6, clampf(escorregadio, 0.0, 0.98))
		if not is_on_floor():
			aderencia *= 1.6
		_vx = move_toward(_vx, alvo, velocidade * aderencia * delta)
	else:
		_vx = alvo
	empurrao = move_toward(empurrao, 0.0, 2600.0 * delta)
	velocity.x = _vx + vento + empurrao

	if velocity.y > 0.0:
		_vel_queda = velocity.y
	move_and_slide()
	var no_chao := is_on_floor()
	if no_chao and not _estava_no_chao and sprite.sprite_frames.has_animation("pouso"):
		_pousando = tempo_pouso
		var forca := clampf(_vel_queda / queda_forte, 0.35, 1.0) * amassar_no_pouso
		_deformar(Vector2(1.0 + forca * 1.1, 1.0 - forca))
	_estava_no_chao = no_chao
	_pousando = maxf(_pousando - delta, 0.0)
	_atualizar_animacao(direcao)


## Amassa/estica o desenho na hora e volta ao normal com um "boing" (squash & stretch).
func _deformar(fator: Vector2) -> void:
	if _escala_base == Vector2.ONE and tamanho_do_pixel > 0.0:
		_escala_base = sprite.scale
	if fator == Vector2.ONE or (amassar_no_pouso <= 0.0 and fator.y < 1.0) or (esticar_no_pulo <= 0.0 and fator.y > 1.0):
		return
	if _tween_impacto:
		_tween_impacto.kill()
	sprite.scale = _escala_base * fator
	_tween_impacto = create_tween()
	_tween_impacto.tween_interval(0.05)                       # segura o "achatado" um instante
	var rebote := Vector2(2.0, 2.0) - fator                   # passa um pouco do normal para o outro lado
	_tween_impacto.tween_property(sprite, "scale", _escala_base * rebote.lerp(Vector2.ONE, 0.6), tempo_volta * 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_impacto.tween_property(sprite, "scale", _escala_base, tempo_volta * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func morrer() -> void:
	controle_ativo = false
	velocity.x = 0.0
	_vx = 0.0
	vento = 0.0
	empurrao = 0.0
	escorregadio = 0.0


func _atualizar_animacao(direcao: float) -> void:
	# No runner, "parado" na verdade é correndo para a direita (o mundo é que se move).
	var dir_anim := direcao
	if modo_runner and dir_anim == 0.0 and controle_ativo:
		dir_anim = 1.0

	var anim := ""
	if not controle_ativo and is_on_floor():
		anim = "parado"
	elif not is_on_floor():
		if velocity.y < 0:
			if dir_anim < 0:
				anim = "pulo_esquerda"
			elif dir_anim > 0:
				anim = "pulo_direita"
			else:
				anim = "pulo"
		else:
			anim = "queda"
	elif _pousando > 0.0:
		anim = "pouso"
	elif dir_anim < 0:
		anim = "andar_esquerda"
	elif dir_anim > 0:
		anim = "andar_direita"
	else:
		anim = "parado"

	var tem_lado := anim.begins_with("andar") or anim.begins_with("pulo_")
	sprite.flip_h = olhando_esquerda and not tem_lado

	if sprite.animation != anim:
		var era_pulo := String(sprite.animation).begins_with("pulo")
		var quadro := sprite.frame
		var progresso := sprite.frame_progress
		sprite.play(anim)
		if era_pulo and anim.begins_with("pulo"):
			sprite.set_frame_and_progress(quadro, progresso)
