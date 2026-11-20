#!/usr/bin/env bash
## S49: play one smoke on a copy of server/arena.db seeded the way its header
## says, in its own network namespace (unshare -rn: a qemu may hold 5555).
##   godot/tools/seeded_smoke.sh <smoke> ["<smoke args>"]
##   for s in $(ls godot/test/*_smoke.gd); do … done   (S49: all 48 pass)
## args the smokes want: ask2 --as=test2, tutorial --as=novatoNNN,
## tourn_offline --tid=2600004.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
s=$1; tmp=$(mktemp -d); db=$tmp/$s.db; cp server/arena.db $db
# S50: a coach owns 8 fighters (up to 10 earned). The dev base's `test` grew
# to ~80 before that; keep the ones the seeds name (1, 5, 15, 245; 4-10 for
# revive_edge's full bench) so the smokes that recruit have room.
keep="1,2,3,5,15,245"   # two Elite titulars (2, 3) for the ghost smokes
case $s in   # the ones that recruit, up to three at a time
  displace_smoke|colours_smoke|carry_smoke|special_smoke|s47_smoke|summon_smoke) keep="1,5,15,245" ;;
esac
[ "$s" = revive_edge_smoke ] && keep="1,4,5,6,7,8,9,10,15,245"
[ "$s" = slots_smoke ] && keep="1,2,3,4,5,6,15,245"   # every slot taken
python3 -c "import sqlite3,sys;c=sqlite3.connect(sys.argv[1]);c.execute('delete from fighters where coach_id=1 and id not in (%s)' % sys.argv[2]);c.commit()" $db "$keep"
case $s in
revive_smoke) sql="update fighters set state=2 where id=15; update fighters set state=3 where id=1; insert into coach_cards(coach_id,template_id,quantity,pos) values(1,305,2,0);" ;;
revive_edge_smoke) sql="update fighters set state=2 where id=1; update fighters set state=3 where id=15; update fighters set state=1 where id between 4 and 10; insert into coach_cards(coach_id,template_id,quantity,pos) values(1,137,3,0),(1,305,1,0);" ;;
tourn_offline_smoke) sql="update tournaments set search_period_start=strftime('%Y-%m-%d %H:%M:%S+00:00','now','+150 seconds'), registration_open=1, finished_at=NULL, winner_coach_id=0 where id=4; delete from tournament_registrations where tournament_wire_id=2600004; insert into tournament_registrations(coach_id,tournament_wire_id,prize_awarded,created_at,points,unfinished,carry_offered,carried) values(2,2600004,0,strftime('%Y-%m-%d %H:%M:%S+00:00','now'),0,0,0,0);" ;;
screens_smoke) sql="insert into coach_cards(coach_id,template_id,quantity,pos) values(1,131,1,0);" ;;
tournament_fight_smoke) python3 godot/test/seed_tournament_final.py $db; sql="" ;;
totems_smoke) sql="update tournaments set search_period_start=datetime('now','-1 minute'), search_period_minutes=60 where id=1; update guilds set demon_id=0 where id=2; insert into coach_cards(coach_id,template_id,quantity,pos) values(1,128,1,0);" ;;
cardpick_smoke) sql="insert into card_picks(coach_id,wins,picks,offer,drops_since_rare) values(1,0,0,'543,900,861',0);" ;;
tournaments_smoke) cp $db $tmp/arena.db; python3 godot/test/seed_tournaments.py $tmp; db=$tmp/arena.db; sql="" ;;
*) sql="" ;;
esac
[ -n "$sql" ] && python3 -c "import sqlite3,sys;c=sqlite3.connect(sys.argv[1]);c.executescript(sys.argv[2]);c.commit()" $db "$sql"
SMOKES=$s SMOKE_ARGS="${2:-}" SMOKE_GREP='\[audit\] (FAIL|[0-9]+ checks)|SCRIPT ERROR' timeout 900 unshare -rn bash -c "ip link set lo up; godot/tools/no_retail_smoke.sh $db" 2>&1 | grep -v building | grep -E "audit|SCRIPT|OK:|FAIL|s09|seeded"
