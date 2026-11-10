// Everything anyone says. Short: a line has to be read with a thumb busy.

export const LINES = {
  // Night 1
  n1_hello: "The robot built the app. It forgot the part that does anything. Tonight, the backend is you.",
  n1_press: "We're on the front page of Hubbub News. I did that. Me.",
  n1_scooter: "Scooter's at two percent. Which of these plugs isn't important?",
  n1_text1: "I'm at Nonna's. She says I'm \"not in the computer\".",
  n1_text2: "A queue of people at my door say they booked. With WHO?",
  n1_ledger: "I keep a ledger. Ink doesn't mind scooters. Show him: put three in the book yourself.",
  n1_nudge: "He copies what you do. Tap his rule so he waits, then drag three to the book.",
  n1_scooter2: "Scooter's dead again. Same plug?",
  n1_text3: "Again?! Buy a pen!",
  n1_kept: "The lights went out and every booking is still here. I may frame this page.",
  // Night 2
  n2_hello: "Deposits. Five dollars a head. The app fills in the total, which is thoughtful of it.",
  n2_text1: "lol. the app lets you type your own total. deposit: $0. telling everyone",
  n2_light: "Party of eight. Deposit: zero dollars. The till is... light.",
  n2_text2: "it SAID $0. you charged me $40??",
  n2_fixed: "Their phone, their lies. Your desk, your prices.",
  n2_never: "Someone sent a slip that said zero. You charged forty. I'm almost impressed.",
  n2_donation: "Let's call tonight's deposits a suggestion.",
  n2_cancel: "Cancellations. A slip says which table to free. That's all it says.",
  n2_loop: "Something is cancelling tables in numerical order. That's not a diner. That's a loop.",
  n2_stopped: "Now it asks the book whose table it is. The book says no. Good book.",
  n2_goodbook: "A bot is counting through table numbers. The book keeps saying \"not yours\". Good book.",
  n2_text3: "My table was CANCELLED? I didn't cancel anything!",
  // Night 3
  n3_hello: "New feature! Diners can ask the Model where to eat. It bills us a dollar a question.",
  n3_key: "That key is how the Model knows it's us. Us, and whoever's holding it.",
  n3_leak: "Someone three time zones away is writing wedding speeches on our key.",
  n3_lock: "They still have it. Changing the rule doesn't change the lock.",
  n3_again: "A brand new key, and the robot is handing it straight back out.",
  n3_cost: "That was ${n} of other people's questions.",
  n3_same: "They keep asking the same four things. We already paid for those answers...",
  n3_nudge: "The Model's answers are sticking to the board. Try dropping a question on the notes.",
  n3_text1: "FULL. No more tonight. Tell your computer.",
  n3_old: "That note is from before Nonna filled up. Tap it off the board.",
  n3_ttl: "Or give notes a shelf life, and the next one fixes itself.",
  n3_scooter: "Scooter.",
  n3_copies: "Every note gone, and nothing lost. They were only copies.",
  n3_notcopies: "The robot still keeps bookings on notes. Those weren't copies.",
  // Night 4
  n4_hello: "Launch night. Before anyone books, they all ask the same thing.",
  n4_out: "The article's out! Everybody grab a desk!",
  n4_desk: "I'm RIGHT here. Drag me to a desk.",
  n4_pages: "I can only turn pages so fast.",
  n4_queue: "{n} desks, one book. The queue's at Gerard.",
  n4_better: "Oh. That's... much better. I'm only writing now.",
  n4_shelf: "That list of free tables is from an hour ago. Shelf life. On the notes.",
  n4_fog: "Fog machine needs a socket. This one looks free.",
  n4_nobody: "He unplugged a whole desk. Nobody noticed.",
  n4_outage: "One desk. One plug. No Forkcast.",
  n4_clean: "Zero-dollar slips, a counting bot, a dead desk. Nothing got through.",
  n4_dirty: "At this speed, every shortcut you taught him is a firehose.",
  // The robot, on being shown
  learn_book_notes: "Watched you do it three times. I can do that. Faster.",
  learn_book_ledger: "The book. It's slower. ...Fine. The book.",
  learn_pay_stamp: "Stamp whatever the slip says. Efficient. I'd have done the same.",
  learn_pay_adder: "Work out every total here? Slow for you. Nothing for me.",
  learn_cancel_stamp: "Cancel on request, no questions. Very customer-centric.",
  learn_cancel_ledger: "Look up whose table it is first. Thorough.",
  learn_ask_key: "Put the key in the app and let the phones ask. Zero work for us. Elegant.",
  learn_ask_model: "Every question across this desk, a dollar each. As you wish.",
  learn_ask_notes: "Check the notes before paying for a new answer. I was about to suggest that.",
  learn_free_ledger: "Ask the book every single time. Always right.",
  learn_free_notes: "Read it off a note; ask the book when there isn't one. Got it.",
} as const;

export const KIND_NAME = { book: "Bookings", pay: "Deposits", cancel: "Cancellations", ask: "Questions", free: "\"What's free?\"" } as const;

/** What a rule chip says the robot does. */
export const RULE_NAME: Record<string, string> = {
  "book:notes": "sticky notes",
  "book:ledger": "the book",
  "pay:stamp": "trust the slip",
  "pay:adder": "work it out here",
  "cancel:stamp": "just do it",
  "cancel:ledger": "check whose it is",
  "ask:key": "hand out the key",
  "ask:model": "ask the Model",
  "ask:notes": "notes, then Model",
  "free:ledger": "ask the book",
  "free:notes": "notes, then book",
};

export const STATION_NAME = {
  notes: "Sticky notes",
  ledger: "The book",
  stamp: "Stamp it",
  adder: "Work it out",
  model: "The Model",
  key: "Hand over the key",
} as const;

/** The real name, stamped on a thing once the night has shown what it is. */
export const REAL_NAME = {
  notes: "MEMORY",
  ledger: "DATABASE",
  stamp: "UNCHECKED INPUT",
  adder: "VALIDATION",
  model: "AI MODEL (PAID API)",
  key: "API KEY",
} as const;

export type Term = { term: string; means: string };

/** After each night: what the things you just handled are called. */
export const TERMS: Term[][] = [
  [
    { term: "Memory", means: "The sticky notes. Instant, and wiped by every restart. Servers restart all the time: every update is one." },
    { term: "Database", means: "Gerard's book. Slower, and still there in the morning. Anything you'd be sorry to lose goes here." },
    { term: "Backend", means: "You, tonight. The app on the phone is the frontend: it asks. The backend answers and remembers." },
  ],
  [
    { term: "Request", means: "A slip. It's written on the diner's phone, so every word on it is whatever the diner wants it to say." },
    { term: "Server-side validation", means: "Working the total out at your desk. Slow by hand, free for a machine, so there's never a reason to skip it." },
    { term: "Authorization", means: "Asking the book whose table it is before touching it. Knowing a table's number isn't owning it." },
  ],
  [
    { term: "API key", means: "The key to a paid service. Anything you put in the app, every phone has. Keys stay at your desk." },
    { term: "Rotating a key", means: "Changing the lock. Once a key is out, hiding it again does nothing; only a new one does." },
    { term: "Cache", means: "The notes of old answers. A hit is free and instant. Losing them all costs nothing, because they're copies." },
    { term: "Stale, and TTL", means: "A copy goes on saying what was true. A time-to-live throws it away after a while, so it can't be wrong for long." },
  ],
  [
    { term: "Load balancer", means: "Ulrich, dealing slips to whichever desk is free." },
    { term: "Scaling out", means: "More desks doing the same job. It also means one can be unplugged and nobody notices." },
    { term: "Bottleneck", means: "The one thing everybody's waiting for. Usually it's the database. More desks don't shorten Gerard's queue." },
    { term: "Reads and writes", means: "Looking is most of the traffic and can come from a copy. Changing something has to go to the book." },
  ],
];

export type BriefLine = { ok: boolean; text: string; instead?: string };

/** The game's last screen: what the robot's rules amount to, as sentences
 * you'd put at the top of a request to a real AI. */
export function brief(rules: Record<string, string[] | undefined>, ttl: boolean, servers: number): BriefLine[] {
  const first = (k: string) => rules[k]?.[0];
  return [
    {
      ok: first("book") === "ledger",
      text: "Save every booking in the database. Server memory is only for copies we can afford to lose.",
      instead: "Your robot still keeps bookings in memory.",
    },
    {
      ok: first("pay") === "adder",
      text: "The server works out every price itself. Never trust a number the app sends.",
      instead: "Your robot still charges whatever the phone says.",
    },
    {
      ok: first("cancel") === "ledger",
      text: "Before changing anything, check on the server that it belongs to whoever is asking.",
      instead: "Your robot still cancels any table for anyone.",
    },
    {
      ok: first("ask") !== undefined && first("ask") !== "key",
      text: "API keys stay on the server; the app never sees one. If a key gets out, rotate it.",
      instead: "Your robot still hands the key to every phone.",
    },
    {
      ok: first("ask") === "notes" && ttl,
      text: "Cache the Model's answers to repeated questions, and give every cached copy an expiry.",
      instead: first("ask") === "notes" ? "Your notes never expire, so they go on being wrong." : "Your robot pays for the same four answers all night.",
    },
    {
      ok: first("free") === "notes",
      text: "The database is the bottleneck. Serve reads from a cache; every write still checks the real thing.",
      instead: "Your robot asks the one book for everything.",
    },
    {
      ok: servers >= 2,
      text: "Run at least two servers, so one can restart without anyone noticing.",
      instead: "You ran launch night on one desk.",
    },
  ];
}
