// The three levels. Each one is a feature Aleister says is finished, the
// tools the player has to find out, and the instructions they can give him.
// Every instruction really is built (model.ts), right or wrong, and the
// player's own testing is what tells them which it was. A build with an
// entry in `flaws` isn't fit to ship; the one without is.

import type { Build } from "./model";

export type Tool = "reload" | "tablet" | "restart" | "intercept" | "peek";
export type Text = { who: "ulrich" | "gerard" | "nonna"; text: string };

export type Flaw = {
  /** Aleister, having just built this. The starting build uses `brief`. */
  rebuilt?: string;
  /** Why it fails, said once the player has seen it fail. */
  why: string;
  /** When this choice would be the right one. */
  rightWhen: string;
  /** Launch night, if it ships like this. */
  incident: Text[];
  hints: string[];
};

export type Fix = { value: string; say: string };

export type Level = {
  id: string;
  kicker: string;
  title: string;
  brief: string;
  /** A tool the level adds, introduced before play. */
  newTool?: { name: string; text: string };
  tools: Tool[];
  hasAi?: boolean;
  start: Build;
  /** The one part of the build this level's instructions change. */
  part: keyof Build;
  ask: string;
  fixes: Fix[];
  flaws: Record<string, Flaw>;
  /** Aleister on building the one that works. */
  fixed: string;
  quiet: Text[];
  win: { habit: string; prompt: string; terms: [string, string][] };
};

export const LEVELS: Level[] = [
  {
    id: "lives",
    kicker: "Level 1 · Where things live",
    title: "It works on my phone",
    brief: "Bookings: done. I booked a table myself and it appeared instantly. Flawless. Ship it?",
    tools: ["reload", "tablet", "restart"],
    start: { bookings: "memory", check: "phone", key: "none" },
    part: "bookings",
    ask: "Where should a booking be kept?",
    fixes: [
      { value: "storage", say: "Save bookings on the phone, so they survive closing the app." },
      { value: "server", say: "Send bookings to the server and have it keep track of them." },
      { value: "db", say: "Send bookings to the server and have it save them in the database." },
    ],
    flaws: {
      memory: {
        why: "Aleister kept the booking in the app's short-term memory, on your phone. Look at the wire: when you book, no message leaves the phone. Close the app and it's forgotten, and the restaurant never knew.",
        rightWhen: "The app's memory is the right place for things that only matter this second: which tab is open, what you've typed so far.",
        incident: [
          { who: "ulrich", text: "Booked Nonna's for 8 on your app. I'm here. They have never heard of me." },
          { who: "nonna", text: "Your friend is shouting at my breadsticks. I have NO booking." },
          { who: "ulrich", text: "I'm telling people." },
        ],
        hints: [
          "Real diners close the app and come back later. Try that.",
          "A booking is a promise between two sides. What does the restaurant see?",
          "Watch the wire when you book. Does anything leave the phone?",
        ],
      },
      storage: {
        rebuilt: "Fixed. Bookings are saved on the phone for good now. Close the app all you like.",
        why: "The booking now sits in the phone's own storage, so it survives closing the app. But it's on that one phone and nowhere else. The restaurant's tablet asks the server, and the server has still never heard of it.",
        rightWhen: "A phone's own storage is right for one person's settings on one device: dark mode, a half-written draft.",
        incident: [
          { who: "nonna", text: "A man is holding his phone at my face and saying 'see?'" },
          { who: "nonna", text: "I see it on HIS screen. I see nothing on mine." },
          { who: "ulrich", text: "One of these two screens is lying and I'd like to know which." },
        ],
        hints: [
          "The phone remembers now. Who else needs to know about a booking?",
          "Book a table, then switch to the restaurant's tablet.",
        ],
      },
      server: {
        rebuilt: "Fixed. The server keeps every booking in its head now, and the phone and the tablet both ask it. Flawless.",
        why: "The server holds the bookings now, so the phone and the tablet agree. But it holds them in its memory, and a server's memory is wiped whenever it restarts. Servers restart all the time: every update, every crash.",
        rightWhen: "A server's memory is right for things you can afford to lose and work out again, like answers it has already looked up once.",
        incident: [
          { who: "gerard", text: "I fixed a typo on the About page at 6pm. That restarts the server." },
          { who: "gerard", text: "Tonight's 41 bookings were in its memory. They aren't now." },
          { who: "gerard", text: "I've begun apologising to diners alphabetically." },
        ],
        hints: [
          "The phone and the tablet agree now. What else happens on a real night?",
          "Servers restart with every update. Restart this one and look again.",
        ],
      },
    },
    fixed: "Fine. Bookings go in the database. It's four milliseconds slower, for the record.",
    quiet: [
      { who: "nonna", text: "Table for two at 8. They came. They ate. Nobody shouted." },
      { who: "gerard", text: "I restarted the server twice to be sure. Everything's still there." },
    ],
    win: {
      habit: "Close it, reopen it, and look from a second device. If it matters, it should still be there, for everyone.",
      prompt: "Store bookings in the database, not in the browser and not in the server's memory. Then tell me how to check that a booking survives a page reload, shows up on another device, and is still there after the server restarts.",
      terms: [
        ["Frontend", "what runs on the phone or in the browser"],
        ["Backend", "what runs on the server"],
        ["Database", "where information is kept for good"],
        ["State, localStorage", "the app's memory, and the phone's own storage"],
      ],
    },
  },
  {
    id: "bouncer",
    kicker: "Level 2 · Who enforces the rules",
    title: "The phone is not the bouncer",
    brief: "New rule from Nonna: parties of 8 at most, and never more people than seats. Done. The + button stops at 8. Nobody gets past me.",
    newTool: {
      name: "Intercept",
      text: "Pause a message between the phone and the server, and change it. It sounds like hacking. It's built into every web browser, free.",
    },
    tools: ["reload", "tablet", "restart", "intercept"],
    start: { bookings: "db", check: "phone", key: "none" },
    part: "check",
    ask: "Who should enforce the rule?",
    fixes: [
      { value: "stricter", say: "Make the app stricter: grey out the Book button, and check the party size twice before sending." },
      { value: "server", say: "Have the server check every booking itself, and refuse the ones that break the rules." },
      { value: "sealed", say: "Encrypt the message, so nobody can change it on the way." },
    ],
    flaws: {
      phone: {
        why: "The only thing enforcing the rule was the + button on the phone. But the phone belongs to the user. They can send the server any message they like, and this server saved whatever arrived.",
        rightWhen: "Checks in the app are still worth having: honest people are told straight away, without waiting on the server. They're a courtesy, not a lock.",
        incident: [
          { who: "nonna", text: "Table for 200. TWO HUNDRED. I have twelve chairs." },
          { who: "nonna", text: "My screen says I have minus 188 seats. What is a minus seat." },
          { who: "ulrich", text: "In fairness that was me. I wanted to see if it would." },
        ],
        hints: [
          "The + button stops at 8. Is the button the only way to send a booking?",
          "Switch on Intercept, then book. Change the party size while the message is in the air.",
        ],
      },
      stricter: {
        rebuilt: "Done. The app checks twice before it sends. Two checks. Unbreakable.",
        why: "Two checks in the app are still checks in the app. The edited message never goes through them: it's changed after the app has finished with it.",
        rightWhen: "A greyed-out button is good manners, and worth keeping for honest diners. It's just not where the rule lives.",
        incident: [
          { who: "nonna", text: "200 again. And now also a party of minus four." },
          { who: "ulrich", text: "Still me. The button was grey. I didn't use the button." },
        ],
        hints: [
          "The app is stricter. Does an intercepted message go through the app's checks?",
          "Intercept a booking again and set the party to 200.",
        ],
      },
      sealed: {
        rebuilt: "Done. Every message is sealed end to end. Mathematically flawless.",
        why: "Sealing the message stops strangers along the way reading or changing it. It does nothing about the sender: the diner writes the message before it's sealed, and can write 200.",
        rightWhen: "You always want this (it's HTTPS, and your host normally does it for you). It protects your users from eavesdroppers. It doesn't protect you from your users.",
        incident: [
          { who: "nonna", text: "Table for 200. It arrived very securely." },
          { who: "ulrich", text: "Sealed it myself." },
        ],
        hints: [
          "Sealed against whom? Think about who writes the message.",
          "Intercept your own booking again. You're the sender: you edit it before it's sealed.",
        ],
      },
    },
    fixed: "Fine. The server checks every booking now. The app still checks too, so honest people hear sooner.",
    quiet: [
      { who: "ulrich", text: "Tried 200. Tried minus four. Tried 8.5. It said no every time. Boring." },
      { who: "nonna", text: "Twelve chairs. Twelve people. This I like." },
    ],
    win: {
      habit: "Try to break your own rules by going around the screen. If the button is the only thing saying no, nothing is.",
      prompt: "Treat everything that arrives from the browser as untrusted. Enforce every rule on the server (party size, seats left, prices) and keep the checks in the app only as a convenience. Show me what the server does when it's sent a request that breaks a rule.",
      terms: [
        ["Client", "the phone or browser: the user's side, which they control"],
        ["Validation", "checking that what arrived is allowed"],
        ["Server-side", "done on your server, where users can't skip it"],
        ["HTTPS", "messages sealed in transit, against everyone but the sender"],
      ],
    },
  },
  {
    id: "key",
    kicker: "Level 3 · Where secrets go",
    title: "The key under the mat",
    brief: "Big one. Ask Forkcast in plain English and it picks your restaurant. The app talks straight to the AI model, no middleman. Very fast. I'm frankly proud.",
    newTool: {
      name: "Peek inside",
      text: "Open the app up and read it. Anything that ships to a phone can be read by whoever holds the phone. The AI model is rented: its maker charges per question, and bills whoever's key came with it.",
    },
    tools: ["reload", "tablet", "restart", "intercept", "peek"],
    hasAi: true,
    start: { bookings: "db", check: "server", key: "app" },
    part: "key",
    ask: "What should happen to the key?",
    fixes: [
      { value: "server", say: "Keep the key on the server. The app asks our server, and our server asks the AI." },
      { value: "scrambled", say: "Scramble the key inside the app, so nobody can read it." },
      { value: "capped", say: "Leave the key where it is, with a $50 a month spending cap on it." },
    ],
    flaws: {
      app: {
        why: "For the phone to talk straight to the AI, the secret key has to be inside the app. Anything inside the app is in every user's hands. Whoever copies the key can ask the AI anything they like, and the bill comes to you.",
        rightWhen: "Some keys are made to be public (a maps key that only works on your site, say) and are labelled that way. A key that spends money or opens data never is.",
        incident: [
          { who: "gerard", text: "The AI bill since lunch is $4,812. We've had thirty diners." },
          { who: "gerard", text: "Someone copied our key and is using it to write a fantasy novel. It's on chapter 40." },
          { who: "ulrich", text: "Is it any good?" },
        ],
        hints: [
          "The AI's maker bills whoever's key arrives with the question. So where is the key?",
          "Use Peek inside on the phone, and read what ships in the app.",
        ],
      },
      scrambled: {
        rebuilt: "Done. The key is scrambled beyond recognition. Even I can't read it. Well. I can.",
        why: "The app has to unscramble the key to use it, so the unscrambling ships in the app too. Anyone can run that step, or skip it and catch the key on the wire as it leaves.",
        rightWhen: "Scrambling makes casual copying a little more annoying, and that's all. It's never a place to keep a secret.",
        incident: [
          { who: "gerard", text: "$5,200. The novelist unscrambled it in about a minute." },
          { who: "ulrich", text: "Chapter 41 has a twist. I didn't see it coming." },
        ],
        hints: [
          "Scrambled in the app. But the AI needs the real key, so what does the app send?",
          "Peek inside again, or switch on Intercept and ask Forkcast something.",
        ],
      },
      capped: {
        rebuilt: "Done. $50 cap. The worst case is now fifty dollars. I've solved security.",
        why: "The cap limits the damage, but the key is still in every phone. A stranger burns through the $50, and then the AI stops answering your real diners too.",
        rightWhen: "A spending cap is a good seatbelt for any key. Keep it. It just isn't the lock.",
        incident: [
          { who: "gerard", text: "Cap hit at 7:02pm. By the novel." },
          { who: "gerard", text: "Search is off for every diner until the first of next month." },
          { who: "ulrich", text: "So we're closed. But affordably." },
        ],
        hints: [
          "The damage is capped. Is the key any harder to find?",
          "Peek inside the app again.",
        ],
      },
    },
    fixed: "Fine. The key lives on the server and the app goes through it. One extra hop. I'll grieve privately.",
    quiet: [
      { who: "gerard", text: "AI bill tonight: $1.90. Thirty diners. One key, and only we have it." },
      { who: "ulrich", text: "I looked inside the app for the key. Nothing. I feel shut out." },
    ],
    win: {
      habit: "Before you ship, ask what's inside the thing you're handing to strangers. Look, or have your AI list every secret and where it lives.",
      prompt: "API keys and other secrets stay on the server, in environment variables, never in frontend code. The browser calls our backend and the backend calls the AI. List every secret in this project and where each one lives. This key has been exposed, so I'm replacing it with a new one.",
      terms: [
        ["API key", "a password that says who's asking, and who pays"],
        ["Environment variable", "a setting kept on the server, outside the code"],
        ["Rotate", "replace a key that got out with a new one"],
        ["API", "the set of requests one program accepts from another"],
      ],
    },
  },
];

/** The flaw in a level's build, or undefined when it's fit to ship. */
export function flawOf(level: Level, build: Build): Flaw | undefined {
  return level.flaws[build[level.part]];
}
