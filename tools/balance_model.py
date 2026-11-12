"""Non-spatial model of Brasswick's daily tick, for balance checks.

Mirrors sim/city_sim.gd and sim/city_events.gd in rule order and constants.
The numbers in P and DEFS below are copies: when a constant changes in the
game, change it here too, or the model drifts.

Not modelled: map layout and smog. Assumes every building has road access
and that the player keeps homes out of smog (so smog adds no Unrest and
Glasshouses grow at full rate); the Smog Scrubber is therefore left out.
The city is capped at `map_tiles` of building footprint. Homes are heated
Tenements first, then Townhouses, rather than in placement order.

A scripted player builds once per day. Three kinds are compared:
  naive   pays for every repair; spends freely from day one
  lazy    saves for a first Brassworks; pays for repairs only until the city
          has a Mechanic's Yard, then relies on Yards
  active  saves for a first Brassworks; pays for every repair
In practice naive and active usually come out the same: the saving rule
rarely changes what gets built.
Each can play "classic" (the seven original buildings only) or "modern"
(also Townhouse, Market, Tavern, Airship Dock and Clocktower).
The scripted player is competent, not clever. Read the results as "which
levers matter", not as predicted scores.

Usage (not part of the Godot project; needs only Python 3):
  python tools/balance_model.py              compare variants, 300 games each
                                             (takes several minutes)
  python tools/balance_model.py base 50      same, 50 games each
  python tools/balance_model.py trace 200    print one lazy modern game
  python tools/balance_model.py trace 200 a  the same for an active player
To try a change, add a report(...) line under "base" with the overrides.
"""
import math
import random
import statistics
import sys
from collections import Counter

P = dict(
    start_crowns=600, start_coal=50, start_food=50,
    move_in=2, upkeep=1, repair_cost=20,
    brk_base=0.01, brk_per=0.001, brk_max=0.10,
    u_hunger=20.0, u_cold=10.0, u_idle=5.0, u_broken=2.0, u_broken_max=10.0,
    u_debt=5.0, u_calm=3.0, u_tea=4.0, u_tavern=3.0, u_clock=2.0,
    move_in_below=50.0, leave_above=75.0, leave_share=0.05, walkout_days=3,
    quiet_days=10, min_gap=5, strike_days=5, strike_factor=0.5,
    trader_crowns=100, trader_food=40,
    tavern_food=5, trade_coal=10, trade_crowns=15, trade_reserve=100,
    homes_per_tea=4,      # homes one Tea Garden can cover (layout guess)
    homes_per_tavern=6,   # homes one Tavern can cover (layout guess)
    machines_per_yard=10, # machines one Mechanic's Yard can cover (layout guess)
    road_cost=6,          # road tiles bought with each building, in Crowns
    map_tiles=2000,       # buildable tiles: about half of the 64 x 64 map
    # Rule variants, both off in the game:
    staff_priority=False,   # True: workers go to food, coal, yard, brass in that order
    fuel_food_first=False,  # True: Glasshouses get Coal before other machines
)
DEFS = {  # cost, workers, coal burned, food, coal dug, crowns
    "glasshouse": (80, 4, 1, 20, 0, 0),
    "pit": (100, 6, 0, 0, 12, 0),
    "brassworks": (150, 8, 4, 0, 0, 40),
    "yard": (120, 4, 1, 0, 0, 0),
    "market": (110, 4, 0, 0, 0, 12),
    "tavern": (90, 3, 0, 0, 0, 0),
    "dock": (200, 4, 0, 0, 0, 0),
}
# Buildings that are not workplaces: cost, housing, coal burned.
PLAIN = {"tenement": (50, 10, 1), "townhouse": (140, 20, 2), "tea": (60, 0, 0),
         "clocktower": (500, 0, 0)}
TILES = {"tenement": 4, "townhouse": 4, "tea": 4, "clocktower": 4, "glasshouse": 6, "pit": 9,
         "brassworks": 12, "yard": 4, "market": 6, "tavern": 4, "dock": 9}
BREAKS = {"glasshouse", "pit", "brassworks", "yard"}
PRIORITY = {"glasshouse": 0, "pit": 1, "yard": 2, "brassworks": 3, "market": 4, "tavern": 5, "dock": 6}


class City:
    def __init__(self, p, rng, active_repairs, savvy=True, modern=False):
        self.p, self.rng, self.active, self.savvy, self.modern = p, rng, active_repairs, savvy, modern
        self.crowns, self.coal, self.food = p["start_crowns"], p["start_coal"], p["start_food"]
        self.pop = self.peak = 0
        self.unrest = 0.0
        self.tenements = self.townhouses = self.teas = 0
        self.clock = False
        self.tiles = 0
        self.work = []  # dicts: kind, broken, staff, ran
        self.at_max = 0
        self.strike = 0
        self.last_event = -p["min_gap"]
        self.day = 0
        self.causes = Counter()
        self.food_made = self.coal_net = self.idle = 0

    def count(self, kind):
        return sum(1 for w in self.work if w["kind"] == kind)

    @property
    def homes(self):
        return self.tenements + self.townhouses

    @property
    def capacity(self):
        return self.tenements * PLAIN["tenement"][1] + self.townhouses * PLAIN["townhouse"][1]

    def buy(self, kind):
        cost = (PLAIN[kind][0] if kind in PLAIN else DEFS[kind][0]) + self.p["road_cost"]
        if self.crowns < cost or self.tiles + TILES[kind] > self.p["map_tiles"]:
            return False
        if self.savvy and kind != "brassworks" and self.count("brassworks") == 0 \
                and self.crowns - cost < 156 + 30:
            return False
        self.tiles += TILES[kind]
        self.crowns -= cost
        if kind == "tenement":
            self.tenements += 1
        elif kind == "townhouse":
            self.townhouses += 1
        elif kind == "tea":
            self.teas += 1
        elif kind == "clocktower":
            self.clock = True
        else:
            self.work.append(dict(kind=kind, broken=False, staff=0, ran=False))
        return True

    def run_day(self):
        p = self.p
        self.day += 1
        cap = self.capacity
        pop = min(self.pop, cap)
        if self.unrest > p["leave_above"] and pop > 0:
            pop -= max(1, math.ceil(pop * p["leave_share"]))
        elif self.unrest < p["move_in_below"]:
            pop = min(cap, pop + self.homes * p["move_in"])
        self.pop = pop
        self.peak = max(self.peak, pop)

        total = pop // 2
        avail = total
        order = self.work
        if p["staff_priority"]:
            order = sorted(self.work, key=lambda w: PRIORITY[w["kind"]])
        for w in order:
            w["staff"] = 0
            if not w["broken"]:
                w["staff"] = min(DEFS[w["kind"]][1], avail)
                avail -= w["staff"]
        self.idle = avail

        pool = self.coal
        food_made = crowns_made = broken = stopped = 0
        machines, taverns, docks = [], [], []
        for w in self.work:
            w["ran"] = False
            if w["broken"]:
                broken += 1
                continue
            _, need, burn, f, c, cr = DEFS[w["kind"]]
            share = w["staff"] / need
            if w["kind"] == "tavern":
                taverns.append(w)
            elif w["kind"] == "dock":
                docks.append(w)
            elif burn == 0:
                w["ran"] = share > 0
                pool += round(c * share * (p["strike_factor"] if self.strike else 1.0))
                food_made += round(f * share)
                crowns_made += round(cr * share)
            else:
                machines.append(w)
        if p["fuel_food_first"]:
            machines.sort(key=lambda w: PRIORITY[w["kind"]])
        warm_tenements = min(self.tenements, pool)
        pool -= warm_tenements
        warm_townhouses = min(self.townhouses, pool // PLAIN["townhouse"][2])
        pool -= warm_townhouses * PLAIN["townhouse"][2]
        cold = self.homes - warm_tenements - warm_townhouses
        for w in machines:
            _, need, burn, f, c, cr = DEFS[w["kind"]]
            if pool >= burn:
                pool -= burn
                share = w["staff"] / need
                w["ran"] = share > 0
                food_made += round(f * share)
                crowns_made += round(cr * share)
            else:
                stopped += 1
        for w in docks:
            share = w["staff"] / DEFS["dock"][1]
            w["ran"] = share > 0
            sold = min(round(p["trade_coal"] * share), pool - p["trade_reserve"])
            if sold > 0:
                pool -= sold
                crowns_made += round(sold * p["trade_crowns"] / p["trade_coal"])
        have = self.food + food_made
        hungry = max(0, pop - have)
        food_left = max(0, have - pop)
        open_taverns = 0
        for w in taverns:
            if w["staff"] > 0 and food_left >= p["tavern_food"]:
                food_left -= p["tavern_food"]
                w["ran"] = True
                open_taverns += 1
        upkeep = p["upkeep"] * (self.homes + self.teas + len(self.work) + int(self.clock))
        self.crowns += crowns_made + pop // 2 - upkeep
        self.food = food_left
        self.coal_net = pool - self.coal
        self.coal = pool
        self.food_made = food_made

        def share_of(a, b):
            return min(1.0, a / b) if b > 0 else 0.0
        parts = dict(
            hunger=p["u_hunger"] * share_of(hungry, pop),
            cold=p["u_cold"] * share_of(cold, self.homes),
            idle=p["u_idle"] * share_of(avail, total),
            broken=min(p["u_broken_max"], p["u_broken"] * broken),
            debt=p["u_debt"] if self.crowns < 0 else 0.0,
        )
        relief = p["u_calm"] \
            + p["u_tea"] * share_of(self.teas * p["homes_per_tea"], self.homes) \
            + p["u_tavern"] * share_of(open_taverns * p["homes_per_tavern"], self.homes) \
            + (p["u_clock"] if self.clock else 0.0)
        change = sum(parts.values()) - relief
        for k, v in parts.items():
            self.causes[k] += v
        self.unrest = min(100.0, max(0.0, self.unrest + change))
        self.at_max = self.at_max + 1 if self.unrest >= 100.0 else 0

        breakable = [w for w in self.work if w["kind"] in BREAKS]
        yards = sum(1 for w in self.work if w["kind"] == "yard" and not w["broken"] and w["staff"] > 0)
        cover = share_of(yards * p["machines_per_yard"], len(breakable))
        for w in breakable:
            if w["broken"] and self.rng.random() < cover:
                w["broken"] = False
        chance = min(p["brk_max"], p["brk_base"] + p["brk_per"] * len(breakable))
        for w in breakable:
            if w["ran"] and not w["broken"] and self.rng.random() < chance:
                w["broken"] = True
        if self.at_max >= p["walkout_days"]:
            return False
        self.events()
        return True

    def events(self):
        p = self.p
        if self.strike:
            self.strike -= 1
        if self.day <= p["quiet_days"] or self.day - self.last_event < p["min_gap"]:
            return
        chance = 0.04
        for floor, c in ((1000, 0.18), (500, 0.13), (250, 0.09), (100, 0.06)):
            if self.pop >= floor:
                chance = c
                break
        if self.rng.random() >= chance:
            return
        self.last_event = self.day
        ran = [w for w in self.work if w["ran"] and not w["broken"] and w["kind"] in BREAKS]
        options = ["trader", "storm"] + (["boiler"] if ran else []) + ([] if self.strike else ["strike"])
        kind = self.rng.choice(options)
        if kind == "boiler":
            self.rng.choice(ran)["broken"] = True
        elif kind == "strike":
            self.strike = p["strike_days"]
        elif kind == "trader":
            if self.rng.random() < 0.5:
                self.crowns += p["trader_crowns"]
            else:
                self.food += p["trader_food"]

    def player(self):
        """A sensible but not optimal player, acting once per day."""
        p = self.p
        has_yard = any(w["kind"] == "yard" and not w["broken"] for w in self.work)
        if self.active or not has_yard:
            for w in self.work:
                if w["broken"] and self.crowns >= p["repair_cost"] + 40:
                    self.crowns -= p["repair_cost"]
                    w["broken"] = False
        for _ in range(6):
            growth = self.homes * p["move_in"] if self.pop < self.capacity else 0
            g, pit, bw, yard, market, tavern, dock = (self.count(k) for k in (
                "glasshouse", "pit", "brassworks", "yard", "market", "tavern", "dock"))
            machines = g + pit + bw + yard
            coal_need = self.tenements + 2 * self.townhouses + g + 4 * bw + yard
            food_need = self.pop + growth + p["tavern_food"] * tavern
            if self.homes == 0:
                ok = self.buy("tenement")
            elif g * 20 < food_need and self.food < 3 * max(self.pop, 10):
                ok = self.buy("glasshouse")
            elif pit * 12 < 1.3 * coal_need + 2 and self.coal < 8 * coal_need + 30:
                ok = self.buy("pit")
            elif self.idle >= 6 and (pit * 12 >= 1.3 * (coal_need + 4) or self.coal > 40 and bw == 0):
                ok = self.buy("brassworks")
            elif self.modern and self.idle >= 4 and bw > 0:
                ok = self.buy("market")
            elif machines >= 3 and yard * p["machines_per_yard"] < machines:
                ok = self.buy("yard")
            elif self.teas * p["homes_per_tea"] < self.homes and (self.unrest > 15 or (self.crowns > 400 and self.homes >= 6)):
                ok = self.buy("tea")
            elif self.modern and self.unrest > 15 and self.idle >= 3 \
                    and self.food > 2 * self.pop + 20 and tavern * p["homes_per_tavern"] < self.homes:
                ok = self.buy("tavern")
            elif self.modern and self.idle >= 4 and self.coal > p["trade_reserve"] + 60 and dock < 1 + pit // 3:
                ok = self.buy("dock")
            elif self.modern and not self.clock and self.crowns > 800 and self.homes >= 10:
                ok = self.buy("clocktower")
            elif self.pop >= 0.8 * self.capacity and self.unrest < 40 and self.crowns >= 110:
                ok = self.buy("townhouse" if self.modern and self.crowns >= 300 else "tenement")
            else:
                ok = False
            if not ok:
                break


def play(p, seed, active, days, savvy=True, modern=False):
    city = City(p, random.Random(seed), active, savvy, modern)
    city.player()
    while city.day < days:
        if not city.run_day():
            return city, False
        city.player()
    return city, True


def report(label, overrides=None, games=300, days=1000, modern=False):
    p = dict(P, **(overrides or {}))
    for name, active, savvy in (("naive", True, False), ("lazy", False, True), ("active", True, True)):
        results = [play(p, s, active, days, savvy, modern) for s in range(games)]
        lost = [c for c, alive in results if not alive]
        peaks = [c.peak for c, _ in results]
        final = [c.pop for c, alive in results if alive]
        crowns = [c.crowns for c, alive in results if alive]
        causes = Counter()
        for c, _ in results:
            causes.update(c.causes)
        top = ", ".join("%s %.0f%%" % (k, 100 * v / max(1, sum(causes.values()))) for k, v in causes.most_common(3))
        print("%-30s %-7s lost %3d%%  median loss day %4s  peak pop median %4d (p10 %4d, p90 %4d)  final pop %4s  final crowns %6s | %s" % (
            label, name,
            round(100 * len(lost) / games),
            int(statistics.median(c.day for c in lost)) if lost else "-",
            statistics.median(peaks), sorted(peaks)[games // 10], sorted(peaks)[9 * games // 10],
            int(statistics.median(final)) if final else "-",
            int(statistics.median(crowns)) if crowns else "-", top))


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "base"
    if which == "base":
        games = int(sys.argv[2]) if len(sys.argv) > 2 else 300
        report("classic buildings", games=games)
        report("modern buildings", games=games, modern=True)
        report("classic, upkeep 2 (design doc)", dict(upkeep=2), games=games)
        report("modern, upkeep 2", dict(upkeep=2), games=games, modern=True)
    elif which == "trace":
        city = City(dict(P), random.Random(1), len(sys.argv) > 3, modern=True)
        city.player()
        for _ in range(int(sys.argv[2]) if len(sys.argv) > 2 else 60):
            alive = city.run_day()
            city.player()
            if city.day <= 30 or city.day % 20 == 0 or not alive:
                print("day %3d pop %4d/%4d crowns %5d coal %4d food %4d unrest %5.1f idle %3d  T%d H%d G%d P%d B%d Y%d M%d V%d D%d tea%d clock%d broken %d" % (
                    city.day, city.pop, city.capacity, city.crowns, city.coal, city.food, city.unrest, city.idle,
                    city.tenements, city.townhouses, city.count("glasshouse"), city.count("pit"),
                    city.count("brassworks"), city.count("yard"), city.count("market"), city.count("tavern"),
                    city.count("dock"), city.teas, int(city.clock), sum(w["broken"] for w in city.work)))
            if not alive:
                print("WALKOUT")
                break
