class_name SongData
extends ReleasableContent
## Novos atributos (gênero, duração...) entram aqui, em to_dict e em from_dict.

const ATTRIBUTE_VOCAL := "vocal"
const ATTRIBUTE_LYRICS := "lyrics"
const ATTRIBUTE_BEAT := "beat"
const ATTRIBUTE_PRODUCTION := "production"

var credits := SongCredits.new()
var sample := SongSample.new()
## Nota inicial de cada atributo, por id.
var attribute_bases: Dictionary[String, int] = {}
## Pontos que as melhorias somaram a cada atributo, por id.
var attribute_points: Dictionary[String, int] = {}
var feat_score: int = 0
## Sorteados na criação e guardados, para editar colaboradores não sortear a nota de novo.
var beat_roll: float = 0.0
var production_roll: float = 0.0


func status_label() -> String:
	return "Lançada" if is_released() else "Não lançada"

## Diss track: artista alvo (vazio numa música normal) e o beef ligado ao lançamento.
var diss_target_id: String = ""
var beef_id: String = ""


func attribute_value(attribute_id: String) -> int:
	return mini(attribute_bases.get(attribute_id, 0) + attribute_points.get(attribute_id, 0), 100)


func to_dict() -> Dictionary:
	var data := super()
	data["credits"] = credits.to_dict()
	data["sample"] = sample.to_dict()
	data["attribute_bases"] = attribute_bases
	data["attribute_points"] = attribute_points
	data["feat_score"] = feat_score
	data["beat_roll"] = beat_roll
	data["production_roll"] = production_roll
	data["diss_target_id"] = diss_target_id
	data["beef_id"] = beef_id
	return data


static func from_dict(data: Dictionary) -> SongData:
	var song := SongData.new()
	song._load_common(data)
	song.credits = SongCredits.from_dict(data.get("credits", {}))
	song.sample = SongSample.from_dict(data.get("sample", {}))
	song.attribute_bases = _int_values(data.get("attribute_bases", {}))
	song.attribute_points = _int_values(data.get("attribute_points", {}))
	song.feat_score = int(data.get("feat_score", 0))
	song.beat_roll = float(data.get("beat_roll", 0.0))
	song.diss_target_id = data.get("diss_target_id", "")
	song.beef_id = data.get("beef_id", "")
	song.production_roll = float(data.get("production_roll", 0.0))
	return song


## O JSON lê todos os números como float.
static func _int_values(source: Dictionary) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	for key: String in source:
		result[key] = int(source[key])
	return result
