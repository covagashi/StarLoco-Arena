extends RefCounted
## S47 (point 11): every card shows its own kind of object, not the family's
## one icon on hundreds of cards. content/card_art.json (card id → the
## sub-family pictogram in ui/cards/sub/) is written by
## tools/icons/card_art.py from the card's type and Spanish name; rerun
## `python3 tools/icons/card_art.py --sub` after a card is added or renamed.

const CardFace := preload("res://src/ui/card_face.gd")
const Cards := preload("res://src/gamedata/cards.gd")


func run(t) -> void:
	t.suite("card_art")
	var art: Dictionary = AssetPaths.read_json("content/card_art.json", {})
	t.ok(art.size() > 600, "card_art.json maps the cards (%d)" % art.size())
	var missing := []
	var unknown := []
	for cid in art:
		if not AssetPaths.exists("ui/cards/sub/%s.webp" % art[cid]):
			missing.append("%s→%s" % [cid, art[cid]])
		if Cards.meta(int(cid)).is_empty():
			unknown.append(cid)
	t.eq(missing, [], "every sub-family pictogram it names is drawn")
	t.eq(unknown, [], "it names only real cards")
	# every card has its own art: its piece (coach gear; haircuts: the hair
	# pictogram) or a sub-family pictogram — none falls back to the family's
	var bare := []
	for cid in Cards.all_ids():
		var ty := int(Cards.meta(cid).get("type", -1))
		if ty >= 2 and ty <= 13:
			continue
		if not art.has(str(cid)):
			bare.append(cid)
	t.eq(bare, [], "no card outside the coach gear is left on its family's pictogram")
	# art_path picks: the piece first, then the sub-family, then hair, then family
	t.eq(CardFace.art_path(379, false), "ui/cards/sub/pocima_fuego.webp", "Pócima ígnea: the flask with a flame")
	t.eq(CardFace.art_path(491, false), "ui/cards/sub/runa_robusta.webp", "Runa robusta: its rune stone")
	t.eq(CardFace.art_path(105, false), "ui/cards/family/hair.webp", "a haircut keeps the hair pictogram")
	t.eq(CardFace.art_path(1, true), "ui/cards/fighter/1.webp", "fighter gear keeps its piece")
	if AssetPaths.exists("ui/cards/coach/185.webp"):
		t.eq(CardFace.art_path(185, false), "ui/cards/coach/185.webp", "coach gear keeps its piece")
