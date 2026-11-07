class_name Fmt
extends RefCounted
## Formatação de números para exibição: 5430 -> "5.430", -100 -> "-$100".


static func number(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.right(3) + grouped
		digits = digits.left(-3)
	return ("-" if value < 0 else "") + digits + grouped


static func money(value: int) -> String:
	return ("-$" if value < 0 else "$") + number(absi(value))


static func signed_money(value: int) -> String:
	return ("+" if value >= 0 else "") + money(value)


static func signed_number(value: int) -> String:
	return ("+" if value >= 0 else "") + number(value)
