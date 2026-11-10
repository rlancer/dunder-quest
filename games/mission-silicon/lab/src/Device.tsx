// What people hold: the diner's phone running Forkcast, and the tablet at
// the restaurant's host stand. Both draw only what the world gives them.

import { useState } from "react";
import {
  MAX_PARTY, QUESTIONS, RESTAURANTS, phoneBookings, restaurant, seatsLeft, tabletBookings, type World,
} from "./model";

type Props = {
  world: World;
  view: "phone" | "tablet";
  busy: boolean;
  hasAi: boolean;
  onView: (view: "phone" | "tablet") => void;
  onBook: (id: string, party: number) => void;
  onAsk: (qid: string) => void;
};

export function Device(props: Props) {
  const { world, view, busy } = props;
  return (
    <section className="device" aria-label="The app">
      <div className="tabs" role="tablist">
        <button role="tab" aria-selected={view === "phone"} disabled={busy} onClick={() => props.onView("phone")}>
          Your phone
        </button>
        <button role="tab" aria-selected={view === "tablet"} disabled={busy} onClick={() => props.onView("tablet")}>
          Restaurant's tablet
        </button>
      </div>
      <div className={busy ? "screen busy" : "screen"}>
        {view === "phone" ? <Phone {...props} /> : <Tablet world={world} />}
      </div>
    </section>
  );
}

function Phone({ world, busy, hasAi, onBook, onAsk }: Props) {
  const [open, setOpen] = useState<string | null>(null);
  const [party, setParty] = useState(2);
  const mine = phoneBookings(world);
  return (
    <>
      <div className="apphead"><b>Forkcast</b><span>Hungry?</span></div>
      {hasAi && (
        <div className="askbox">
          <p className="label">Ask Forkcast</p>
          {QUESTIONS.map((q) => (
            <button key={q.id} className="chip" disabled={busy} onClick={() => onAsk(q.id)}>{q.ask}</button>
          ))}
          {world.ai.answer && <p className="answer">{world.ai.answer}</p>}
        </div>
      )}
      <p className="label">Tonight</p>
      <ul className="places">
        {RESTAURANTS.map((r) => {
          const left = seatsLeft(world, r.id, "phone");
          const most = Math.min(MAX_PARTY, left);
          const size = Math.min(party, Math.max(most, 1));
          return (
            <li key={r.id}>
              <div className="row">
                <div>
                  <b>{r.name}</b>
                  <small>{r.blurb} {left} seats left.</small>
                </div>
                {open !== r.id && (
                  <button className="btn mini" disabled={busy || left < 1} onClick={() => { setOpen(r.id); setParty(2); }}>
                    {left < 1 ? "Full" : "Book"}
                  </button>
                )}
              </div>
              {open === r.id && (
                <div className="picker">
                  <button className="step" aria-label="Fewer" disabled={size <= 1} onClick={() => setParty(size - 1)}>−</button>
                  <span aria-live="polite">{size}</span>
                  <button className="step" aria-label="More" disabled={size >= most} onClick={() => setParty(size + 1)}>+</button>
                  <button
                    className="btn mini go"
                    disabled={busy || most < 1}
                    onClick={() => { setOpen(null); onBook(r.id, size); }}
                  >
                    Book for {size}
                  </button>
                </div>
              )}
            </li>
          );
        })}
      </ul>
      <p className="label">Your bookings</p>
      {mine.length === 0 ? <p className="none">None yet.</p> : (
        <ul className="booked">
          {mine.map((b) => <li key={b.id}>{restaurant(b.restaurant).name}, party of {b.party}</li>)}
        </ul>
      )}
    </>
  );
}

function Tablet({ world }: { world: World }) {
  const all = tabletBookings(world);
  return (
    <>
      <div className="apphead host"><b>Host stand</b><span>Tonight</span></div>
      <p className="label">Bookings from Forkcast</p>
      {all.length === 0 ? <p className="none">No bookings tonight.</p> : (
        <ul className="booked">
          {all.map((b) => <li key={b.id}>#{b.id} {restaurant(b.restaurant).name}, party of {b.party}</li>)}
        </ul>
      )}
      <p className="label">Seats left</p>
      <ul className="booked plain">
        {RESTAURANTS.map((r) => {
          const left = seatsLeft(world, r.id, "tablet");
          return <li key={r.id} className={left < 0 ? "neg" : undefined}>{r.name}: {left} of {r.seats}</li>;
        })}
      </ul>
    </>
  );
}
