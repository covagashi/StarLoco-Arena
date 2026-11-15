package gamedata

// tournaments.go decodes record types 1000 and 1001 — the tournament
// definitions (client `aub`, enum `atr_0.cVd`) and the tournament level list
// (client `ek_2`, enum `atr_0.cVe`).
//
// Layout of 1000, from `aub`'s own `a(ByteBuffer,int,short)` and confirmed
// against its writer `cr()`:
//
//	[i16 id][u8 f1][u8 f2][u8 teamType][i32 f3][i32 f4]
//	[u8 n] np_1 × n                      // the tournament's fight ruleset
//	[i16 f5][i32 inscriptionCard][i32 rewardCard][u8 flag]
//	5 × ( [u8 n] × { [u8 key][i32 value] } )   // five prize maps
//
// Names come from the client's own property strings where it exposes one
// (`qr_0`): `qo()` is "tournamentInscriptionCard" — `aug.registerTournament`
// looks that card up in the player's inventory to let them enter — and `aHi()` is
// "tournamentRewards". `aHh()` is the team type, compared against `aql_0`
// (1 = classique 1v1, 2 = évolution, 3 = cimetière, 4 = légendaire).
//
// Several fields have NO consumer in the client (`aHe`, `aHf`, `aHg`, `aHj`,
// `aHk`). That is expected rather than suspicious: the client only reads what it
// displays, and the rest is server-side configuration. They are decoded and named
// by position so nothing is silently dropped.

// TournamentTeamType mirrors the client's `aql_0`.
const (
	TournamentTeamUnknown   uint8 = 0
	TournamentTeamClassic   uint8 = 1 // "Tournoi avec équipes de type classique 1vs1"
	TournamentTeamEvolution uint8 = 2 // "… de type évolution"
	TournamentTeamGraveyard uint8 = 3 // "… de type cimetière"
	TournamentTeamLegendary uint8 = 4 // "… de type légendaire"
)

// tournamentPrizeTiers is the fixed number of prize maps every definition
// carries (`aub.cVM` is `new aim_1[5]`).
const tournamentPrizeTiers = 5

// TournamentPrize is one prize map: key -> amount. The client never reads these,
// so the key's meaning is not established; it is preserved verbatim.
type TournamentPrize map[uint8]int32

// TournamentDef is one decoded type-1000 record.
type TournamentDef struct {
	ID int16 // `Bw()` — the key the client registers the definition under

	// TeamType is `aHh()`, checked against `aql_0` to pick which UI tab the
	// tournament opens (classic / evolution / graveyard / legendary).
	TeamType uint8

	// InscriptionCard is `qo()` = "tournamentInscriptionCard": the card a coach
	// must hold to register. 0 = no ticket required.
	InscriptionCard int32
	// RewardCard is `aHi()` = "tournamentRewards", shown on the tournament panel.
	RewardCard int32

	// Rules is the tournament's own `np_1` fight ruleset (same element type as a
	// challenge's bonuses).
	Rules []Parameter

	// Prizes are the five prize maps, in record order.
	Prizes [tournamentPrizeTiers]TournamentPrize

	// Fields with no client consumer, kept by position so the record is fully
	// accounted for rather than skipped.
	Unknown1 uint8 // `BE()`
	Unknown2 uint8 // `aHe()`
	Unknown3 int32 // `aHf()`
	Unknown4 int32 // `aHg()`
	Unknown5 int16 // `cB()`
	Flag     bool  // `aHj()`
}

// Tournaments is the decoded type-1000 table plus the type-1001 level list.
type Tournaments struct {
	byID   map[int16]*TournamentDef
	levels []uint8
}

// NewTournaments builds a table from explicit definitions (tests).
func NewTournaments(defs ...*TournamentDef) *Tournaments {
	t := &Tournaments{byID: make(map[int16]*TournamentDef, len(defs))}
	for _, d := range defs {
		if d != nil {
			t.byID[d.ID] = d
		}
	}
	return t
}

// Get returns the definition with this id, or nil.
func (t *Tournaments) Get(id int16) *TournamentDef {
	if t == nil {
		return nil
	}
	return t.byID[id]
}

// Len reports how many definitions decoded.
func (t *Tournaments) Len() int {
	if t == nil {
		return 0
	}
	return len(t.byID)
}

// All returns the id->definition map (read-only use).
func (t *Tournaments) All() map[int16]*TournamentDef {
	if t == nil {
		return nil
	}
	return t.byID
}

// Levels returns the type-1001 level list, in record order.
func (t *Tournaments) Levels() []uint8 {
	if t == nil {
		return nil
	}
	return t.levels
}
