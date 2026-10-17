class_name CamadaParallax
extends Resource
## Uma camada do cenário (montanhas do fundo, ruínas do meio, chão da frente...).

@export var textura: Texture2D
## 0 = parada (bem longe), 1 = anda junto com o chão e os obstáculos
@export_range(0.0, 1.5, 0.01) var velocidade: float = 0.3
## Onde fica a BASE da camada: pixels acima do chão (+) ou abaixo (-)
@export var altura: float = 0.0
@export var escala: float = 5.0
## Repete a imagem espelhando (esconde a emenda quando a imagem não foi feita para repetir)
@export var espelhar_ao_repetir: bool = true
## Movimento próprio em pixels/segundo (ex.: nuvens andando mesmo com o jogo parado)
@export var vento: float = 0.0
@export var cor: Color = Color.WHITE
