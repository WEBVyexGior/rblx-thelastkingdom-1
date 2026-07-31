# The Forgotten Lands — layout

The road home, in five stages. Each one answers a question the last one raised,
so a player who never reads a line of dialogue still learns the story by walking
it.

The castle is visible from the first step and from every stage after it. It is
the only fixed point in the world; everything else is what happened on the way
to it.

## The through-line

| Stage | z | What the player sees | What it tells them |
|---|---|---|---|
| **1 — Outskirts** | +200 → -110 | The rail line ends. A road, a cairn, a burned farm. | *Somebody made it this far, and stopped.* |
| **2 — Village** | -300 → -530 | Roofless houses, a barricaded square, a chapel with no bell. | *People lived here and they fought.* |
| **3 — Crossing** | -720 → -950 | A gorge, a broken bridge, watchtowers on both banks. | *They cut the bridge themselves. From this side.* |
| **4 — Siegeground** | -1140 → -1370 | Catapults, a ram, cairns in rows, the outer gate torn open. | *An army came, and it lost.* |
| **5 — Castle** | -1680 → -2100 | Walls breached, towers down, the keep split open. | *You are forty years too late.* |

## Stage notes

### 1 — Outskirts
The train from the Kingdom Hub arrives here, so the stage opens on rails and a
platform: the last piece of the world that still works. The road leaves it and
never comes back. A survivor's cairn and a leaning signpost sit at the first
objective; a burned farmhouse at the second. The palisade at the far end was
built in a hurry, from the wrong side — it was meant to keep something *out* of
the village, and it failed.

### 2 — Village
Two rows of houses down one street. None have roofs. Furniture is in the road,
not in the homes — it was dragged out to build barricades. The well in the
square is boarded over from above. The chapel is the only building with its
walls intact, which is its own kind of statement.

### 3 — Crossing
A gorge with water at the bottom. The bridge's centre span is gone and the cut
is clean — this was demolition, not decay, and the charges were set on the near
side. Whoever did it was trying to stop something crossing *toward* the castle.
It did not work. Planks have been thrown across since, by someone who came
after.

### 4 — Siegeground
The field before the castle, where the relief army died. Trebuchets face the
walls, still loaded. A ram lies short of the gate. The cairns are in rows,
which means someone had time to bury them — and then nobody had time to bury
the ones who did the burying.

### 5 — Castle
Two breaches in the curtain wall, one tower fallen and one leaning, the keep
opened at the top. Inside: a great hall with its roof gone, stables, a chapel,
and the courtyard where the last of it happened.

## Building order

Geometry is built from code (`tools/BuildWorld.luau`) so the whole route can be
reshaped by changing numbers. Props, torches, banners and set dressing are
placed by hand afterwards — that is where the world stops being a diagram.

Nothing in the generated structure should be treated as precious: it is a
skeleton to hang a world on.
