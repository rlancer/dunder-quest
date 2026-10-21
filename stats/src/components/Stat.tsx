export function Stat({ label, value, note }: { label: string; value: string | number; note?: string }) {
  return (
    <div className="stat">
      <div className="stat-label">{label}</div>
      <div className="stat-value">{typeof value === "number" ? value.toLocaleString() : value}</div>
      {note ? <div className="stat-note">{note}</div> : null}
    </div>
  );
}

export function formatTime(seconds: number): string {
  if (seconds <= 0) return "—";
  const whole = Math.floor(seconds);
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}.${Math.floor((seconds % 1) * 10)}`;
}

export function Empty({ children }: { children: string }) {
  return <p className="empty">{children}</p>;
}
