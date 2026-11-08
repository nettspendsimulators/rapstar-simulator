class_name LabelContract
extends RefCounted
## Contrato do jogador com uma gravadora. Guarda os termos aceitos e o andamento: quanto a
## gravadora já recebeu, quanto falta recuperar do adiantamento e quanto sobra do orçamento.
## A divisão das receitas e a ajuda nos custos acontecem no EconomySystem, com estes dados.

const STATUS_ACTIVE := "active"
const STATUS_ENDED := "ended"
const STATUS_TERMINATED := "terminated"

var label_id: String = ""
var start_week: int = 0
var end_week: int = 0
var status: String = STATUS_ACTIVE
var artist_share: float = 0.7
var advance: int = 0
## Adiantamento ainda não recuperado: sai da parte do artista nas receitas.
var recoup_left: int = 0
var marketing_support: float = 0.0
var video_support: float = 0.0
var release_support: float = 0.0
var budget: int = 0
var budget_left: int = 0
var discovery_bonus: float = 0.0
var show_bonus: float = 0.0
## Totais do contrato: receita bruta, parte da gravadora, valor recuperado e custos cobertos.
var gross_total: int = 0
var label_total: int = 0
var recouped_total: int = 0
var covered_total: int = 0


func is_active(week: int) -> bool:
	return status == STATUS_ACTIVE and week < end_week


func weeks_left(week: int) -> int:
	return maxi(end_week - week, 0)


## Divide uma receita: a gravadora fica com a parte dela e, enquanto houver adiantamento a
## recuperar, também com a parte do artista até quitar. Devolve o que chega ao artista.
func split(amount: int) -> Dictionary:
	var label_cut := roundi(amount * (1.0 - artist_share))
	var artist := amount - label_cut
	var recoup := mini(recoup_left, artist)
	recoup_left -= recoup
	artist -= recoup
	gross_total += amount
	label_total += label_cut
	recouped_total += recoup
	return {"gross": amount, "label": label_cut, "recoup": recoup, "artist": artist}


## Parte de um custo que a gravadora paga, dentro do orçamento que sobra.
func cover(support: float, cost: int) -> int:
	var covered := mini(roundi(cost * support), budget_left)
	budget_left -= covered
	covered_total += covered
	return covered


func support_for(category: String) -> float:
	match category:
		"marketing":
			return marketing_support
		"video":
			return video_support
		"release":
			return release_support
	return 0.0


func to_dict() -> Dictionary:
	return {
		"label_id": label_id, "start_week": start_week, "end_week": end_week, "status": status,
		"artist_share": artist_share, "advance": advance, "recoup_left": recoup_left,
		"marketing_support": marketing_support, "video_support": video_support, "release_support": release_support,
		"budget": budget, "budget_left": budget_left, "discovery_bonus": discovery_bonus, "show_bonus": show_bonus,
		"gross_total": gross_total, "label_total": label_total, "recouped_total": recouped_total, "covered_total": covered_total,
	}


static func from_dict(data: Dictionary) -> LabelContract:
	var contract := LabelContract.new()
	contract.label_id = String(data.get("label_id", ""))
	contract.start_week = int(data.get("start_week", 0))
	contract.end_week = int(data.get("end_week", 0))
	contract.status = String(data.get("status", STATUS_ACTIVE))
	contract.artist_share = float(data.get("artist_share", 0.7))
	contract.advance = int(data.get("advance", 0))
	contract.recoup_left = int(data.get("recoup_left", 0))
	contract.marketing_support = float(data.get("marketing_support", 0.0))
	contract.video_support = float(data.get("video_support", 0.0))
	contract.release_support = float(data.get("release_support", 0.0))
	contract.budget = int(data.get("budget", 0))
	contract.budget_left = int(data.get("budget_left", 0))
	contract.discovery_bonus = float(data.get("discovery_bonus", 0.0))
	contract.show_bonus = float(data.get("show_bonus", 0.0))
	contract.gross_total = int(data.get("gross_total", 0))
	contract.label_total = int(data.get("label_total", 0))
	contract.recouped_total = int(data.get("recouped_total", 0))
	contract.covered_total = int(data.get("covered_total", 0))
	return contract
