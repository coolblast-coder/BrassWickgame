"""Non-spatial model of Brasswick's daily tick, for balance checks.

Mirrors sim/city_sim.gd and sim/city_events.gd in rule order and constants.
The numbers in P and the tables below are copies: when a constant changes in
the game, change it here too, or the model drifts.

Not modelled: map layout and smog. Assumes every building has road access
and that the player keeps homes out of smog (so smog adds no Unrest and
Glasshouses grow at full rate); the Smog Scrubber is therefore left out.
The city is capped at `map_tiles` of building footprint. Homes are heated
Tenements first, then Townhouses, rather than in placement order. The
player never switches buildings off. Stockpiles are limited as in the game,
and the player adds Warehouses to hold about three days of Food.

Seasons are modelled, but poorly judged: getting through winter depends on
stocking up beforehand, and the scripted player cannot plan. Its results
with seasons swing from a quarter to all games lost on small changes to its
habits, so they say little about whether the season numbers are fair. Wind
is not modelled, because smog is not.

Also not modelled: Town Hall policies, council requests, and the choices
events now offer. Events here still take the "do nothing" outcome (a strike
runs its full length, a boiler bursts) and the Airship Trader gives Crowns
or Food at random, as the game did before choices were added.

A scripted player builds once per day. Three kinds are compared:
  naive   pays for every repair; spends freely from day one
  lazy    saves for a first Market; pays for repairs only until the city
          has a Mechanic's Yard, then relies on Yards
  active  saves for a first Market; pays for every repair
The scripted player is competent, not clever. Read the results as "which
levers matter", not as predicted scores.

Usage (not part of the Godot project; needs only Python 3):
  python tools/balance_model.py              compare variants, 300 games each
                                             (takes several minutes)
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
    move_in=2, upkeep_by_tier=(1, 1, 2, 2), repair_cost=20,
    brk_base=0.01, brk_per=0.001, brk_max=0.10,
    u_hunger=20.0, u_thirst=12.0, u_goods=8.0, u_cold=10.0, u_idle=5.0,
    u_broken=2.0, u_broken_max=10.0, u_debt=5.0,
    u_calm=3.0, u_tea=4.0, u_tavern=3.0, u_clock=2.0,
    move_in_below=50.0, leave_above=75.0, leave_share=0.05, walkout_days=3,
    quiet_days=10, min_gap=5, strike_days=5, strike_factor=0.5,
    trader_crowns=100, trader_food=40,
    tavern_food=5, trade_coal=10, trade_crowns=15, trade_reserve=100,
    tier_population=(0, 100, 400, 1000),
    water_tier=1, citizens_per_water=5, water_grant=100,
    goods_tier=2, citizens_per_goods=10, goods_grant=40,
    steam_tier=3, steam_grant=60,
    storage_base=300, storage_per_warehouse=500,  # limit on every stockpile
    # Seasons, in order from day 1: spring, summer, autumn, winter.
    season_days=12,
    season_food=(1.0, 1.0, 1.25, 0.75),      # Glasshouse output
    season_home_coal=(1, 1, 1, 2),           # Coal to heat a home
    season_water=(1.0, 1.25, 1.0, 1.0),      # citizens' Water need
    season_tier=1,          # tier from which the seasons have any effect
    winter_margin=1.2,      # surplus of Food output a planning player builds
    plans_for_winter=False, # True: scripted player overbuilds farms and pits
    homes_per_tea=4,      # homes one Tea Garden can cover (layout guess)
    homes_per_tavern=6,   # homes one Tavern can cover (layout guess)
    machines_per_yard=10, # machines one Mechanic's Yard can cover (layout guess)
    road_cost=6,          # road tiles bought with each building, in Crowns
    map_tiles=2000,       # buildable tiles: about half of the 64 x 64 map
    # Rule variants:
    staff_priority=True,    # False: workers fill buildings in placement order
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
    "pump": (120, 3, 1, 0, 0, 0),
    "workshop": (160, 6, 3, 0, 0, 0),
    "station": (300, 6, 8, 0, 0, 0),
}
WATER_OUT = {"pump": 30}
GOODS_OUT = {"workshop": 12}
STEAM_OUT = {"station": 20}
STEAM_USE = {"workshop": 4, "dock": 3}
CLOCK_STEAM = 2
# Buildings that are not workplaces: cost, housing, coal burned.
PLAIN = {"tenement": (50, 10, 1), "townhouse": (140, 20, 2), "tea": (60, 0, 0),
         "warehouse": (100, 0, 0),
         "clocktower": (500, 0, 0)}
TILES = {"tenement": 4, "townhouse": 4, "tea": 4, "warehouse": 4, "clocktower": 4, "glasshouse": 6, "pit": 9,
         "brassworks": 12, "yard": 4, "market": 6, "tavern": 4, "dock": 9, "pump": 4,
         "workshop": 6, "station": 9}
TIER = {"brassworks": 1, "yard": 1, "tavern": 1, "townhouse": 1, "pump": 1,
        "dock": 2, "workshop": 2, "clocktower": 3, "station": 3}
ESSENTIAL = {"glasshouse", "pit", "pump", "workshop", "station"}
STAFFED_FIRST = {"glasshouse", "pit", "pump", "station"}
BREAKS = {"glasshouse", "pit", "brassworks", "yard", "pump", "workshop", "station"}
PRIORITY = {"glasshouse": 0, "pit": 1, "pump": 2, "yard": 3, "station": 4, "workshop": 5,
            "brassworks": 6, "market": 7, "tavern": 8, "dock": 9}


class City:
    def __init__(self, p, rng, active_repairs, savvy=True):
        self.p, self.rng, self.active, self.savvy = p, rng, active_repairs, savvy
        self.crowns, self.coal, self.food = p["start_crowns"], p["start_coal"], p["start_food"]
        self.water = self.goods = self.steam = 0
        self.pop = self.peak = self.tier = 0
        self.unrest = 0.0
        self.tenements = self.townhouses = self.teas = self.warehouses = 0
        self.clock = False
        self.tiles = 0
        self.work = []  # dicts: kind, broken, staff, ran
        self.at_max = 0
        self.strike = 0
        self.last_event = -p["min_gap"]
        self.day = 0
        self.causes = Counter()
        self.idle = 0

    def count(self, kind):
        return sum(1 for w in self.work if w["kind"] == kind)

    @property
    def homes(self):
        return self.tenements + self.townhouses

    @property
    def capacity(self):
        return self.tenements * PLAIN["tenement"][1] + self.townhouses * PLAIN["townhouse"][1]

    @property
    def townhouse_residents(self):
        cap = self.capacity
        return self.pop * self.townhouses * PLAIN["townhouse"][1] // cap if cap else 0

    def season(self, day=None):
        day = self.day if day is None else day
        return ((max(day, 1) - 1) // self.p["season_days"]) % 4

    def storage(self):
        return self.p["storage_base"] + self.warehouses * self.p["storage_per_warehouse"]

    def upkeep_each(self):
        return self.p["upkeep_by_tier"][self.tier]

    def unlocked(self, kind):
        return TIER.get(kind, 0) <= self.tier

    def buy(self, kind):
        if not self.unlocked(kind):
            return False
        cost = (PLAIN[kind][0] if kind in PLAIN else DEFS[kind][0]) + self.p["road_cost"]
        if self.crowns < cost or self.tiles + TILES[kind] > self.p["map_tiles"]:
            return False
        if self.savvy and kind != "market" and self.count("market") == 0 \
                and self.crowns - cost < 116 + 30:
            return False
        self.tiles += TILES[kind]
        self.crowns -= cost
        if kind == "tenement":
            self.tenements += 1
        elif kind == "townhouse":
            self.townhouses += 1
        elif kind == "tea":
            self.teas += 1
        elif kind == "warehouse":
            self.warehouses += 1
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
        while self.tier + 1 < len(p["tier_population"]) and self.peak >= p["tier_population"][self.tier + 1]:
            self.tier += 1
            if self.tier == p["water_tier"]:
                self.water += p["water_grant"]
            if self.tier == p["goods_tier"]:
                self.goods += p["goods_grant"]
            if self.tier == p["steam_tier"]:
                self.steam += p["steam_grant"]

        total = pop // 2
        avail = total
        order = self.work
        if p["staff_priority"]:
            order = sorted(self.work, key=lambda w: w["kind"] not in STAFFED_FIRST)
        for w in order:
            w["staff"] = 0
            if not w["broken"]:
                w["staff"] = min(DEFS[w["kind"]][1], avail)
                avail -= w["staff"]
        self.idle = avail

        pool = self.coal
        steam_pool = self.steam
        needs_steam = self.tier >= p["steam_tier"]
        food_made = crowns_made = water_made = goods_made = steam_made = broken = 0

        def powered(kind):
            nonlocal steam_pool
            need = STEAM_USE.get(kind, 0)
            if not needs_steam or need == 0:
                return True
            if steam_pool >= need:
                steam_pool -= need
                return True
            return False

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
        clock_runs = self.clock
        if self.clock and needs_steam:
            if steam_pool >= CLOCK_STEAM:
                steam_pool -= CLOCK_STEAM
            else:
                clock_runs = False
        if p["fuel_food_first"]:
            machines.sort(key=lambda w: PRIORITY[w["kind"]])
        # Before the city reaches `season_tier` every season is like spring.
        season = self.season() if self.tier >= p["season_tier"] else 0
        food_factor = p["season_food"][season]
        heat = p["season_home_coal"][season]
        warm_tenements = min(self.tenements, pool // (PLAIN["tenement"][2] * heat))
        pool -= warm_tenements * PLAIN["tenement"][2] * heat
        warm_townhouses = min(self.townhouses, pool // (PLAIN["townhouse"][2] * heat))
        pool -= warm_townhouses * PLAIN["townhouse"][2] * heat
        cold = self.homes - warm_tenements - warm_townhouses
        for w in machines:
            kind = w["kind"]
            _, need, burn, f, c, cr = DEFS[kind]
            if pool >= burn and powered(kind):
                pool -= burn
                share = w["staff"] / need
                w["ran"] = share > 0
                food_made += round(f * share * food_factor)
                crowns_made += round(cr * share)
                water_made += round(WATER_OUT.get(kind, 0) * share)
                goods_made += round(GOODS_OUT.get(kind, 0) * share)
                steam_made += round(STEAM_OUT.get(kind, 0) * share)
        for w in docks:
            if not powered("dock"):
                continue
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

        water_have = self.water + water_made
        water_need = math.ceil(pop / p["citizens_per_water"] * p["season_water"][season]) \
            if self.tier >= p["water_tier"] else 0
        thirsty = min(pop, max(0, water_need - water_have) * p["citizens_per_water"])
        self.water = max(0, water_have - water_need)

        buyers = self.townhouse_residents
        goods_have = self.goods + goods_made
        goods_need = math.ceil(buyers / p["citizens_per_goods"]) if self.tier >= p["goods_tier"] else 0
        without_goods = min(buyers, max(0, goods_need - goods_have) * p["citizens_per_goods"])
        self.goods = max(0, goods_have - goods_need)

        self.steam = steam_pool + steam_made

        upkeep = self.upkeep_each() * (self.homes + self.teas + self.warehouses + len(self.work) + int(self.clock))
        self.crowns += crowns_made + pop // 2 - upkeep
        room = self.storage()
        self.food = min(food_left, room)
        self.coal = min(pool, room)
        self.water = min(self.water, room)
        self.goods = min(self.goods, room)
        self.steam = min(self.steam, room)

        def share_of(a, b):
            return min(1.0, a / b) if b > 0 else 0.0
        parts = dict(
            hunger=p["u_hunger"] * share_of(hungry, pop),
            thirst=p["u_thirst"] * share_of(thirsty, pop),
            goods=p["u_goods"] * share_of(without_goods, pop),
            cold=p["u_cold"] * share_of(cold, self.homes),
            idle=p["u_idle"] * share_of(avail, total),
            broken=min(p["u_broken_max"], p["u_broken"] * broken),
            debt=p["u_debt"] if self.crowns < 0 else 0.0,
        )
        relief = p["u_calm"] \
            + p["u_tea"] * share_of(self.teas * p["homes_per_tea"], self.homes) \
            + p["u_tavern"] * share_of(open_taverns * p["homes_per_tavern"], self.homes) \
            + (p["u_clock"] if clock_runs else 0.0)
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
        hired = 0  # jobs created today, not yet reflected in self.idle
        for _ in range(6):
            idle = self.idle - hired
            before = len(self.work)
            growth = self.homes * p["move_in"] if self.pop < self.capacity else 0
            g, pit, bw, yard, market, tavern, dock, pump, shop, station = (self.count(k) for k in (
                "glasshouse", "pit", "brassworks", "yard", "market", "tavern", "dock",
                "pump", "workshop", "station"))
            machines = sum(1 for w in self.work if w["kind"] in BREAKS)
            coal_need = self.tenements + 2 * self.townhouses + g + 4 * bw + yard + pump + 3 * shop + 8 * station
            food_need = self.pop + growth + p["tavern_food"] * tavern
            water_need = (self.pop + growth) / p["citizens_per_water"] if self.tier >= p["water_tier"] else 0
            goods_need = self.townhouses * 2 if self.tier >= p["goods_tier"] else 0
            steam_need = 4 * shop + 3 * dock + (CLOCK_STEAM if self.clock else 0) \
                if self.tier >= p["steam_tier"] else 0
            # With too few workers for the essential buildings, house more
            # before anything else. (This mattered most when staffing went
            # purely by placement order; see the staff_priority variant.)
            # A player who plans for winter builds enough Glasshouses and
            # Coal Pits to get through it without relying on stock; one who
            # does not sizes them for today's season.
            if p["plans_for_winter"]:
                farm_yield = 1.0 / p["winter_margin"]
                winter_heat = (max(p["season_home_coal"]) - 1) * (self.tenements + 2 * self.townhouses)
            else:
                farm_yield = p["season_food"][self.season(self.day + 1)]
                winter_heat = (p["season_home_coal"][self.season(self.day + 1)] - 1) \
                    * (self.tenements + 2 * self.townhouses)
            water_need *= max(p["season_water"]) if p["plans_for_winter"] \
                else p["season_water"][self.season(self.day + 1)]
            short_staffed = any(not w["broken"] and w["staff"] < DEFS[w["kind"]][1]
                                and w["kind"] in ESSENTIAL for w in self.work)
            if self.homes == 0:
                ok = self.buy("tenement")
            elif short_staffed and idle <= 0 and self.pop >= 0.8 * self.capacity and self.unrest < 50:
                ok = self.buy("tenement")
            elif g * 20 * farm_yield < food_need and self.food < 3 * max(self.pop, 10):
                ok = self.buy("glasshouse")
            elif pit * 12 < 1.3 * (coal_need + winter_heat) + 2 and self.coal < 8 * coal_need + 30:
                ok = self.buy("pit")
            elif pump * 30 < water_need and self.water < 6 * water_need:
                ok = self.buy("pump")
            elif station * 20 < steam_need and self.steam < 4 * steam_need:
                ok = self.buy("station")
            elif shop * 12 < goods_need and self.goods < 6 * goods_need:
                ok = self.buy("workshop")
            elif self.crowns > 250 and self.storage() < 3 * max(food_need, coal_need) \
                    and max(self.coal, self.food) >= 0.9 * self.storage():
                ok = self.buy("warehouse")
            elif self.tier >= 1 and idle >= 6 and pit * 12 >= 1.3 * (coal_need + 4):
                ok = self.buy("brassworks")
            elif idle >= 4:
                ok = self.buy("market")
            elif self.unlocked("yard") and machines >= 3 and yard * p["machines_per_yard"] < machines:
                ok = self.buy("yard")
            elif self.teas * p["homes_per_tea"] < self.homes and (self.unrest > 15 or (self.crowns > 400 and self.homes >= 6)):
                ok = self.buy("tea")
            elif self.unlocked("tavern") and self.unrest > 15 and idle >= 3 \
                    and self.food > 2 * self.pop + 20 and tavern * p["homes_per_tavern"] < self.homes:
                ok = self.buy("tavern")
            elif self.unlocked("dock") and idle >= 4 and self.coal > p["trade_reserve"] + 60 and dock < 1 + pit // 3:
                ok = self.buy("dock")
            elif self.unlocked("clocktower") and not self.clock and self.crowns > 800 and self.homes >= 10:
                ok = self.buy("clocktower")
            elif self.pop >= 0.8 * self.capacity and self.unrest < 40 and self.crowns >= 110:
                ok = self.buy("townhouse" if self.tier >= 1 and self.crowns >= 300 else "tenement")
            else:
                ok = False
            if not ok:
                break
            if len(self.work) > before:
                hired += DEFS[self.work[-1]["kind"]][1]


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
        crowns = [c.crowns for c, alive in results if alive]
        tiers = Counter(c.tier for c, _ in results)
        causes = Counter()
        for c, _ in results:
            causes.update(c.causes)
        top = ", ".join("%s %.0f%%" % (k, 100 * v / max(1, sum(causes.values()))) for k, v in causes.most_common(3))
        print("%-24s %-7s lost %3d%%  loss day %4s  peak pop %4d (p10 %4d, p90 %4d)  final pop %4s  crowns %7s  tiers %s | %s" % (
            label, name,
            round(100 * len(lost) / games),
            int(statistics.median(c.day for c in lost)) if lost else "-",
            statistics.median(peaks), sorted(peaks)[games // 10], sorted(peaks)[9 * games // 10],
            int(statistics.median(final)) if final else "-",
            int(statistics.median(crowns)) if crowns else "-",
            "/".join(str(tiers.get(t, 0)) for t in range(4)), top))


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "base"
    if which == "base":
        games = int(sys.argv[2]) if len(sys.argv) > 2 else 300
        report("current values", games=games)
        report("no seasons", dict(season_food=(1.0,) * 4, season_home_coal=(1,) * 4,
                                  season_water=(1.0,) * 4), games=games)
        report("player overbuilds for winter", dict(plans_for_winter=True), games=games)
        report("no storage limit", dict(storage_base=10 ** 9), games=games)
        report("staffing in placement order", dict(staff_priority=False), games=games)
        report("upkeep 1 at every tier", dict(upkeep_by_tier=(1, 1, 1, 1)), games=games)
        report("upkeep 1, 2, 2, 3", dict(upkeep_by_tier=(1, 2, 2, 3)), games=games)
        report("upkeep 1, 2, 3, 4", dict(upkeep_by_tier=(1, 2, 3, 4)), games=games)
    elif which == "trace":
        city = City(dict(P), random.Random(1), len(sys.argv) > 3)
        city.player()
        for _ in range(int(sys.argv[2]) if len(sys.argv) > 2 else 60):
            alive = city.run_day()
            city.player()
            if city.day <= 30 or city.day % 20 == 0 or not alive:
                print("day %3d tier %d pop %4d/%4d crowns %6d coal %4d food %4d water %4d goods %4d steam %4d unrest %5.1f idle %3d  T%d H%d G%d P%d B%d Y%d M%d V%d D%d Pu%d W%d S%d tea%d clock%d broken %d" % (
                    city.day, city.tier, city.pop, city.capacity, city.crowns, city.coal, city.food,
                    city.water, city.goods, city.steam, city.unrest, city.idle,
                    city.tenements, city.townhouses, city.count("glasshouse"), city.count("pit"),
                    city.count("brassworks"), city.count("yard"), city.count("market"), city.count("tavern"),
                    city.count("dock"), city.count("pump"), city.count("workshop"), city.count("station"),
                    city.teas, int(city.clock), sum(w["broken"] for w in city.work)))
            if not alive:
                print("WALKOUT")
                break
