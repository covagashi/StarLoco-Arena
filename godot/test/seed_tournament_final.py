#!/usr/bin/env python3
# S49: seeds a COPY of arena.db for test/tournament_fight_smoke.gd: an Evolution
# cup "Copa Final" whose search is open, test (1) and test2 (2) entered, and
# legal Historia teams (5000-6000) for both.
#   python3 godot/test/seed_tournament_final.py <copy of arena.db>
import sqlite3, sys, datetime as dt
c = sqlite3.connect(sys.argv[1]); now = dt.datetime.now(dt.timezone.utc)
f = lambda t: t.strftime('%Y-%m-%d %H:%M:%S+00:00')
cur = c.execute("""insert into tournaments(def_id,name,short,description,organizer,enabled,
    registration_open,position,search_period_start,search_period_minutes,search_periods,
    period_interval_minutes,repeat_days,finished_at,winner_coach_id,previous_id,creator_coach_id,
    created_at,updated_at) values(12,'Copa Final','Copa Final','final sembrada','StarLoco',1,1,5,?,60,1,0,0,NULL,0,0,0,?,?)""",
    (f(now - dt.timedelta(minutes=5)), f(now), f(now)))
t = cur.lastrowid
for coach in (1, 2):
    c.execute("""insert into tournament_registrations(coach_id,tournament_wire_id,prize_awarded,points,
        unfinished,carry_offered,carried,created_at) values(?,?,0,0,0,0,0,?)""", (coach, 2600000 + t, f(now)))
c.commit(); print('seeded Copa Final', 2600000 + t)
# legal Historia teams (5000-6000): test's three starters and three new ones for test2
c.execute("update fighters set budget=1700 where coach_id=1 and evolution=1 and state=0")
for i, b in enumerate((8, 9, 1)):
    c.execute("""insert into fighters(coach_id,breed_id,name,hair,skin,eye,sex,budget,evolution,state,xp,total_xp,
        sphere_x,sphere_y,tiredness,morale) values(2,?,?,0,0,0,0,1700,1,0,0,0,0,0,0,50)""", (b, 'Final%d' % i))
c.commit(); print('seeded Historia teams')
