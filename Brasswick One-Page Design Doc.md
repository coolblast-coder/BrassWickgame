# Brasswick: One-Page Design Doc

Nov 11, 2026 · @Anton

## The game

Brasswick (working title) is an endless 3D city builder where you grow a coal-fed steam city as large as you can before its citizens walk out on you. It is built in Godot 4 with GDScript, using boxes, cylinders and capsules as placeholder art.

**Tone:** soot and hardship at street level, brass, bunting and absurd contraptions on the skyline. Events are written with dry humour; the consequences are real.

**How it ends:** every failure in the city (hunger, cold, smog, idle hands, broken machines, debt) pushes one Unrest meter. If Unrest stays at 100 for 3 in-game days in a row, the Great Walkout begins and the game is over. Your score is peak population and days survived.

**Time:** real time with pause and 1x/3x speed. One in-game day is 10 seconds at 1x, and the whole simulation updates once per day.

## 1. Core gameplay loop

Every minute the player reads the city, spends Crowns to fix the worst shortage, and lives with the side effects of that fix.

1. **Read.** Check the top bar (Crowns, Coal, Food, Population, Unrest) and flip on the smog or unrest overlay to see where the trouble is.
2. **Build.** Drag out roads, then place buildings beside them. Housing brings citizens; citizens bring taxes and workers.
3. **Supply.** New citizens eat and burn coal, so add Glasshouses and Coal Pits, then Brassworks to pay for it all.
4. **Contain.** More machines mean more smog and breakdowns. Repair broken buildings, add Mechanic's Yards and Tea Gardens, and move housing away from chimneys.
5. **React.** A random event lands (a burst boiler, a coal strike, a smog storm). Pause, re-plan, recover.
6. **Push on.** Once Unrest is steady and Crowns are in the black, expand again. Each expansion restarts the loop at a larger, less forgiving scale.

## 2. Controls

Mouse and keyboard only, with every action also reachable from on-screen buttons.

| Action | Input |
| --- | --- |
| Pan camera | WASD or arrow keys, or push the mouse to a screen edge |
| Rotate camera | Q / E, or hold middle mouse and drag |
| Zoom | Mouse wheel |
| Pick a building | Click the build bar, or keys 1 to 7 |
| Place a building | Left click on a highlighted tile (green = valid, red = blocked) |
| Lay road | Left click and drag |
| Rotate before placing | R |
| Cancel | Right click or Esc |
| Select a building | Left click it to see workers, output and condition |
| Repair a broken building | Select it, then press F or click Repair |
| Demolish | X to enter demolish mode, then left click |
| Pause / speed | Space to pause, Tab to switch 1x and 3x |
| Overlays | O cycles none, smog, unrest |

## 3. First playable: three must-haves

The prototype is one flat 64 x 64 grid, seven things to build, and one way to lose.

**A. Grid building with roads.** Buildings snap to tiles and only work when they touch a road that connects back to the Town Hall, which is placed for you at the start. The player starts with 600 Crowns, 50 Coal and 50 Food.

| Build | Cost (Crowns) | Workers | Coal per day | What it does |
| --- | --- | --- | --- | --- |
| Road | 2 per tile | 0 | 0 | Connects buildings to the Town Hall |
| Tenement | 50 | 0 | 1 | Houses 10 citizens |
| Glasshouse | 80 | 4 | 1 | Grows 20 Food per day |
| Coal Pit | 100 | 6 | 0 | Digs 12 Coal per day; light smog |
| Brassworks | 150 | 8 | 4 | Earns 40 Crowns per day; heavy smog |
| Mechanic's Yard | 120 | 4 | 1 | Repairs breakdowns within 6 tiles for free |
| Tea Garden | 60 | 0 | 0 | Lowers smog and Unrest within 4 tiles |

All numbers are starting values to tune in playtests.

**B. A daily city simulation.** Citizens are numbers, not agents. Once per in-game day the game totals production, consumption, taxes, smog and Unrest and updates the top bar. Capsule walkers on the roads and a few circling airships are decoration only; their count follows population, capped at about 50.

**C. Collapse pressure.** Machines break down, random events fire more often as population passes 100, 250, 500 and 1,000, and the Unrest meter ends the game. The first version ships four events: Burst Boiler (one machine breaks at once), Coal Strike (pits at half output for 5 days), Smog Storm (smog stops clearing for 5 days) and Airship Trader (a gift of Crowns or Food).

**Cut from the first version:** saving and loading, terrain, sound, tutorials, building upgrades, menus beyond a restart button.

## 4. Later: three features once the core is fun

Each of these adds a new decision on top of the existing loop instead of replacing it.

1. **Pneumatic tubes and airship docks.** Coal and Food stop being city-wide totals and have to travel. Tubes move goods between districts, and docks let the player buy and sell with passing airships.
2. **Clockwork automatons.** Automatons fill worker slots without eating, but burn coal, break down, and raise Unrest among the citizens they replace.
3. **Citizen classes and edicts.** Labourers, engineers and gentry want different things, as in Anno. Edicts such as coal rationing or a smog curfew trade one pressure for another.

Save and load, sound and real 3D assets are needed before anyone else plays it, but they are polish, not design.

## 5. Resources and how they connect

Four things are stockpiled (Crowns, Coal, Food, Citizens) and three things are pressures (Smog, Breakdowns, Unrest); every shortage in the first group feeds the second.

&#91;embedded content: resource map · 8 resources and pressures, 1 loop\]

Read it top down: housing brings citizens, half of them work, workers make Food, Coal and Crowns, and burning coal creates the smog and breakdowns that push Unrest. High Unrest drives citizens away, which shrinks the workforce and makes the next shortage worse.

| Resource | Comes from | Goes to | When it runs short |
| --- | --- | --- | --- |
| Crowns | Tax of 1 per 2 citizens per day; Brassworks | Building, repairs (20 each), upkeep of 2 per building per day | Below zero: nothing can be built or repaired, Unrest rises |
| Citizens | Move in when Tenements have room and Unrest is under 50 | Half become Workers | Leave when Unrest passes 75 |
| Workers | Half the population | Staff Glasshouses, Coal Pits, Brassworks, Mechanic's Yards | Understaffed buildings produce in proportion; idle workers add Unrest |
| Coal | Coal Pits | Tenement heating and every machine building | Machines stop; cold homes add Unrest |
| Food | Glasshouses | 1 per citizen per day | Hunger adds Unrest faster than anything else |
| Smog | Every coal-burning building and Coal Pit, spreading to nearby tiles | Cleared slowly over time and by Tea Gardens | Too much: smoggy Tenements add Unrest, smoggy Glasshouses grow less |
| Breakdowns | A daily chance per machine, starting at 1% and rising with the city's machine count | Fixed by paying Crowns or by a Mechanic's Yard in range | Too many: broken buildings produce nothing and add Unrest |

**Why it gets harder.** Food, coal and housing needs grow in step with population, but smog piles up where buildings cluster, breakdown odds rise with every machine added, and events fire more often at each population threshold. A city of 1,000 is not ten cities of 100; it is one city with ten times the chimneys in the same air.
