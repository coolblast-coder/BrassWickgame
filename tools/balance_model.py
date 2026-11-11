"""Non-spatial model of Brasswick's daily tick, for balance checks.

Mirrors sim/city_sim.gd and sim/city_events.gd in rule order and constants.
The numbers in P below are copies: when a constant changes in the game,
change it here too, or the model drifts.

Not modelled: map layout. Assumes every building has road access and that the
player keeps homes out of smog (so smog adds no Unrest and Glasshouses grow
at full rate). The city is capped at `map_tiles` of building footprint.

A scripted player builds once per day. Three kinds are compared:
  naive   pays for every repair; spends freely from day one
  lazy    saves for a first Brassworks; pays for repairs only until the city
          has a Mechanic's Yard, then relies on Yards
  active  saves for a first Brassworks; pays for every repair
In practice naive and active usually come out the same: the saving rule
rarely changes what gets built.
The scripted player is competent, not clever. Read the results as "which
levers matter", not as predicted scores.

Usage (not part of the Godot project; needs only Python 3):
  python tools/balance_model.py              compare variants, 300 games each
                                             (takes a few minutes)
  python tools/balance_model.py base 50      same, 50 games each
  python tools/balance_model.py trace 200    print one lazy game day by day
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
    move_in=2, housing=10, upkeep=1, repair_cost=20,
    brk_base=0.01, brk_per=0.001, brk_max=0.10,
    u_hunger=20.0, u_cold=10.0, u_idle=5.0, u_broken=2.0, u_broken_max=10.0,
    u_debt=5.0, u_calm=3.0, u_tea=4.0,
    move_in_below=50.0, leave_above=75.0, leave_share=0.05, walkout_days=3,
    quiet_days=10, min_gap=5, strike_days=5, strike_factor=0.5,
    trader_crowns=100, trader_food=40,
    homes_per_tea=4,      # Tenements one Tea Garden can cover (layout guess)
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
}
PRIORITY = {"glasshouse": 0, "pit": 1, "yard": 2, "brassworks": 3}


class City:
    def __init__(self, p, rng, active_repairs, savvy=True):
        self.p, self.rng, self.active, self.savvy = p, rng, active_repairs, savvy
        self.crowns, self.coal, self.food = p["start_crowns"], p["start_coal"], p["start_food"]
        self.pop = self.peak = 0
        self.unrest = 0.0
        self.tenements = self.teas = 0
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

    def buy(self, kind):
        cost = {"tenement": 50, "tea": 60}.get(kind) or DEFS[kind][0]
        cost += self.p["road_cost"]
        size = {"tenement": 4, "tea": 4, "glasshouse": 6, "pit": 9, "brassworks": 12, "yard": 4}[kind]
        if self.crowns < cost or self.tiles + size > self.p["map_tiles"]:
            return False
        if self.savvy and kind != "brassworks" and self.count("brassworks") == 0                 and self.crowns - cost < 156 + 30:
            return False
        self.tiles += size
        self.crowns -= cost
        if kind == "tenement":
            self.tenements += 1
        elif kind == "tea":
            self.teas += 1
        else:
            self.work.append(dict(kind=kind, broken=False, staff=0, ran=False))
        return True

    def run_day(self):
        p = self.p
        self.day += 1
        cap = self.tenements * p["housing"]
        pop = min(self.pop, cap)
        if self.unrest > p["leave_above"] and pop > 0:
            pop -= max(1, math.ceil(pop * p["leave_share"]))
        elif self.unrest < p["move_in_below"]:
            pop = min(cap, pop + self.tenements * p["move_in"])
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
        machines = []
        for w in self.work:
            w["ran"] = False
            if w["broken"]:
                broken += 1
                continue
            _, need, burn, f, c, cr = DEFS[w["kind"]]
            share = w["staff"] / need
            if burn == 0:
                w["ran"] = share > 0
                pool += round(c * share * (p["strike_factor"] if self.strike else 1.0))
            else:
                machines.append(w)
        if p["fuel_food_first"]:
            machines.sort(key=lambda w: PRIORITY[w["kind"]])
        cold = max(0, self.tenements - pool)
        pool -= self.tenements - cold
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
        upkeep = p["upkeep"] * (self.tenements + self.teas + len(self.work))
        self.crowns += crowns_made + pop // 2 - upkeep
        have = self.food + food_made
        hungry = max(0, pop - have)
        self.food = max(0, have - pop)
        self.coal_net = pool - self.coal
        self.coal = pool
        self.food_made = food_made

        def share_of(a, b):
            return min(1.0, a / b) if b > 0 else 0.0
        tea_cover = share_of(self.teas * p["homes_per_tea"], self.tenements)
        parts = dict(
            hunger=p["u_hunger"] * share_of(hungry, pop),
            cold=p["u_cold"] * share_of(cold, self.tenements),
            idle=p["u_idle"] * share_of(avail, total),
            broken=min(p["u_broken_max"], p["u_broken"] * broken),
            debt=p["u_debt"] if self.crowns < 0 else 0.0,
        )
        change = sum(parts.values()) - p["u_tea"] * tea_cover - p["u_calm"]
        for k, v in parts.items():
            self.causes[k] += v
        self.unrest = min(100.0, max(0.0, self.unrest + change))
        self.at_max = self.at_max + 1 if self.unrest >= 100.0 else 0

        yards = sum(1 for w in self.work if w["kind"] == "yard" and not w["broken"] and w["staff"] > 0)
        cover = share_of(yards * p["machines_per_yard"], len(self.work))
        for w in self.work:
            if w["broken"] and self.rng.random() < cover:
                w["broken"] = False
        chance = min(p["brk_max"], p["brk_base"] + p["brk_per"] * len(self.work))
        for w in self.work:
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
        ran = [w for w in self.work if w["ran"] and not w["broken"]]
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
            growth = self.tenements * p["move_in"] if self.pop < self.tenements * p["housing"] else 0
            g, pit, bw, yard = (self.count(k) for k in ("glasshouse", "pit", "brassworks", "yard"))
            coal_need = self.tenements + g + 4 * bw + yard
            if self.tenements == 0:
                ok = self.buy("tenement")
            elif g * 20 < self.pop + growth and self.food < 3 * max(self.pop, 10):
                ok = self.buy("glasshouse")
            elif pit * 12 < 1.3 * coal_need + 2 and self.coal < 8 * coal_need + 30:
                ok = self.buy("pit")
            elif self.idle >= 6 and (pit * 12 >= 1.3 * (coal_need + 4) or self.coal > 40 and bw == 0):
                ok = self.buy("brassworks")
            elif len(self.work) >= 3 and yard * p["machines_per_yard"] < len(self.work):
                ok = self.buy("yard")
            elif self.teas * p["homes_per_tea"] < self.tenements and (self.unrest > 15 or (self.crowns > 400 and self.tenements >= 6)):
                ok = self.buy("tea")
            elif self.pop >= 0.8 * self.tenements * p["housing"] and self.unrest < 40 and self.crowns >= 110:
                ok = self.buy("tenement")
            else:
                ok = False
            if not ok:
                break


def play(p, seed, active, days, savvy=True):
    city = City(p, random.Random(seed), active, savvy)
    city.player()
    while city.day < days:
        if not city.run_day():
            return city, False
        city.player()
    return city, True


def report(label, overrides=None, games=300, days=1000):
    p = dict(P, **(overrides or {}))
    for name, active, savvy in (("naive", True, False), ("lazy", False, True), ("active", True, True)):
        results = [play(p, s, active, days, savvy) for s in range(games)]
        lost = [c for c, alive in results if not alive]
        peaks = [c.peak for c, _ in results]
        final = [c.pop for c, alive in results if alive]
        causes = Counter()
        for c, _ in results:
            causes.update(c.causes)
        top = ", ".join("%s %.0f%%" % (k, 100 * v / max(1, sum(causes.values()))) for k, v in causes.most_common(3))
        print("%-34s %-7s lost %3d%%  median loss day %4s  peak pop median %4d (p10 %4d, p90 %4d)  final pop %4s | %s" % (
            label, name,
            round(100 * len(lost) / games),
            int(statistics.median(c.day for c in lost)) if lost else "-",
            statistics.median(peaks), sorted(peaks)[games // 10], sorted(peaks)[9 * games // 10],
            int(statistics.median(final)) if final else "-", top))


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "base"
    if which == "base":
        games = int(sys.argv[2]) if len(sys.argv) > 2 else 300
        report("current values", games=games)
        report("upkeep 2 (design doc)", dict(upkeep=2), games=games)
        report("start 800 crowns", dict(start_crowns=800), games=games)
        report("coal: glasshouses first", dict(fuel_food_first=True), games=games)
        report("workers: essentials first", dict(staff_priority=True), games=games)
    elif which == "trace":
        city = City(dict(P), random.Random(1), len(sys.argv) > 3)
        city.player()
        for _ in range(int(sys.argv[2]) if len(sys.argv) > 2 else 60):
            alive = city.run_day()
            city.player()
            if city.day <= 30 or city.day % 20 == 0 or not alive:
                print("day %3d pop %4d/%4d crowns %5d coal %4d food %4d unrest %5.1f idle %3d  T%d G%d P%d B%d Y%d tea%d broken %d" % (
                    city.day, city.pop, city.tenements * 10, city.crowns, city.coal, city.food, city.unrest, city.idle,
                    city.tenements, city.count("glasshouse"), city.count("pit"), city.count("brassworks"),
                    city.count("yard"), city.teas, sum(w["broken"] for w in city.work)))
            if not alive:
                print("WALKOUT")
                break
