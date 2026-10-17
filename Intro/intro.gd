extends Control

@export var video_intro: VideoStream
@export_file("*.tscn") var proxima_cena: String = "res://Menu.tscn"
@export var pode_pular: bool = true          
@export var espera_antes_de_pular: float = 0.6 

var player: VideoStreamPlayer
var fade: ColorRect
var tempo := 0.0
var terminando := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var preto := ColorRect.new()
	preto.color = Color.BLACK
	add_child(preto)
	preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	player = VideoStreamPlayer.new()
	player.expand = true
	add_child(player)
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for no in [preto, player, fade]:
		no.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if video_intro == null:
		push_warning("Intro sem vídeo: arraste o .ogv no campo 'Video Intro'.")
		_ir_para_proxima.call_deferred()
		return

	player.stream = video_intro
	# O vídeo já termina em preto e silêncio, então troca direto, sem pausa.
	player.finished.connect(_ir_para_proxima.bind(true))
	player.play()

func _process(delta: float) -> void:
	tempo += delta

func _unhandled_input(event: InputEvent) -> void:
	if not pode_pular or terminando or tempo < espera_antes_de_pular:
		return
	var apertou := (event is InputEventKey or event is InputEventMouseButton \
		or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if apertou:
		get_viewport().set_input_as_handled()
		_ir_para_proxima()


func _ir_para_proxima(acabou_sozinho := false) -> void:
	if terminando:
		return
	terminando = true
	if acabou_sozinho:
		get_tree().change_scene_to_file(proxima_cena)
		return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(fade, "modulate:a", 1.0, 0.5)
	t.parallel().tween_property(player, "volume_db", -60.0, 0.5)
	t.tween_callback(func(): get_tree().change_scene_to_file(proxima_cena))
