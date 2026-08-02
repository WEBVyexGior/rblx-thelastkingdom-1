# The nine chambers

Notes behind `tools/BuildChambers.luau`.

The serpentine already works as a route. What it does not yet do is tell you
where you are. Nine identical yards would be nine identical fights; nine
*places* make the walk mean something, and let a player say "I'm at the
graveyard" without a map.

The order is not decorative. It runs outward-in: the parts of a castle a
stranger would see first, then the parts only its household used, then the last
place anybody was alive.

| # | z | Place | What it was | What it is now |
|---|---|---|---|---|
| 1 | +20 → -180 | **Outer Ward** | Guardhouse, muster yard | Barricaded from the inside. They knew what was coming. |
| 2 | -180 → -380 | **Stables** | Horses, forage, farrier | Stalls smashed outward. Whatever left did not use the door. |
| 3 | -380 → -580 | **Kitchens** | Bake ovens, well, stores | Cold ovens, a boarded well, stores emptied in a hurry. |
| 4 | -580 → -780 | **Graveyard** | Chapel and burial ground | New graves, dug badly, and more of them than the ground was meant for. |
| 5 | -780 → -980 | **Smithy** | Forge, armoury, quench | Weapons half-finished on the bench. It was still working when it stopped. |
| 6 | -980 → -1180 | **Great Hall** | Feasting, court, banners | The largest ruin here, roof gone, table still standing. |
| 7 | -1180 → -1380 | **The Rows** | Servants' houses, market | Ordinary streets. The only place in the castle that was ever cheerful. |
| 8 | -1380 → -1580 | **Inner Ward** | Last defensive line | A tower down across the yard. The line broke here. |
| 9 | -1580 → -1780 | **Keep Steps** | The way in to the keep | The end. Whatever it was, it went in there. |

## Rules the builder follows

**Nothing on the path.** The route is drawn first and every building tests
against it, so the road is never blocked and never has to be un-blocked by hand.

**Nothing near a spawn.** Enemies arrive at fixed marks; a building on top of
one drops zombies inside a wall.

**Buildings face the path.** A door that opens onto a wall reads as generated.
Every entrance is turned toward the route, because that is where people walked.

**Ruin gets worse as you go in.** Chamber 1 is barricaded but standing; chamber
8 has a tower lying across it. The damage should read as a fight that moved in
one direction and lost ground the whole way.

**One folder per chamber**, and every building its own Model, so a whole house
can be grabbed and moved in one click.

**No two houses the same.** Buildings are assembled from independent traits
rather than picked from a handful of fixed shapes. See `HouseAnatomy.md` for what
those traits are and why the Rows deal from a shuffled deck instead of rolling.
