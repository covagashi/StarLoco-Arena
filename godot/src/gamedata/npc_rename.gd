extends RefCounted

## Our own names for the tutorial characters (the lobby's "Aprendizaje":
## the twelve class masters, Baan, and Adamai of the intro), the owner's call
## on 2026-10-24 ("cambia los nombres por si acaso"): the retail ones are
## Ankama's. One name for every language; edit them here. Since S26 the
## time demons too (Maya day signs, "Señores del Tiempo").
##
## NpcDialogs runs every content text through apply(), so a name changes in
## the services list, the talk title and any line that mentions it alike.

## content.29 name id -> our name
const NAMES := {
	170: "Tobías", 171: "Saeta", 172: "Rufo", 173: "Nerea", 174: "Bombín",
	175: "Teodoro", 176: "Aurelio", 177: "Lía", 178: "Fermín", 179: "Zoe",
	180: "Elvio", 181: "Mateo", 295: "Nilo",
	262: "Imix", 263: "Ik'", 264: "Ak'bal", 265: "K'an", 266: "Chikchan", 281: "Kimi",
}

## The retail names in es / en / fr, as the data spells them -> our name.
## Longest first, so "Edy Raiser" goes before any shorter overlap.
const OLD := {
	"Edy Raiser": "Elvio", "Ed Isace": "Elvio", "Ed eraser": "Elvio",
	"Scartrine": "Saeta", "Cikatrin": "Saeta", "Cicatrine": "Saeta",
	"Pepítox": "Tobías", "Pepitoo": "Tobías", "Pépitox": "Tobías",
	"Nosigar": "Bombín", "Patapuf": "Bombín", "Pataclop": "Bombín",
	"Estalad": "Teodoro", "Stalad": "Teodoro",
	"Lithian": "Lía", "Litio": "Lía",
	"Greeny": "Rufo", "Gruñy": "Rufo", "Grüny": "Rufo",
	"Gatiel": "Mateo", "Guitel": "Mateo",
	"Rutger": "Aurelio", "Roger": "Aurelio",
	"Vidow": "Nerea", "Ewon": "Nerea",
	"Dazil": "Zoe", "Dzee": "Zoe", "Zee": "Zoe",
	"Adamai": "Aldebrán", "Adamaï": "Aldebrán",
	"Baan": "Nilo",
	"Gus": "Fermín",
	# S26 (owner, 2026-10-25): the time demons take Maya day signs
	# (tzolk'in), in the order they are fought; Demonio III keeps his.
	"El demonio del minuto 58": "Imix",
	"el demonio del minuto 58": "Imix",
	"al demonio del minuto 58": "a Imix",
	"del demonio del minuto 58": "de Imix",
	"Demonio del minuto 58": "Imix",
	"demonio del minuto 58": "Imix",
	"The Demon of the 58th Minute": "Imix",
	"The Demon of the 58th minute": "Imix",
	"the Demon of the 58th Minute": "Imix",
	"the Demon of the 58th minute": "Imix",
	"Demon of the 58th Minute": "Imix",
	"Demon of the 58th minute": "Imix",
	"demon of the 58th Minute": "Imix",
	"demon of the 58th minute": "Imix",
	"The 58th minute demon": "Imix",
	"the 58th minute demon": "Imix",
	"58th minute demon": "Imix",
	"Le démon de la 58ème minute": "Imix",
	"le démon de la 58ème minute": "Imix",
	"du démon de la 58ème minute": "de Imix",
	"Démon de la 58ème minute": "Imix",
	"démon de la 58ème minute": "Imix",
	"Démon  de la 58ème minute": "Imix",
	"El demonio del minuto 52": "Ik'",
	"el demonio del minuto 52": "Ik'",
	"al demonio del minuto 52": "a Ik'",
	"del demonio del minuto 52": "de Ik'",
	"Demonio del minuto 52": "Ik'",
	"demonio del minuto 52": "Ik'",
	"The Demon of the 52nd Minute": "Ik'",
	"The Demon of the 52nd minute": "Ik'",
	"the Demon of the 52nd Minute": "Ik'",
	"the Demon of the 52nd minute": "Ik'",
	"Demon of the 52nd Minute": "Ik'",
	"Demon of the 52nd minute": "Ik'",
	"demon of the 52nd Minute": "Ik'",
	"demon of the 52nd minute": "Ik'",
	"The 52nd minute demon": "Ik'",
	"the 52nd minute demon": "Ik'",
	"52nd minute demon": "Ik'",
	"Le démon de la 52ème minute": "Ik'",
	"le démon de la 52ème minute": "Ik'",
	"du démon de la 52ème minute": "de Ik'",
	"Démon de la 52ème minute": "Ik'",
	"démon de la 52ème minute": "Ik'",
	"Démon  de la 52ème minute": "Ik'",
	"El demonio del minuto 46": "Ak'bal",
	"el demonio del minuto 46": "Ak'bal",
	"al demonio del minuto 46": "a Ak'bal",
	"del demonio del minuto 46": "de Ak'bal",
	"Demonio del minuto 46": "Ak'bal",
	"demonio del minuto 46": "Ak'bal",
	"The Demon of the 46th Minute": "Ak'bal",
	"The Demon of the 46th minute": "Ak'bal",
	"the Demon of the 46th Minute": "Ak'bal",
	"the Demon of the 46th minute": "Ak'bal",
	"Demon of the 46th Minute": "Ak'bal",
	"Demon of the 46th minute": "Ak'bal",
	"demon of the 46th Minute": "Ak'bal",
	"demon of the 46th minute": "Ak'bal",
	"The 46th minute demon": "Ak'bal",
	"the 46th minute demon": "Ak'bal",
	"46th minute demon": "Ak'bal",
	"Le démon de la 46ème minute": "Ak'bal",
	"le démon de la 46ème minute": "Ak'bal",
	"du démon de la 46ème minute": "de Ak'bal",
	"Démon de la 46ème minute": "Ak'bal",
	"démon de la 46ème minute": "Ak'bal",
	"Démon  de la 46ème minute": "Ak'bal",
	"El demonio del minuto 25": "K'an",
	"el demonio del minuto 25": "K'an",
	"al demonio del minuto 25": "a K'an",
	"del demonio del minuto 25": "de K'an",
	"Demonio del minuto 25": "K'an",
	"demonio del minuto 25": "K'an",
	"The Demon of the 25th Minute": "K'an",
	"The Demon of the 25th minute": "K'an",
	"the Demon of the 25th Minute": "K'an",
	"the Demon of the 25th minute": "K'an",
	"Demon of the 25th Minute": "K'an",
	"Demon of the 25th minute": "K'an",
	"demon of the 25th Minute": "K'an",
	"demon of the 25th minute": "K'an",
	"The 25th minute demon": "K'an",
	"the 25th minute demon": "K'an",
	"25th minute demon": "K'an",
	"Le démon de la 25ème minute": "K'an",
	"le démon de la 25ème minute": "K'an",
	"du démon de la 25ème minute": "de K'an",
	"Démon de la 25ème minute": "K'an",
	"démon de la 25ème minute": "K'an",
	"Démon  de la 25ème minute": "K'an",
	"El demonio del minuto 12": "Chikchan",
	"el demonio del minuto 12": "Chikchan",
	"al demonio del minuto 12": "a Chikchan",
	"del demonio del minuto 12": "de Chikchan",
	"Demonio del minuto 12": "Chikchan",
	"demonio del minuto 12": "Chikchan",
	"The Demon of the 12th Minute": "Chikchan",
	"The Demon of the 12th minute": "Chikchan",
	"the Demon of the 12th Minute": "Chikchan",
	"the Demon of the 12th minute": "Chikchan",
	"Demon of the 12th Minute": "Chikchan",
	"Demon of the 12th minute": "Chikchan",
	"demon of the 12th Minute": "Chikchan",
	"demon of the 12th minute": "Chikchan",
	"The 12th minute demon": "Chikchan",
	"the 12th minute demon": "Chikchan",
	"12th minute demon": "Chikchan",
	"Le démon de la 12ème minute": "Chikchan",
	"le démon de la 12ème minute": "Chikchan",
	"du démon de la 12ème minute": "de Chikchan",
	"Démon de la 12ème minute": "Chikchan",
	"démon de la 12ème minute": "Chikchan",
	"Démon  de la 12ème minute": "Chikchan",
	"the 1st Minute Demon": "Imix",
	"1st Minute Demon": "Imix",
	"Démon du défi des minutes 1": "Imix",
	"démon du défi des minutes 1": "Imix",
	"the 2nd Minute Demon": "Ik'",
	"2nd Minute Demon": "Ik'",
	"Démon du défi des minutes 2": "Ik'",
	"démon du défi des minutes 2": "Ik'",
	"the 3rd Minute Demon": "Ak'bal",
	"3rd Minute Demon": "Ak'bal",
	"Démon du défi des minutes 3": "Ak'bal",
	"démon du défi des minutes 3": "Ak'bal",
	"the 4th Minute Demon": "K'an",
	"4th Minute Demon": "K'an",
	"Démon du défi des minutes 4": "K'an",
	"démon du défi des minutes 4": "K'an",
	"the 5th Minute Demon": "Chikchan",
	"5th Minute Demon": "Chikchan",
	"Démon du défi des minutes 5": "Chikchan",
	"démon du défi des minutes 5": "Chikchan",
	"demonio del minuto 3": "Ak'bal",
	"Démon des Minutes 3": "Ak'bal",
	"El demonio del segundo 37": "Kimi",
	"el demonio del segundo 37": "Kimi",
	"Demonio del segundo 37": "Kimi",
	"demonio del segundo 37": "Kimi",
	"Demon of the 37th Second": "Kimi",
	"Démon de la 37ème seconde": "Kimi",
	"démon de la 37ème seconde": "Kimi",
	"demonios de los minutos": "Señores del Tiempo",
	"Demonios de los minutos": "Señores del Tiempo",
	"Demons of the Minutes": "Lords of Time",
	"demons of the minutes": "Lords of Time",
	"Minute Demons": "Lords of Time",
	"minute demons": "Lords of Time",
	"Minute Demon": "Lord of Time",
	"minute demon": "Lord of Time",
	"Demon of Minutes": "Lord of Time",
	"Démons des Minutes": "Seigneurs du Temps",
	"démons des minutes": "Seigneurs du Temps",
	"démon des minutes": "Seigneur du Temps",
	"Primer desafío de los minutos": "Desafío de Imix",
	"Segundo desafío de los minutos": "Desafío de Ik'",
	"Tercer desafío de los minutos": "Desafío de Ak'bal",
	"Cuarto desafío de los minutos": "Desafío de K'an",
	"Último desafío de los minutos": "Desafío de Chikchan",
	"First Minutes Challenge": "Imix's Challenge",
	"Second Time Challenge": "Ik's Challenge",
	"Third Minutes Challenge": "Ak'bal's Challenge",
	"Fourth Minutes Challenge": "K'an's Challenge",
	"Last Time Challenge": "Chikchan's Challenge",
	"Premier Défi des minutes": "Défi d'Imix",
	"Deuxième Défi des minutes": "Défi d'Ik'",
	"Troisième Défi des minutes": "Défi d'Ak'bal",
	"Quatrième Défi des minutes": "Défi de K'an",
	"Dernier Défi des minutes": "Défi de Chikchan",
	"1er demonio del desafío de los minutos": "Imix",
	"2º demonio del desafío de los minutos": "Ik'",
	"3er demonio del desafío de los minutos": "Ak'bal",
	"4º demonio del desafío de los minutos": "K'an",
	"5º demonio del desafío de los minutos": "Chikchan",
	"du démon de la 12e minute": "de Chikchan",
	"démon de la 12e minute": "Chikchan",
}

static var _re: RegEx


static func name_for(id: int, fallback: String) -> String:
	return NAMES.get(id, fallback)


## `text` with every retail name of OLD replaced by ours (whole words).
static func apply(text: String) -> String:
	if text.is_empty():
		return text
	if _re == null:
		var keys: Array = OLD.keys()
		keys.sort_custom(func(a, b): return a.length() > b.length())
		var alts := PackedStringArray()
		for k in keys:
			alts.append(_escape(k))
		_re = RegEx.create_from_string("(?<![\\p{L}\\p{N}])(" + "|".join(alts) + ")(?![\\p{L}\\p{N}])")
	var out := ""
	var at := 0
	for m in _re.search_all(text):
		out += text.substr(at, m.get_start() - at) + str(OLD[m.get_string(1)])
		at = m.get_end()
	return out + text.substr(at)


static func _escape(s: String) -> String:
	var out := ""
	for c in s:
		out += ("\\" + c) if c in ".^$*+?()[]{}|\\" else c
	return out
