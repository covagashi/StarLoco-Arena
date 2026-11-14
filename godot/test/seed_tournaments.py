#!/usr/bin/env python3
"""S09 block E (moved here from the devlog, 2026-11-14): seeds a COPY of
arena.db for test/tournaments_smoke.gd. Stop the server, copy arena.db (and a
config.yaml pointing at it) into a folder, run this on the folder, start the
server there. Coach "test" = id 1. Leaves the real base alone.
    python3 godot/test/seed_tournaments.py <folder with the copied arena.db>
"""
import sqlite3, sys, datetime as dt
sp = sys.argv[1]
c = sqlite3.connect(sp + '/arena.db')
UTC = dt.timezone.utc
now = dt.datetime.now(UTC)
f = lambda t: t.strftime('%Y-%m-%d %H:%M:%S+00:00')
BASE = 2600000
# S29: classic tournaments are played offline, AI against AI, the moment
# registration closes (tournament_offline.go), so a classic cup whose search
# is open is already over; the cups the smoke watches live are Evolution ones
# (def 12, tournament_defs.gd), which stay live
EVOLUTION = 12

def tourn(name, start, minutes, periods, interval, repeat=0, finished=None, prev=0, pos=5, def_id=1):
    cur = c.execute("""insert into tournaments(def_id,name,short,description,organizer,enabled,
        registration_open,position,search_period_start,search_period_minutes,search_periods,
        period_interval_minutes,repeat_days,finished_at,winner_coach_id,previous_id,creator_coach_id,
        created_at,updated_at) values(?,?,?,?, 'StarLoco',1,1,?,?,?,?,?,?,?,0,?,0,?,?)""",
        (def_id, name, name, 'Torneo sembrado para el smoke de S09', pos, f(start), minutes, periods,
         interval, repeat, f(finished) if finished else None, prev, f(now), f(now)))
    return cur.lastrowid

def reg(coach, tid_row, unfinished=0):
    c.execute("""insert into tournament_registrations(coach_id,tournament_wire_id,prize_awarded,
        points,unfinished,carry_offered,carried,created_at) values(?,?,0,0,?,0,0,?)""",
        (coach, BASE + tid_row, unfinished, f(now)))

# 1. carry-over: a finished repeating edition left coach 1 unfinished
old = tourn('Copa Smoke', now - dt.timedelta(days=1), 60, 1, 0, repeat=2,
            finished=now - dt.timedelta(hours=1))
reg(1, old, unfinished=1)
tourn('Copa Smoke II', now + dt.timedelta(days=1), 60, 1, 0, repeat=2, prev=old)
# 2-3. a tournament whose search is open now, coaches 1 and 2 entered
opn = tourn('Copa Smoke Abierta', now - dt.timedelta(minutes=5), 60, 2, 1440, def_id=EVOLUTION)
reg(1, opn); reg(2, opn)
# 4. a period that opens during the session
late = tourn('Copa Smoke Tarde', now + dt.timedelta(seconds=70), 10, 1, 0, def_id=EVOLUTION)
reg(1, late); reg(2, late)
# 5. one "Création de Tournoi" card for coach 1
c.execute("insert into coach_cards(coach_id,template_id,quantity,pos) values(1,807,1,0)")
c.commit()
print('seeded; late cup opens at', f(now + dt.timedelta(seconds=70)))
