class_name SongData
extends ReleasableContent
## Novos atributos (gênero, duração...) entram aqui, em to_dict e em from_dict.

## Valor das notas parciais em músicas anteriores ao sistema de colaboradores.
const UNKNOWN_SCORE := -1

var credits := SongCredits.new()
var beat_quality: int = UNKNOWN_SCORE
var production_quality: int = UNKNOWN_SCORE
var feat_score: int = UNKNOWN_SCORE
## Nota sem as melhorias. quality é base_quality + improvement_points.
var base_quality: int = 0
var improvement_points: int = 0
## Sorteados na criação e guardados, para editar colaboradores não sortear a nota de novo.
var beat_roll: float = 0.0
var production_roll: float = 0.0


func status_label() -> String:
	return "Lançada" if is_released() else "Não lançada"


func to_dict() -> Dictionary:
	var data := super()
	data["credits"] = credits.to_dict()
	data["beat_quality"] = beat_quality
	data["production_quality"] = production_quality
	data["feat_score"] = feat_score
	data["base_quality"] = base_quality
	data["improvement_points"] = improvement_points
	data["beat_roll"] = beat_roll
	data["production_roll"] = production_roll
	return data


static func from_dict(data: Dictionary) -> SongData:
	var song := SongData.new()
	song._load_common(data)
	song.credits = SongCredits.from_dict(data.get("credits", {}))
	song.beat_quality = int(data.get("beat_quality", UNKNOWN_SCORE))
	song.production_quality = int(data.get("production_quality", UNKNOWN_SCORE))
	song.feat_score = int(data.get("feat_score", UNKNOWN_SCORE))
	song.base_quality = int(data.get("base_quality", song.quality))
	song.improvement_points = int(data.get("improvement_points", 0))
	song.beat_roll = float(data.get("beat_roll", 0.0))
	song.production_roll = float(data.get("production_roll", 0.0))
	return song
