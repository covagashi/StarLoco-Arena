package game

import (
	"context"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Ladder seasons (S25, owner 2026-10-25): "temporadas, y los que están en el
// top ganan pesetas para comprar cosméticos"; "reinicio suave por temporada".
//
// A season runs to the first day of a calendar month (domain.SeasonBounds).
// When it ends, the scheduler pays the top 50 of each ladder — the 1v1
// Ranking and the ghost ladder — in pesetas (domain.SeasonPrizes), soft-resets
// every rating halfway to its start, and opens the next season. A coach hears
// about its results the next time its client asks (60030 → 60031), right
// away when it is online at the close.

// seasonTick is how often the scheduler looks; a season lasts weeks.
const seasonTick = time.Minute

func (d *Deps) seasonNow() time.Time {
	if d.SeasonClock != nil {
		return d.SeasonClock()
	}
	return time.Now()
}

// RunSeasonScheduler ticks until ctx is done.
func (d *Deps) RunSeasonScheduler(ctx context.Context) {
	t := time.NewTicker(seasonTick)
	defer t.Stop()
	d.TickSeasons()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			d.TickSeasons()
		}
	}
}

// TickSeasons opens the first season, and closes the open one once its end
// has passed (then opens the next). Idempotent: SeasonRepo.Close settles a
// season at most once.
func (d *Deps) TickSeasons() {
	if d.Store == nil || d.Store.Seasons == nil {
		return
	}
	now := d.seasonNow()
	open, err := d.Store.Seasons.Open()
	if err != nil {
		d.Log.Warn("season scheduler: open", "err", err)
		return
	}
	if open != nil && now.Before(open.EndsAt) {
		return
	}
	closed := false
	if open != nil {
		closed = d.closeSeason(open, now)
	}
	last, err := d.Store.Seasons.LastNumber()
	if err != nil {
		d.Log.Warn("season scheduler: last", "err", err)
		return
	}
	start, end := domain.SeasonBounds(now)
	next := &domain.Season{Number: last + 1, StartsAt: start, EndsAt: end}
	if err := d.Store.Seasons.Create(next); err != nil {
		d.Log.Warn("season scheduler: create", "season", next.Number, "err", err)
		return
	}
	d.Log.Info("season opened", "season", next.Number, "ends", end)
	if closed {
		d.tellOnlineSeasonClosed() // after the next one opens, so 60031 names it
	}
}

// closeSeason pays and resets one season; true when this call closed it.
func (d *Deps) closeSeason(s *domain.Season, now time.Time) bool {
	var results []domain.SeasonResult
	for _, ladder := range []uint8{domain.LadderRanked, domain.LadderGhost} {
		top, err := d.seasonTop(ladder)
		if err != nil {
			d.Log.Warn("season close: top", "season", s.Number, "ladder", ladder, "err", err)
			return false
		}
		for i, st := range top {
			rank := int32(i + 1)
			results = append(results, domain.SeasonResult{
				Season: s.Number, Ladder: ladder, CoachID: st.CoachID,
				Rank: rank, Rating: st.Rating, Pesetas: domain.SeasonPrize(rank),
			})
		}
	}
	closed, err := d.Store.Seasons.Close(s.ID, results, now)
	if err != nil {
		d.Log.Warn("season close", "season", s.Number, "err", err)
		return false
	}
	if closed {
		d.Log.Info("season closed", "season", s.Number, "paid", len(results))
	}
	return closed
}

// tellOnlineSeasonClosed brings the online coaches up to date after a close:
// the reset Strength, the new wallet and their results (60031).
func (d *Deps) tellOnlineSeasonClosed() {
	if d.World == nil {
		return
	}
	// The online coaches hold their Strength in memory and write it back on
	// their next fight, so the reset has to reach them too, or it is undone.
	for _, sess := range d.World.SessionsWithout(0) {
		if sess == nil || sess.Coach == nil {
			continue
		}
		sess.Coach.Mu.Lock()
		if sess.Coach.Strength > domain.StrengthMin {
			sess.Coach.Strength = domain.SoftReset(sess.Coach.Strength, domain.StrengthMin)
		}
		sess.Coach.Mu.Unlock()
		if fresh, err := d.Store.Coaches.Get(sess.Coach.ID); err == nil {
			sess.Coach.SetWallet(fresh.Wallet)
			if frame, err := buildWalletUpdate(fresh.Wallet); err == nil {
				_ = sess.Send(frame)
			}
		}
		_ = sess.sendSeason()
	}
}

func (d *Deps) seasonTop(ladder uint8) ([]store.Standing, error) {
	n := domain.SeasonPaidPlaces()
	if ladder == domain.LadderGhost {
		return d.Store.Seasons.GhostTop(n)
	}
	return d.Store.Seasons.RankedTop(n)
}

func registerSeasonHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpSeasonRequest, handleSeasonRequest)
}

// handleSeasonRequest (60030) answers 60031.
func handleSeasonRequest(s *Session, _ *protocol.C2SFrame) error {
	return s.sendSeason()
}

// sendSeason sends 60031: the open season and this coach's unseen results,
// which it then marks seen.
func (s *Session) sendSeason() error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Store.Seasons == nil {
		return nil
	}
	open, err := s.deps.Store.Seasons.Open()
	if err != nil {
		return err
	}
	w := protocol.NewWriter()
	if open == nil {
		w.U16(0).I64(0)
	} else {
		w.U16(uint16(open.Number)).I64(open.EndsAt.Unix())
	}
	results, err := s.deps.Store.Seasons.TakeUnseen(s.Coach.ID)
	if err != nil {
		return err
	}
	if len(results) > 255 {
		results = results[len(results)-255:]
	}
	w.U8(uint8(len(results)))
	for _, r := range results {
		w.U16(uint16(r.Season)).U8(r.Ladder).I32(r.Rank).I32(r.Pesetas)
	}
	frame, err := protocol.EncodeS2C(protocol.OpSeason, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}
