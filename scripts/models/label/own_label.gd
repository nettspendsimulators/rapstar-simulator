class_name OwnLabel
extends RefCounted
## Gravadora do jogador: identidade, nível, reputação, caixa próprio (separado do dinheiro do
## artista), artistas contratados e livro-caixa. Depósitos e saques passam pelas finanças da carreira.

var name: String = ""
var short: String = ""
var shape: String = "circle"
var color: Color = Color("#f5b82e")
var color2: Color = Color("#16131c")
var founded_week: int = 0
## Índice em LabelRules.levels.
var level: int = 0
var reputation: float = 0.0
var balance: int = 0
var artists: Array[SignedArtist] = []
## Livro-caixa: {week, amount, description, category}. "transfer" são depósitos e saques.
var ledger: Array[Dictionary] = []


func add_entry(week: int, amount: int, description: String, category: String) -> void:
	balance += amount
	ledger.append({"week": week, "amount": amount, "description": description, "category": category})


## Receitas, despesas e lucro, sem contar depósitos e saques.
func totals() -> Dictionary:
	var income := 0
	var expenses := 0
	for entry in ledger:
		if entry["category"] == "transfer":
			continue
		if int(entry["amount"]) > 0:
			income += int(entry["amount"])
		else:
			expenses -= int(entry["amount"])
	return {"income": income, "expenses": expenses, "profit": income - expenses}


func find_artist(artist_id: String) -> SignedArtist:
	for artist in artists:
		if artist.artist_id == artist_id:
			return artist
	return null


func to_dict() -> Dictionary:
	return {
		"name": name, "short": short, "shape": shape, "color": color.to_html(), "color2": color2.to_html(),
		"founded_week": founded_week, "level": level, "reputation": reputation, "balance": balance,
		"artists": artists.map(func(item: SignedArtist) -> Dictionary: return item.to_dict()), "ledger": ledger.duplicate(true),
	}


static func from_dict(data: Dictionary) -> OwnLabel:
	var own := OwnLabel.new()
	own.name = String(data.get("name", ""))
	own.short = String(data.get("short", ""))
	own.shape = String(data.get("shape", "circle"))
	own.color = Color(String(data.get("color", "f5b82e")))
	own.color2 = Color(String(data.get("color2", "16131c")))
	own.founded_week = int(data.get("founded_week", 0))
	own.level = int(data.get("level", 0))
	own.reputation = float(data.get("reputation", 0.0))
	own.balance = int(data.get("balance", 0))
	for item: Dictionary in data.get("artists", []):
		own.artists.append(SignedArtist.from_dict(item))
	for item: Dictionary in data.get("ledger", []):
		own.ledger.append({"week": int(item.get("week", 0)), "amount": int(item.get("amount", 0)),
			"description": String(item.get("description", "")), "category": String(item.get("category", ""))})
	return own
