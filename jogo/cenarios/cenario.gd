class_name Cenario
extends Resource
## Cenário de um dragão: céu, camadas de parallax, partículas e música da corrida.

enum Particulas { NENHUMA, BRASAS, CHUVA, AREIA, VENTO, NEVE }

@export var nome: String = ""

@export_group("Céu")
@export var ceu_topo: Color = Color(0.18, 0.04, 0.09)
@export var ceu_horizonte: Color = Color(0.84, 0.35, 0.16)
@export_range(2, 24) var faixas_ceu: int = 9          ## céu em degraus, estilo pixel art
@export_range(0.2, 1.0, 0.01) var altura_horizonte: float = 0.78   ## onde o céu fica mais claro (0 = topo, 1 = base)

@export_group("Camadas (da mais longe para a mais perto)")
@export var camadas: Array[CamadaParallax] = []

@export_group("Partículas")
@export var particulas: Particulas = Particulas.NENHUMA
@export var cor_particulas: Color = Color(1.0, 0.55, 0.2)
@export_range(0, 300) var quantidade: int = 70

@export_group("Música")
@export var musica: AudioStream     ## toca na corrida deste cenário (a luta usa a "Musica Luta" do dragão)
