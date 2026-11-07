"""Generate the cast's close-ups and the backdrops.

Uses the Dunder Quest scenery helpers (the request and the pixel pass) from
../../dunder-quest/tools/generate_scenery.py, with this game's prompts. Reads
OPENROUTER_API_KEY and OPENROUTER_BASE_URL from the repo's .env and never
prints the key. Raw output lands in tools/generated/ (ignored by git and
Godot), pixel art in assets/portraits/ and assets/backgrounds/.

Everyone is an archetype with an invented name, drawn from their `look` in
data/season.json; nobody is drawn to look like a real person.

    python tools/art.py                 # generate everything missing
    python tools/art.py ricky garage    # just these
    python tools/art.py --install       # redo the pixel pass only
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import generate_scenery as base  # noqa: E402

RAW = HERE / "generated"
PORTRAITS = ROOT / "assets" / "portraits"
BACKGROUNDS = ROOT / "assets" / "backgrounds"
FACE = 48

FACE_STYLE = (
    "16-bit pixel art character close-up for the dialogue box of a comedy adventure game. Head and "
    "shoulders, facing the viewer, centred, the shoulders running off the bottom edge and the top of the "
    "head near the top edge. Big, simple, readable face: clear eyes, clear eyebrows, a clear mouth, bold "
    "dark outlines, flat shading, a limited palette. An invented original cartoon character who does not "
    "resemble any real person, actor or celebrity. Transparent background, nothing behind the character. "
    "No text, no letters, no logos, no watermark, no frame."
)

CAST = {
    # The incubator's owner: big, shaggy and smug, a loud patterned shirt.
    "ulrich": "A big, burly man in his thirties with shaggy brown hair, a full brown beard and a smug, "
              "self-satisfied half-smile, one eyebrow raised; a loud purple patterned short-sleeved shirt "
              "with an open collar.",
    # The founder: thin, anxious, curly-haired.
    "ricky": "A skinny, anxious young man in his twenties with a mop of curly light-brown hair, worried "
             "raised eyebrows and an uncertain grimace; a plain mid-blue zip hoodie over a grey t-shirt.",
    # The sysadmin: long black hair, beard, deadpan, all black.
    "gilroy": "A pale, deadpan man with long straight black hair past his shoulders, a full black beard, "
              "heavy-lidded unimpressed eyes and a flat mouth; a plain black t-shirt.",
    # The rival coder: neat short hair, a smirk.
    "danesh": "A young South Asian man with brown skin, short neat black hair, a thin moustache and a "
              "smug, competitive smirk; a rust-orange button-up shirt.",
    # Operations: neat, pale, earnest, a tie.
    "gerard": "A very pale, very polite man with neat, short, pale blond hair combed flat with a side "
              "parting, a long thin face and a gentle, earnest smile; a crisp white shirt buttoned up with "
              "a slim slate-grey tie.",
    # The associate: sharp, a bob, a blazer.
    "veronica": "A sharp, unimpressed young woman with a chin-length chestnut-brown bob, one eyebrow "
                "slightly raised, a small knowing smile; a navy blazer over a white top.",
    # The loud investor: spiky bleached hair, shades, a pink shirt.
    "chaz": "A tanned, loud, grinning man with spiky bleached-blond hair, black wraparound sunglasses and "
            "a huge toothy grin; a hot-pink shirt with the collar popped and a thin gold chain.",
    # The AI teammate: a monitor with a green face.
    "aleister": "Not a person: an old chunky beige computer monitor seen from the front, its black screen "
                "showing a simple bright green pixel face (two square eyes and a wide, eager smile), a "
                "short stand at the bottom. Looks eager and overconfident.",
    # The adult CEO: silver hair, a tan, a salesman's grin, a suit.
    "mack": "A tanned, confident man in his late fifties with neat, short silver hair, a firm jaw and a broad, "
            "polished salesman's grin; a navy suit jacket over a white shirt with a dark blue tie.",
    # The quiet investor: pale, still, unreadable.
    "walter": "A thin, very still man in his sixties with short, neat white hair, pale skin, wire-rimmed "
              "glasses and a blank, unreadable expression, mouth a straight line; a plain charcoal sweater "
              "over a grey collared shirt.",
    # The tech giant's guru CEO: serene, silver-flecked, expensively casual.
    "galen": "A lean, serene man in his fifties with short, swept-back greying hair and a neat salt-and-pepper "
             "beard, half-closed eyes and a calm, superior, beatific smile, as if forgiving you; an expensive "
             "oatmeal cashmere sweater over a white t-shirt, a thin string of wooden prayer beads at his wrist "
             "raised near his chin.",
    # The friend who fails upward: big curly hair, a vacant, contented smile, a hoodie.
    "melon": "A tall, gangly, sweet-natured young man in his twenties with a huge round mop of big curly "
             "dark-brown hair, sleepy, friendly half-open eyes and a relaxed, vacant, contented smile, as if "
             "nothing has ever worried him; a baggy faded olive-green hoodie over a white t-shirt.",
    # Ricky's date, a developer: calm, dry, long dark hair, a teal top.
    "wendy": "A calm, self-assured young woman in her twenties, a software developer, with long straight dark "
             "hair tucked behind one ear, thick dark eyebrows, one eyebrow raised in dry disbelief and a small "
             "patient smile; a teal knit sweater over a white collar, small silver earrings.",
}

STYLE = (
    "16-bit pixel art adventure game background, chunky readable shapes, limited palette, "
    "slightly shabby San Francisco startup comedy mood, no people, no animals, no text, "
    "no letters, no readable writing, no logos, no watermark, no UI."
)
ROOM = (
    "Flat side-on view of one room, like a stage set seen from the audience, camera at standing height. "
    "The bottom quarter of the frame is a plain, uncluttered floor and the furniture stands against the "
    "back wall; the interesting things are in the upper middle. Fills the whole frame: "
)

SCENES = {
    "garage": ROOM + (
        "a cluttered suburban garage turned into a startup office late at night. In the centre at the back "
        "a homemade server rack glowing hot orange, covered in blinking green and red lights and tangled "
        "cables, with a cheap desk fan on a stool pointed at it. Folding tables with laptops and energy "
        "drink cans, a whiteboard of boxes and arrows with no readable words, a roll-up garage door, "
        "bare fluorescent tubes, a concrete floor. Dim blue night light with green screen glow. " + STYLE
    ),
    "kitchen": ROOM + (
        "the kitchen of a shabby old Victorian house in San Francisco's Mission District that is used as a "
        "startup incubator, on a Sunday morning: old painted wooden cabinets, a tall bay window with "
        "morning sun and colourful Victorian houses across the street, a big wooden table with laptops, "
        "cereal boxes, coffee mugs and a stack of pizza boxes, a coffee maker, a fridge covered in sticky "
        "notes with no readable writing, worn wooden floorboards. Warm, bright and calm. " + STYLE
    ),
    "boardroom": ROOM + (
        "a sleek venture capital boardroom on a high floor in San Francisco's SoMa district: a long glossy "
        "dark wood table with leather chairs and glasses of water, floor-to-ceiling windows with the city and "
        "the Bay Bridge in grey morning light, and a huge wall-mounted screen showing a dashboard of "
        "colourful charts and tiles with no readable numbers or words, a tall potted plant. Cool, expensive "
        "and quiet. " + STYLE
    ),
    "keynote": ROOM + (
        "a tech giant's enormous keynote stage inside its glass-walled Silicon Valley campus hall: a wide, "
        "glossy black stage with a single minimalist white lectern, a giant curved screen behind it glowing "
        "with a calm gradient of sunrise orange and violet and an abstract swirl shape, no readable words or "
        "logos; a low zen rock garden and a bonsai tree at the edge of the stage, a meditation cushion, "
        "spotlights in a dark ceiling rig, rows of empty audience chairs in the foreground at the very "
        "bottom. Hushed, expensive, slightly cult-like. " + STYLE
    ),
    "hoststand": ROOM + (
        "the entrance of a busy little Italian trattoria in San Francisco's North Beach on a Friday evening, "
        "seen from just inside the door: a small wooden host stand in the centre with a reservation book, a "
        "brass lamp and an old beige computer box with blinking lights tucked under it, a chalkboard of "
        "specials with no readable writing, strings of warm bulbs, red-and-white checked tablecloths on full "
        "tables behind with candles in wine bottles, framed photos on brick walls, a coat rack. Warm, crowded, "
        "slightly chaotic dinner-rush glow. " + STYLE
    ),
    "lawfirm": ROOM + (
        "a corporate law firm's glass-walled conference room high in a San Francisco tower at night: a long "
        "pale wooden table with neat stacks of thick paper documents and binders, a speakerphone in the middle, "
        "high-backed black leather chairs, a wall of floor-to-ceiling shelves of identical leather-bound law "
        "books, a frosted glass wall, the city lights through a tall window, a cold blue overhead light. "
        "Hushed, expensive and intimidating. " + STYLE
    ),
    "conference": ROOM + (
        "the main stage of a big, loud startup conference in a convention-centre hall in San Francisco: a "
        "wide stage of grey carpet tiles under bright, harsh white and electric-blue stage lights; a huge wall "
        "of LED screens behind it glowing with an abstract pattern of magenta and cyan geometric blocks, no "
        "readable words, letters or logos; a small clear acrylic demo podium with an open laptop and a tangle "
        "of cables taped to the floor with gaffer tape; to one side a long judges' table with a black "
        "tablecloth, three empty swivel chairs, paper cups and water bottles; black speaker stacks and a "
        "lighting truss overhead; rows of cheap folding chairs at the very bottom, a few lanyards left on "
        "them. Bright, noisy, hurried and a little cheap, nothing like a calm corporate keynote. " + STYLE
    ),
    "livingroom": ROOM + (
        "the living room of a shabby old Victorian house in San Francisco's Mission District that is used as a "
        "startup incubator, late at night: a sagging brown leather sofa and mismatched armchairs facing a big "
        "wall-mounted TV that shows an enormous, absurdly complicated diagram of hundreds of tiny boxes and "
        "arrows glowing green, with no readable words; a coffee table buried in laptops, energy drink cans, pizza "
        "boxes and a tangle of cables; a tall bay window with the dark street and one streetlight outside; a "
        "worn rug, a fireplace with a mantel of odd trophies, a whiteboard leaning on the wall covered in boxes "
        "and arrows. Dim warm lamplight against the cold green glow of the screen. " + STYLE
    ),
    "interview": ROOM + (
        "a documentary interview set, years later, in a calm, tidy, sunlit room: a single empty modern armchair "
        "in the centre angled slightly toward the viewer, a softbox light on a stand to one side and a small "
        "camera on a tripod at the edge, a tall leafy plant, a low shelf with a few books and one framed photo "
        "of a shabby Victorian house, a softly blurred window with afternoon light behind. Quiet, warm, "
        "reflective, the look of a documentary where people look back on a company. " + STYLE
    ),
    "movein": ROOM + (
        "the living room of a shabby old Victorian house in San Francisco's Mission District on move-in day, "
        "a bright Monday morning: a battered suitcase and a stack of cardboard moving boxes by the door, a "
        "sagging brown leather sofa with a bathrobe thrown over its arm, a coffee table with an old beige "
        "computer monitor showing a simple green pixel smiley face, a blank whiteboard on an easel, a tall bay "
        "window full of morning sun and colourful Victorian houses across the street, a worn rug, a fireplace "
        "with a mantel of odd trophies. Hopeful, scruffy and sunny. " + STYLE
    ),
    "roof": ROOM + (
        "the flat roof terrace of a gleaming tech giant's glass office building in Silicon Valley on a sunny "
        "afternoon: a row of identical expensive white lounge chairs facing nowhere in particular, small side "
        "tables with untouched fruit-infused water and a bowl of oranges, potted olive trees and neat artificial "
        "grass, a glass safety railing, a big blue sky, the campus's other glass buildings and a car park "
        "stretching away below. Pleasant, pointless and eerily calm, like a place where people are paid to wait. "
        + STYLE
    ),
    "whiteboard": ROOM + (
        "the living room of a shabby old Victorian house in San Francisco's Mission District used as a startup "
        "incubator, very late at night: in the centre a big whiteboard on an easel covered in a crude marker "
        "drawing of a phone, arrows and a box, with no readable words or letters; marker pens and an open "
        "laptop on a coffee table with takeaway noodle cartons and mugs; a sagging sofa; a tall bay window, "
        "dark outside with one streetlight; a floor lamp throwing a warm pool of light, everything else in "
        "blue shadow. Tired, scrappy, two-in-the-morning energy. " + STYLE
    ),
    "party": ROOM + (
        "a house party in the big living room of a shabby old Victorian house in San Francisco's Mission District "
        "used as a startup incubator, on a Saturday night, with the guests just out of frame: strings of fairy "
        "lights and colourful paper lanterns across the ceiling, a makeshift DJ table with a laptop and speakers, "
        "a folding table of snacks, cups and a punch bowl, a projector beam throwing a bright plain green glow "
        "on the wall above the fireplace, balloons, a disco ball, the bay window dark with the city lights "
        "outside. Loud, warm, a little too much. " + STYLE
    ),
    "argument": ROOM + (
        "the living room of a shabby old Victorian house in San Francisco's Mission District used as a startup "
        "incubator, at two in the morning in the middle of an argument: two rival desks pushed to opposite ends "
        "of the room, each with a glowing laptop and a big monitor full of coloured code lines with no readable "
        "words, a strip of masking tape across the worn rug dividing the room in two, a whiteboard on an easel "
        "split down the middle by a thick marker line with scribbled boxes on each side and no readable words, "
        "energy drink cans and cold coffee mugs, a sagging sofa in the middle, a tall bay window dark outside "
        "with one streetlight. Cold blue screen glow against one warm lamp. Tense and petty. " + STYLE
    ),
    "pitch": ROOM + (
        "a quiet, expensive venture capital partners' meeting room in San Francisco on a bright afternoon: a "
        "long pale oak table with a few phones lying on it face up, their screens glowing with a simple app of "
        "green buttons and cards with no readable words, glasses of water and neat notepads, white leather "
        "chairs, a big wall screen showing a single plain green slide with no words, minimalist abstract "
        "art, a tall window onto the city and the bay. Calm, sparse, intimidating, money in the air. " + STYLE
    ),
    "spreadsheet": ROOM + (
        "a corner of a shabby old Victorian house in San Francisco's Mission District used as a startup "
        "incubator, on a Monday morning: one immaculately tidy desk against the back wall, with a huge monitor "
        "filled edge to edge by a colourful spreadsheet grid of thousands of tiny cells in teal, yellow and pink "
        "with no readable writing, a second laptop showing the same grid, neat labelled box files, a row of "
        "perfectly aligned pens, a printed stack of grid pages with coloured tabs, a cold cup of tea, a small "
        "potted succulent, a wall calendar with every day crossed off, a tall window with grey morning light. "
        "Orderly to the point of worrying. " + STYLE
    ),
    "breach": ROOM + (
        "the kitchen of a shabby old Victorian house in San Francisco's Mission District used as a startup "
        "incubator, early on a Monday morning, the morning a data breach is on the news: a big wooden table with "
        "several open laptops whose screens glow with a red warning banner and a padlock icon with no readable "
        "writing, a phone on the table lit up red, a small wall television showing a red news ticker with no "
        "readable words, cold coffee mugs, a half-eaten bowl of cereal, a tall bay window with flat grey "
        "dawn light. Uneasy red glow against the grey. " + STYLE
    ),
    "focusgroup": ROOM + (
        "the big living room of a shabby old Victorian house in San Francisco's Mission District used as a "
        "startup incubator, just after a consumer focus group has left: a half circle of mismatched folding "
        "chairs facing a wall screen showing a plain login box with no readable words, a few borrowed tablets "
        "and phones left on the chairs, a folding table of open pizza boxes and paper cups, a flip chart with "
        "scribbled sticky notes and no readable writing, a sagging sofa pushed to the side, a tall bay window "
        "with evening light. Warm, a little forlorn. " + STYLE
    ),
    "launch": ROOM + (
        "the overgrown back garden of a shabby old Victorian house in San Francisco's Mission District, dressed "
        "for an absurdly lavish startup launch party on a sunny Saturday afternoon, before the guests arrive: in "
        "the centre an enormous, gleaming ice sculpture of a big bearded man in a robe holding up a giant fork and "
        "gazing into the distance, on a draped table; a huge arch of hundreds of green and white balloons over a "
        "patio; a DJ booth with towering speakers; a tall pyramid tower of champagne glasses; a big outdoor screen "
        "on a stand showing a simple white fork icon on a dark slate background, no words; strings of party lights between a lemon tree "
        "and the back porch, a peeling clapboard wall and a sagging fence behind. Extravagant and obviously far "
        "more than anyone can afford. " + STYLE
    ),
    "aftermath": ROOM + (
        "the overgrown back garden of a shabby old Victorian house in San Francisco's Mission District at two in "
        "the morning after an absurdly lavish startup launch party: a half-melted ice sculpture of a big man holding "
        "up a giant fork, its head fallen off and lying on the table in a puddle; a sagging, half-deflated arch of "
        "green and white balloons with loose balloons drifting on the grass; a DJ booth switched off; a toppled "
        "tower of champagne glasses and empty bottles; a big outdoor screen on a stand still showing a simple white fork icon on a dark slate "
        "background, no words; strings of party lights, some out; paper cups everywhere; a dark sky with the city glow. "
        "Quiet, deflated, funny. " + STYLE
    ),
    # The web Pilot's main set: the cast walk about on its floor and argue.
    "den": ROOM + (
        "the big living room of a shabby old Victorian house in San Francisco's Mission District used as a "
        "startup incubator, on a bright weekday afternoon. On the left a big whiteboard on wheels, wiped "
        "almost clean with faint smudges; in the middle at the back a sagging brown leather sofa under a tall "
        "bay window with colourful Victorian houses across the street; on the right a big wall-mounted TV, "
        "switched off and dark, above a low cabinet with a games console and tangled cables; a worn rug, "
        "potted plants, a beanbag, a mantel of odd trophies, a hallway door. The floor across the whole "
        "bottom third is bare, worn wooden floorboards with nothing on it, room for people to stand. Warm, "
        "sunny and scruffy. " + STYLE
    ),
    "house": (
        "Key art for a pixel-art comedy game title screen: the outside of a slightly run-down painted "
        "Victorian house on a steep San Francisco street in the Mission District at dusk, pale grey-green "
        "paint with white trim, a bay window glowing warm, a garage door at street level leaking green "
        "light, a palm tree, overhead wires, the downtown skyline faint in the distance under a pink and "
        "teal evening sky. Keep the middle of the frame calm and plain so a title can sit on top. No people. "
        + STYLE
    ),
}


def install(name: str) -> None:
    raw = Image.open(RAW / f"{name}.png").convert("RGBA")
    if name in CAST:
        box = raw.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox() or (0, 0, *raw.size)
        # Square up around the figure, anchored to the bottom edge.
        side = max(box[2] - box[0], box[3] - box[1])
        cx = (box[0] + box[2]) // 2
        crop = raw.crop((cx - side // 2, box[3] - side, cx - side // 2 + side, box[3]))
        art = base.pixelate(crop, (FACE, FACE), 24, True)
        out = PORTRAITS
    else:
        # Opaque, so it keeps as a 48-colour palette PNG.
        art = base.pixelate(raw, (480, 270), 48, False).convert("RGB").quantize(48, dither=Image.Dither.NONE)
        out = BACKGROUNDS
    out.mkdir(parents=True, exist_ok=True)
    art.save(out / f"{name}.png", optimize=True)
    print("installed", name, flush=True)


def generate(name: str, url: str, key: str) -> str:
    if name in CAST:
        image = base.request_image(url, key, CAST[name] + " " + FACE_STYLE, "1:1", True)
    else:
        image = base.request_image(url, key, SCENES[name], "16:9", False)
    RAW.mkdir(parents=True, exist_ok=True)
    (RAW / ".gdignore").touch()
    image.save(RAW / f"{name}.png")
    install(name)
    return name


def target(name: str) -> Path:
    return (PORTRAITS if name in CAST else BACKGROUNDS) / f"{name}.png"


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or [n for n in list(CAST) + list(SCENES) if not target(n).exists()]
    if "--install" in sys.argv:
        for name in names:
            install(name)
        return
    env = base.load_env()
    url = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    key = env.get("OPENROUTER_API_KEY", "")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(generate, name, url, key): name for name in names}
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:  # noqa: BLE001
                print("failed", futures[future], str(exc)[:300].replace(key, "[REDACTED]"), flush=True)


if __name__ == "__main__":
    main()
