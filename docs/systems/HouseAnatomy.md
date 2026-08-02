# What makes a house read as medieval

Notes behind the building library in `tools/BuildChambers.luau`. The companion to
`TowerAnatomy.md`, and written for the same reason: a box with a triangle on top
reads as a box with a triangle on top.

## The one that matters most

**The jetty** — the upper floor projecting out past the lower one, carried on the
ends of the floor joists and a bressummer beam under them.

It is worth naming separately because it does more than any other single feature
here. It breaks the vertical box, it throws a hard shadow line across the front
at first-floor height, and it is the silhouette people already associate with the
period without being able to say why. A street of jettied houses reads as
medieval from a distance at which no amount of stonework detail is visible at
all.

## Bottom to top

| Part | What it is | Why it matters |
|---|---|---|
| **Plinth** | Stepped, splayed masonry foot | Same job as a tower's batter: keeps damp and boots off the wall. |
| **Drip mould** | A projecting band where plinth meets wall | Throws water clear of the joint. One part, and the foot stops looking extruded. |
| **Masonry ground floor** | Stone, full storey height | The ground floor was stone even when everything above was timber. It is why the ground floor is the part still standing. |
| **String course** | A band at the floor line | On an all-stone house it is the only outside evidence of a second storey. |
| **Bressummer** | The beam under the jetty | The thing actually carrying the overhang. |
| **Joist ends** | Beam ends poking out beneath it | The *reason* for the jetty. Without them the upper floor is floating. |
| **Brackets** | Carved braces at the jetty corners | Where a carpenter showed off, because it was at eye level. |
| **Timber frame** | Sill, posts, head, alternating braces | Braces alternate direction bay to bay, the way a real frame is trussed. |
| **Wattle & daub** | Plaster panels between the timbers | Where the plaster has fallen, the woven wattle behind it shows. That patchiness is most of what reads as *old* on a timber wall. |
| **Mullions** | Stone bars dividing a window into lights | The difference between a window and a hole. |
| **Hood mould & label stops** | A drip band over the opening, with stops at its ends | Sheds water off the head. Stops are the cheapest "somebody carved this" signal there is. |
| **Iron bars** | On ground-floor windows only | Upper windows are out of reach and never barred. |
| **Segmental relieving arch** | A shallow arch over the door lintel | Carries the wall's weight around the lintel so it does not snap. Segmental, not semicircular — see below. |
| **Strap hinges** | Iron straps running most of the way across the door | The single most recognisable piece of door ironwork. |
| **Studded boards** | Vertical boards, ledged behind, studded through | Doors were boards, not slabs. |
| **Gable framing** | Herringbone bracing in the gable triangle | Decoration put where the whole street could see it. |
| **Verge & barge boards** | Trim along the roof edges | Finishes the roof. A roof without them ends in mid-air. |
| **Ridge tiles** | A capping run along the ridge | The join two slopes make has to be covered by something. |
| **Dormer** | A window standing out of the roof slope | How an attic gets light, and what makes a 1.5-storey house read as lived in. |
| **Chimney stack** | On the gable end, with a capped flue | Belongs on the end wall, not the middle of the roof. |
| **Lean-to** | A single-slope shed against a side wall | Woodstore, privy, workshop. Breaks the rectangle. |
| **Trade sign** | A board on an iron bracket, with a device | Tells you what a building *was*. No amount of stonework does that. |
| **Water butt** | A hooped barrel under the eaves | Catches what the roof sheds. Says somebody lived here. |
| **Tie plates** | Small iron crosses on the front | Tie rods holding the floors in, exactly as on the towers. |
| **Cellar hatch** | A timber hatch in the ground beside the door | Deliveries went down, not through the house. |

## Roof shapes

Four, and the reason there are four is that **the roofline is what the eye
compares at a distance**. A yard where every roof is the same gable reads as one
house copied, however different the walls below it are.

| Shape | What it is |
|---|---|
| `gable` | Two slopes, vertical triangular ends. The default. |
| `hipped` | Four slopes, no gable. Reads older and squatter. |
| `halfhip` | A gable with its top corner cut back. |
| `catslide` | One slope run down much further than the other, usually over a lean-to. |

Gables belong on the ends the **ridge** points at. The ridge runs along the
house's local X, so the gables stand at ±X, spanning the depth. Building them on
the wrong axis draws both gables in the same place across the front — a wall
where a roof should be.

## Two things that have to agree with the storey height

Both of these were wrong first time, and both were invisible in code and obvious
in the viewport:

**The door has to fit the wall it is cut into.** An eleven-stud door with its
lintel and relieving arch needs about sixteen studs of masonry. Written as fixed
numbers it fitted the house it was written against and nothing else. Door and
window heights are now fractions of the storey.

**A semicircular relieving arch is too tall for a doorway.** Over a six-stud
opening it rises more than four studs on its own — a third of a storey — and
comes out through the floor above. Segmental is both shorter and the commoner
medieval form over a door. Given a span and a rise, the radius follows:
`R = (s²/4 + r²) / 2r`.

## Ruin

Same principle as the towers: a ruined house is not a shorter house.

- **Damage falls on a side**, not evenly. Randomising every wall equally gives a
  building that has been uniformly nibbled; picking a side — front, back, corner,
  or roof only — gives one that was *hit*.
- The **front wall survives longest**: it was the thickest, and it faced the road.
- The **roof goes first**, and goes in patches. A whole roof and a bare frame are
  both wrong; a roof half on is what forty years leaves.
- What came down is **lying inside**: fallen rafters, slipped tiles.
- With a wall down, the **hearth is visible from the street**. It is the heaviest
  thing in the house and the last to fall.

## Variety

The complaint that started this was that too many houses looked the same, and the
cause was structural: three fixed functions give three silhouettes however much
the numbers move.

The library is now one `house()` assembled from independent traits — storeys,
jetty, roof shape, wall build, roof covering, ruin depth, which side took the
damage, trade, lean-to, door state. The combinations run into the thousands.

Two ways to get a house out of it, and the choice matters:

- **`rollHouse`** rolls the traits independently. Right for background wreckage,
  where the silhouette is doing the work.
- **A written-out spec** for anything the player walks past. The Rows deal from a
  **shuffled deck of seven hand-written houses** rather than rolling seven times,
  because independent rolls *can* repeat — and on a street of seven, two
  identical neighbours is exactly the repetition you notice. A shuffled deck
  cannot repeat, and shuffling means the street is never memorised either.
