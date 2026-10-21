import { Link } from "@tanstack/react-router";
import { RANGES } from "../data";

const LABELS: Record<(typeof RANGES)[number], string> = { 7: "7 days", 30: "30 days", 90: "90 days", 0: "All time" };

/** Switches the time window, kept in the URL as ?days= so views can be shared. */
export function RangePicker() {
  return (
    <div className="range" role="group" aria-label="Time window">
      {RANGES.map((days) => (
        <Link key={days} to="." search={(s) => ({ ...s, days })} activeOptions={{ includeSearch: true }}>
          {LABELS[days]}
        </Link>
      ))}
    </div>
  );
}
