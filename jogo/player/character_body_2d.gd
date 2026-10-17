extends CharacterBody2D
## Mago: movimento, pulo e animações.
## Os números do pulo e da velocidade podem ser ajustados no Inspetor (nó player).

@export var velocidade: float = 420.0
@export var forca_pulo: float = 820.0
@export var gravidade_extra: float = 1.6
@export var corte_pulo: float = 0.45
@export var modo_runner: bool = true

const COYOTE := 0.10
const BUFFER := 0.12

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var olhando_esquerda := false
var controle_ativo := true
var tempo_no_ar := 0.0
var pulo_guardado := 0.0


func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity += get_gravity() * gravidade_extra * delta
		tempo_no_ar += delta
	else:
		tempo_no_ar = 0.0

	var direcao := 0.0
	if controle_ativo:
		# Pulo
		pulo_guardado = maxf(pulo_guardado - delta, 0.0)

		if Input.is_action_just_pressed("jump"):
			pulo_guardado = BUFFER

		if pulo_guardado > 0.0 and tempo_no_ar <= COYOTE and velocity.y >= 0.0:
			velocity.y = -forca_pulo
			pulo_guardado = 0.0
			tempo_no_ar = COYOTE + 1.0

		# Soltou o botão no meio da subida: pulo mais curto
		if velocity.y < 0.0 and Input.is_action_just_released("jump"):
			velocity.y *= corte_pulo

		direcao = Input.get_axis("left", "right")

	if direcao:
		velocity.x = direcao * velocidade
		olhando_esquerda = direcao < 0
	else:
		velocity.x = move_toward(velocity.x, 0, velocidade)
		if modo_runner:
			olhando_esquerda = false

	move_and_slide()
	_atualizar_animacao(direcao)


func morrer() -> void:
	controle_ativo = false
	velocity.x = 0.0


func _atualizar_animacao(direcao: float) -> void:
	# No runner, "parado" na verdade é correndo para a direita.
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
