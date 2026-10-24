extends RefCounted

## Fixes to the retail NPC dialog data (S20, 2026-10-24). Nilo's tree has
## groups left in French inside the Spanish table, and more of them in the
## English one (the retail never translated them), plus one reply that led to
## the wrong group. NpcDialogs.group() lays these over the data, per UI
## language. The owner may rewrite any of them: S23 is where they get adapted
## to the lobby (no islands, zaaps or ogrines).
##
## Shape: locale -> group id -> {"text"?: String, "labels"?: {reply index:
## label}, "next"?: {reply index: group id}}. Texts keep the data's own
## markup: <b>…</b> and a literal backslash-n for a line break.
##
## Group 80 dropped one line on purpose: "the most common way is the
## boufteurs (card packs) you buy on the website with ogrines" — retail
## sold cards for money, this game does not (S21: no pay-to-win).

const FIX := {
	"es": {
		# "Gracias. Quizás vuelva más tarde." (reply 4) led to group 69, the
		# orientation lesson, which no question reached: it becomes that
		# question; reply 11 already says goodbye.
		8: {"labels": {4: "¿Importa hacia dónde mira mi luchador?",
				9: "También he oído hablar del \"placaje\". ¿Qué es?"}},
		17: {"labels": {1: "Gracias. Quizás vuelva más tarde."}},
		69: {"text": "Sí: no olvides <b>orientar</b> bien a tus luchadores después de cada <b>movimiento y ataque</b>, para no quedar en desventaja.\\nPero también puedes <b>aprovechar</b> cómo se colocan tus adversarios.\\n\\nUn ataque por la espalda hace un <b>40 %</b> más de daño.\\nY uno de lado, un <b>20 %</b> más, así que no dudes en ser <b>traicionero</b>.\\n\\nEso sí, los daños de zona y los neutros no reciben esta bonificación."},
		74: {"text": "Es un tema amplio.\\n¿Qué quieres saber exactamente?",
			"labels": {0: "¿Para qué me sirven las cartas?",
				1: "¿Las cartas sirven de dinero? ¿Como una tarjeta del banco?",
				2: "Pero ¿también son equipamiento?"}},
		75: {"text": "Hay cuatro rarezas de carta, cada una con su color:\\n\\n- <b>Negro</b>, las cartas más corrientes.\\n- <b>Cobre</b>, las comunes.\\n- <b>Plata</b>, las raras.\\n- <b>Oro</b>, las ultrarraras."},
		76: {"text": "Aquí luchas contra otros <b>jugadores</b>.\\n\\nAsí que no te extrañe <b>perder</b> tus primeros combates mientras le coges el truco.\\n¡Pero la victoria sabrá mucho mejor!"},
		77: {"text": "Las cartas son <b>todo lo que posees</b> en el juego.\\n\\nSon tu <b>equipamiento, las habilidades de tus luchadores, tu dinero</b>, etc."},
		78: {"text": "Exacto: cada carta tiene un <b>valor</b> y sirve de moneda.\\nAsí que coleccionar cartas te hace más rico.\\n\\n<b>Hoy en día es mucho más fácil pagar con carta, ¿no crees?</b>"},
		79: {"text": "¡No todas, hombre!\\n\\nAlgunas cartas son <b>piezas de armadura</b> y puedes equipártelas como tales.\\nPiensa que una carta solo es un <b>soporte</b> para llevar mejor la cuenta de lo que tienes. ¡No te pones la carta, claro!\\n\\nEso sí, <b>cuidado</b> con el <b>nivel</b> de la carta: si te pones una pieza que pide nivel 15 y tú eres nivel 10, <b>no recibes</b> sus bonificaciones.\\nAunque puedes llevarla igualmente."},
		80: {"text": "Hay <b>muchas</b> formas de conseguir cartas.\\n\\n- En Evolución, cada vez que <b>ganas</b> un combate tienes una posibilidad de ganar una carta de tu nivel.\\n- Puedes <b>intercambiar</b> con otros jugadores para ampliar tu colección.\\n- Algunos <b>desafíos</b> dan cartas.\\n- Algunas cartas raras se <b>compran</b> a un Card Master.\\n- Los <b>altares de fusión</b> te permiten crear cartas que quizá otros jugadores no conozcan.\\n- Y, por último, los <b>torneos</b> dan cartas exclusivas.",
			"labels": {1: "¡Me apetece ir a la aventura, gracias!"}},
		83: {"text": "El placaje es una habilidad que <b>tiene cada luchador</b>: le da la posibilidad de <b>bloquear el movimiento</b> de un adversario que pase a su lado y hacerle <b>perder el turno</b>.\\n\\nDepende de dos características de los luchadores: <b>la esquiva y el bloqueo</b>.\\nLa esquiva <b>reduce</b> tus posibilidades de que un adversario te bloquee.\\nEl bloqueo te da <b>más</b> posibilidades de bloquearlo tú.\\n\\nPara saber qué posibilidades tienes de esquivar un placaje en una casilla, <b>pon</b> el cursor en la casilla de delante del luchador que se va a mover: verás un número."},
		84: {"labels": {1: "Gracias por todo, ¡hasta pronto!"}},
	},
	"en": {
		8: {"labels": {4: "Does it matter which way my fighter faces?",
				8: "Tell me what's special about my coach's grimoire! (inventory)",
				9: "I've also heard about \"tackling\". What's that?",
				10: "Tell me about the cards.",
				11: "Thanks, I might come back and see you later."}},
		66: {"labels": {0: "Thanks, I have some more questions.", 1: "I'll come back later."}},
		69: {"text": "Yes: don't forget to <b>turn</b> your fighters the right way after every <b>move and attack</b>, so you aren't caught at a disadvantage.\\nBut you can also <b>take advantage</b> of how your opponents are standing.\\n\\nAn attack from behind deals <b>40%</b> extra damage.\\nAn attack from the side, <b>20%</b> extra, so don't be afraid to be <b>sneaky</b>.\\n\\nArea and neutral damage don't get this bonus, though.",
			"labels": {0: "Thanks, I have some more questions.", 1: "Thanks, I might come back and see you later."}},
		74: {"text": "That's a big subject.\\nWhat exactly do you want to know?",
			"labels": {0: "What are cards for?", 1: "Are cards money? Like a bank card?",
				2: "But they're equipment too?", 3: "How do I get cards?",
				4: "Shall we talk about something else?",
				5: "You mentioned Card Masters earlier. Can you tell me more?",
				6: "What are the different card rarities?",
				7: "Thanks, no more questions. See you soon!",
				8: "Let's go back to the fusion altars, I need it explained."}},
		75: {"text": "There are four card rarities, each with its own colour:\\n\\n- <b>Black</b>, the most ordinary cards.\\n- <b>Copper</b>, common cards.\\n- <b>Silver</b>, rare cards.\\n- <b>Gold</b>, ultra-rare cards.",
			"labels": {0: "Thanks, I have some more questions.", 1: "I'll come back and see you later."}},
		76: {"text": "Here you fight other <b>players</b>!\\n\\nSo don't be surprised if you <b>lose</b> your first matches while you get the hang of it.\\nBut that will make victory all the sweeter!",
			"labels": {0: "Thanks, I have some more questions.", 1: "I'll come back later."}},
		77: {"text": "Cards are <b>everything you own</b> in the game.\\n\\nThey are your <b>equipment, your fighters' skills, your money</b>, and so on.",
			"labels": {0: "I still have a few questions!", 1: "That's all for now, thanks."}},
		78: {"text": "That's right: every card has a <b>value</b> and works as currency.\\nSo collecting cards makes you richer.\\n\\n<b>Paying by card is so much easier these days, you know.</b>",
			"labels": {0: "I need a few more details.", 1: "That's all, thanks!"}},
		79: {"text": "Not all of them, silly!\\n\\nSome cards are <b>pieces of armour</b>, and you can equip them as such.\\nThink of a card as just a <b>holder</b> that helps you keep track of what you own. You don't wear the card itself, obviously!\\n\\nBut <b>watch</b> the card's <b>level</b>! If you put on a piece that needs level 15 and you are level 10, you <b>don't get</b> its bonuses.\\nYou can still wear it, though.",
			"labels": {0: "I see, but I still have a few questions.", 1: "I can't wait to try all this, thanks!"}},
		80: {"text": "There are <b>lots</b> of ways to get cards.\\n\\n- In Evolution, every time you <b>win</b> a fight you have a chance to win a card for your level.\\n- You can <b>trade</b> with other players to grow your collection.\\n- Some <b>challenges</b> give cards.\\n- Some rare cards are <b>bought</b> from a Card Master.\\n- The <b>fusion altars</b> let you create cards other players may never have seen.\\n- And finally, <b>tournaments</b> give exclusive cards.",
			"labels": {0: "That's a lot, I need some details.", 1: "I feel like going on an adventure, thanks!"}},
		81: {"text": "Card Masters are card <b>sellers</b>, in a way. You'll find them all around the Horamundo.\\n\\nEach one offers cards that are more or less powerful, and some Card Masters are much <b>sought after</b> by coaches because of it.\\n\\nAs I told you, to buy a card you <b>give</b> other cards that act as money: their total value has to be enough to pay for the card you want.",
			"labels": {0: "Thanks, I need to know a few more little things.", 1: "Thanks, goodbye."}},
		82: {"text": "I'll explain it all in detail!\\n\\nA fusion altar lets you <b>get</b> a card by <b>sacrificing</b> other cards, following a recipe that is set in advance and often <b>unknown</b>!\\nSo you'll have to <b>experiment</b> to find the right recipes.\\n\\nEach fusion altar is <b>different</b>, and more or less <b>powerful</b>.\\nA very powerful altar, fully boosted, can even reach a <b>100%</b> success rate!\\n\\nBut the success rate of a fusion depends on many things, and I'll explain how they work.\\n\\nThere are <b>fusion cards</b>, made specially to <b>boost</b> altars.\\nSo if you want to fuse very high-level cards, you need not only an <b>extremely powerful</b> altar but also a fusion card to <b>boost</b> your chances!\\n\\nWhat you need to remember is that the more powerful the fusion, the harder it is to pull off, so put every chance on your side!\\n\\nThat said, if a fusion fails, don't lose hope: depending on the altar's power, you may get some of the cards back.\\n\\nAnd don't forget that the most powerful cards can only be obtained this way. Who knows, you may come across a unique card nobody has ever seen.",
			"labels": {0: "That's a lot to take in, but I want more!", 1: "My head's going to explode, that's all for now."}},
		83: {"text": "Tackling is a skill <b>every fighter has</b>: it gives a chance to <b>block the movement</b> of an opponent who walks past you and make them <b>lose their turn</b>.\\n\\nTackling depends on two fighter characteristics, <b>dodge and block</b>!\\nDodge <b>lowers</b> your chances of being blocked by an opponent.\\nBlock gives you <b>more</b> chances to block them.\\n\\nTo see your chances of dodging a tackle on a cell, <b>put</b> the cursor on the cell in front of the fighter who is about to move: a number will show.",
			"labels": {0: "Good to know, thanks. I have more questions.", 1: "That's all this time, thanks!"}},
		84: {"text": "The card <b>grimoire</b> lets you easily <b>browse</b> your cards and see which ones you're missing.\\nIt also lets you manage your coach's <b>equipment</b>!\\n\\nAnd there's more: it holds an <b>encyclopaedia</b> of every class and its spells, every summon, and every action card you can use in a fight!\\n\\nIn other words, it's <b>essential</b>!",
			"labels": {0: "I still have a few little questions!", 1: "Thanks for everything, see you soon!"}},
	},
}

## `g` (a group node, already in the UI language) with this locale's fixes.
static func apply(locale: String, id: int, g: Dictionary) -> Dictionary:
	var fix: Dictionary = FIX.get(locale, {}).get(id, {})
	if fix.is_empty() or g.is_empty():
		return g
	var out: Dictionary = g.duplicate(true)
	if fix.has("text"):
		out["text"] = fix.text
	var replies: Array = out.get("replies", [])
	for i in fix.get("labels", {}):
		if int(i) < replies.size():
			replies[int(i)]["label"] = fix.labels[i]
	for i in fix.get("next", {}):
		if int(i) < replies.size():
			replies[int(i)]["next"] = int(fix.next[i])
	return out
