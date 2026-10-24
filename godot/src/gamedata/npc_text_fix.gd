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
		# S23: no website card packs, no islands, no gostofos, no zaaps
		11: {"text": "Tu posición en la <b>clasificación</b> y tu colección de <b>cartas</b> serán tus objetivos principales.\n\nPara subir en las clasificaciones del Horamundo, encadena victorias en la arena contra otros jugadores y demuestra que eres el más fuerte.\n\nGanar combates también te dará <b>cartas</b> para tu grimorio. Además puedes conseguirlas en los <b>Card Masters</b> y en los <b>altares de fusión</b> (Servicios).\n\nDe momento, empieza por la <b>Historia</b> y ve acumulando victorias."},
		12: {"text": "En el Horamundo hay tres formas de combatir.\n\nLa <b>Historia</b> es tu campaña: tus luchadores crecen combate a combate, pero se cansan, se hieren y pueden morir.\n\nEl <b>Ranking</b> iguala a todos los contrincantes y pide conocer bien el juego, así que no empieces por él. Si no hay rival en vivo, puedes pelear contra el fantasma de un jugador.\n\nLos <b>torneos</b> tienen sus propias reglas y dan fichas y <b>cartas</b> exclusivas."},
		44: {"text": "Ve a ver al demonio I cuando hayas superado los desafíos del demonio III (Historia). Él podrá enseñarte tácticas útiles para tus próximos combates."},
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
		11: {"text": "Your place in the <b>rankings</b> and your <b>card</b> collection are your two main objectives!\n\nTo climb the league tables of the Horamundo, win one fight after another in the arena against other players and prove you are the strongest.\n\nWinning matches also gives you <b>cards</b> for your grimoire. You can get more from the <b>Card Masters</b> and the <b>fusion altars</b> (Services).\n\nFor now, start with the <b>Story</b> and rack up some wins."},
		12: {"text": "There are three ways to fight in the Horamundo.\n\nThe <b>Story</b> is your campaign: your fighters grow fight by fight, but they get tired, get hurt and can die.\n\n<b>Ranked</b> puts everyone on an equal footing and needs a good understanding of the game, so don't start there. If nobody is online, you can fight a player's ghost.\n\n<b>Tournaments</b> have their own rules and give tokens and exclusive <b>cards</b>."},
		44: {"text": "Go and see Demon I once you have passed the Demon III's challenges (Story). He should be able to teach you a few techniques that might prove useful in combat."},
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


## S23: the content.29 texts (scenario pages, demon speeches) that talk about
## what the lobby no longer has — islands, zaaps, the map (M), F4, Maknala —
## or carry a typo. locale -> text id -> the whole text.
const NAMES := {
	"es": {
		147: "Hemos llegado al Horamundo y créeme, no es el lugar más acogedor que conozco.",
		153: "Si quieres salir de aquí, debes superar los 3 desafíos que voy a proponerte. A menos que prefieras quedarte hasta el final de tus días, tú decides...\nPero antes, debes reclutar a tres guerreros. Si no hay guerreros, no hay desafíos, ¿de acuerdo? ¿Te ha quedado claro en tu cabeza de chorlito?",
		167: "Bueno, ve a ver a los maestros de clase, ellos te ayudarán: los encontrarás en Servicios → Aprendizaje.\nSi eres muy perezoso, también puedes reclutar a tus guerreros desde Equipo → Historia → Crear luchador.",
		196: "El demonio III pone a prueba a los jefes como tú. Si superas sus desafíos, te esperan los demonios de los minutos y, después, los grandes torneos.",
		218: "Pero ya veremos eso más adelante. ¡Sigamos adelante!",
		243: "Cada vez que quieras un combate del gran torneo, ve a la tarjeta Torneos del lobby. ¡Puedes hacerlo cuando quieras!",
		250: "Hablaremos de ello más tarde. Cuando te sientas preparado, podrás lanzar un combate en el gran torneo.",
		253: "Si consigues vencer a los cinco demonios de los minutos (Historia, capítulo 2), podrás irte con el pase al gran torneo en tus manos.",
		255: "Mmm... bueno, has demostrado que eres digno de participar en el gran torneo. ¡Te daré el pase enseguida! Ya puedes inscribirte en los torneos del Calendario.",
		268: "¿Qué, qué? ¿Realmente crees que puedes vencerme? El demonio I debe estar falto de guerreros para enviarme a mequetrefes como tú... Adelante, ¡muéstrame lo que sabes hacer!",
		269: "¿Qué, qué? ¿Realmente crees que puedes vencerme? El demonio I debe estar falto de guerreros para enviarme a mequetrefes como tú... Adelante, ¡muéstrame lo que sabes hacer!",
		270: "¿Qué, qué? ¿Realmente crees que puedes vencerme? El demonio I debe estar falto de guerreros para enviarme a mequetrefes como tú... Adelante, ¡muéstrame lo que sabes hacer!",
		271: "¿Que qué? ¿Realmente crees que puedes vencerme? El demonio I debe estar falto de guerreros para enviarme a mequetrefes como tú... Adelante, ¡muéstrame lo que sabes hacer!",
		273: "¡Bien hecho, pequeñín! Pareces listo para enfrentarte a los adversarios más tenaces: los demonios de los minutos te esperan (Historia, capítulo 2).\n¡Hasta pronto! Pasa a verme cuando quieras, tendré otros desafíos que proponerte.",
		274: "No eres digno de enfrentarte a mí. Vence antes a los otros cuatro demonios de los minutos. Si regresas, me dignaré a concederte un duelo.",
	},
	"en": {
		153: "If you want to get out of here, you're going to have to complete the 3 challenges I'm about to set you. Unless you'd rather be stuck here for the rest of your life, it's up to you...\nBut before that, you're going to have to recruit three fighters. No fighters, no challenges, understood? Have you got that through your thick skull?",
		167: "Ok, go and see the class masters, they'll help you: you'll find them in Services → Learning.\nIf you're too lazy, you can always hire fighters from Team → Story → Create fighter.",
		196: "Demon III sets tests for coaches like you. Pass them and the minute demons await you, then the great tournaments.",
		218: "But we'll find out more about that later. Let's move on!",
		243: "Each time you want a great tournament match, go to the Tournaments card in the lobby. You can do it whenever you like!",
		250: "We'll talk about it again later. When you feel ready, you can launch a fight in the great tournament.",
		253: "If you manage to beat the five minute demons (Story, chapter 2), you will leave with a pass to the great tournament!",
		255: "Hmm... ok. You've proved yourself worthy of the great tournament. I'll let you in right away! You can now sign up for the tournaments in the Calendar.",
		273: "Well done, kid! I think you're ready for some tougher opponents now: the minute demons are waiting for you (Story, chapter 2).\nBye, then! Come and see me whenever you like, I'll have some more challenges for you.",
		274: "You're not worthy of confronting me. Defeat the other four minute demons first. If you manage it, I might agree to duel with you.",
	},
}


## A content.29 text with this locale's fix, if any.
static func name_text(locale: String, id: int, text: String) -> String:
	return str(NAMES.get(locale, {}).get(id, text))
