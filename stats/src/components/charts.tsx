import { barX, barY, defineChart, lineY } from "@tanstack/charts";
import { Chart } from "@tanstack/charts/react";
import { scaleBand } from "@tanstack/charts/scales/band";
import { scaleLinear } from "@tanstack/charts/scales/linear";
import { scalePoint } from "@tanstack/charts/scales/point";
import { tooltip } from "@tanstack/charts/tooltip";
import { useMemo } from "react";

const EMBER = "var(--ember)";
const ASH = "var(--ash)";

/** A 0-based axis for counts, ticked at whole numbers only. */
function countAxis(values: readonly number[], label: string) {
  const top = Math.max(1, ...values);
  const step = Math.max(1, Math.ceil(top / 5));
  const ticks: number[] = [];
  for (let tick = 0; tick <= top + step - 1; tick += step) ticks.push(tick);
  return {
    scale: scaleLinear().domain([0, ticks.at(-1) ?? top]),
    grid: true,
    axis: { label, ticks: { values: ticks } },
  };
}

/** Players per day. */
export function DailyPlayers({ rows }: { rows: readonly { day: string; players: number }[] }) {
  const definition = useMemo(
    () =>
      defineChart({
        marks: [lineY(rows, { x: "day", y: "players", points: rows.length < 40, stroke: EMBER })],
        scales: {
          x: { scale: () => scalePoint<string>().padding(0.3) },
          y: countAxis(rows.map((r) => r.players), "Players"),
        },
        tooltip,
      }),
    [rows],
  );
  return <Chart definition={definition} height={220} ariaLabel="Players per day" />;
}

type FunnelRow = { name: string; started: number; cleared: number };

/** How many players reached and cleared each stage, in trail order. */
export function StageFunnel({ rows }: { rows: readonly FunnelRow[] }) {
  const definition = useMemo(() => {
    const long = rows.flatMap((row) => [
      { name: row.name, step: "Started", players: row.started },
      { name: row.name, step: "Cleared", players: row.cleared },
    ]);
    return defineChart({
      marks: [
        barY(long, {
          x: "name",
          y: "players",
          z: "step",
          fill: (d) => (d.step === "Cleared" ? EMBER : ASH),
          layout: { type: "group" },
          inset: 1,
          radius: 2,
        }),
      ],
      scales: {
        x: { scale: () => scaleBand<string>().domain(rows.map((r) => r.name)).padding(0.2) },
        y: countAxis(long.map((r) => r.players), "Players"),
      },
      tooltip,
    });
  }, [rows]);
  return <Chart definition={definition} height={280} ariaLabel="Players who started and cleared each stage" />;
}

/** One horizontal bar per category, longest first. */
export function RankedBars({
  rows,
  label,
  ariaLabel,
}: {
  rows: readonly { name: string; value: number }[];
  label: string;
  ariaLabel: string;
}) {
  const definition = useMemo(() => {
    const ranked = [...rows].sort((a, b) => b.value - a.value);
    return defineChart({
      marks: [barX(ranked, { x: "value", y: "name", fill: EMBER, inset: 2, radius: 2 })],
      scales: {
        x: countAxis(ranked.map((r) => r.value), label),
        y: { scale: () => scaleBand<string>().domain(ranked.map((r) => r.name)).padding(0.15) },
      },
      tooltip,
    });
  }, [rows, label]);
  return <Chart definition={definition} height={Math.max(120, rows.length * 34 + 50)} ariaLabel={ariaLabel} />;
}

/** Counts along the stage, one bar per tile column, so trouble spots stand out. */
export function AlongStage({
  rows,
  label,
  ariaLabel,
}: {
  rows: readonly { tile: number; count: number }[];
  label: string;
  ariaLabel: string;
}) {
  const definition = useMemo(() => {
    // Every column from the start, so each bar is one tile wide however sparse the data.
    const counts = new Map(rows.map((r) => [r.tile, r.count]));
    const last = Math.max(0, ...rows.map((r) => r.tile));
    const filled = Array.from({ length: last + 2 }, (_, tile) => ({ tile, count: counts.get(tile) ?? 0 }));
    return defineChart({
      marks: [barY(filled, { x: "tile", y: "count", fill: EMBER })],
      scales: {
        x: { scale: scaleLinear, axis: { label: "Tile across the stage" } },
        y: countAxis(rows.map((r) => r.count), label),
      },
      tooltip,
    });
  }, [rows, label]);
  return <Chart definition={definition} height={220} ariaLabel={ariaLabel} />;
}
