extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var olhando_esquerda := false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direcao := Input.get_axis("ui_left", "ui_right")
	if direcao:
		velocity.x = direcao * SPEED
		olhando_esquerda = direcao < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_atualizar_animacao(direcao)


func _atualizar_animacao(direcao: float) -> void:
	var anim := ""
	if not is_on_floor():
		if velocity.y < 0:
			if direcao < 0:
				anim = "pulo_esquerda"
			elif direcao > 0:
				anim = "pulo_direita"
			else:
				anim = "pulo"
		else:
			anim = "queda"
	elif direcao < 0:
		anim = "andar_esquerda"
	elif direcao > 0:
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
