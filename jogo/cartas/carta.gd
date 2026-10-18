extends Resource
## Uma carta (bênção) que o mago pode escolher depois de derrotar um dragão.
## Para criar uma carta nova: duplique um .tres da pasta "dados", mude o id/nome/texto/ícone.
## (O efeito de cada id está programado em cartas.gd; ids novos precisam de código novo.)

@export var id: String = ""
@export var nome: String = "Carta"
@export_multiline var descricao: String = ""
@export_enum("Comum", "Rara", "Lendária") var raridade: int = 0
@export var icone: Texture2D
@export var acumula: bool = true      ## pode pegar mais de uma vez (o efeito soma)
@export var valor: float = 0.0        ## número usado pelo efeito (ex.: 0.5 = +50%)
@export var ativa: bool = true        ## desmarque para tirar a carta do sorteio
