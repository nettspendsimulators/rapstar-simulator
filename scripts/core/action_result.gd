class_name ActionResult
extends RefCounted
## Resultado de uma ação do jogador: a UI mostra a mensagem sem conhecer as regras.

var ok: bool = false
var message: String = ""
var value: Variant = null


static func success(result_message: String = "", result_value: Variant = null) -> ActionResult:
	var result := ActionResult.new()
	result.ok = true
	result.message = result_message
	result.value = result_value
	return result


static func failure(result_message: String) -> ActionResult:
	var result := ActionResult.new()
	result.message = result_message
	return result
