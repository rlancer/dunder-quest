import { useSuspenseQuery } from "@tanstack/react-query";
import { Link, createFileRoute } from "@tanstack/react-router";
import { DailyPlayers, RankedBars, StageFunnel } from "../components/charts";
import { RangePicker } from "../components/RangePicker";
import { Empty, Stat, formatTime } from "../components/Stat";
import { overviewQuery } from "../data";

export const Route = createFileRoute("/")({
  loaderDeps: ({ search }) => ({ days: search.days }),
  loader: ({ context, deps }) => context.queryClient.ensureQueryData(overviewQuery(deps.days)),
  component: Overview,
});

function Overview() {
  const { days } = Route.useSearch();
  const { data } = useSuspenseQuery(overviewQuery(days));
  const { totals, stages } = data;
  const deaths = stages.reduce((sum, s) => sum + s.deaths, 0);
  const finished = stages.at(-1)?.cleared ?? 0;

  return (
    <>
      <div className="title-row">
        <h1>Overview</h1>
        <RangePicker />
      </div>

      <section className="stats">
        <Stat label="Players" value={totals.players} />
        <Stat label="Sessions" value={totals.sessions} />
        <Stat label="Finished the trail" value={finished} note={`${pct(finished, totals.players)} of players`} />
        <Stat label="Deaths" value={deaths} />
      </section>

      {totals.events === 0 ? (
        <Empty>No events in this window yet. Play a stage with stats switched on and they show up here.</Empty>
      ) : (
        <>
          <section className="card">
            <h2>Players per day</h2>
            <DailyPlayers rows={data.daily} />
          </section>

          <section className="card">
            <h2>Where players drop off</h2>
            <p className="hint">Grey: players who entered the stage. Orange: players who cleared it.</p>
            <StageFunnel rows={stages} />
          </section>

          <section className="card">
            <h2>Stages</h2>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Stage</th>
                    <th className="num">Started</th>
                    <th className="num">Cleared</th>
                    <th className="num">Clear rate</th>
                    <th className="num">Deaths per clear</th>
                    <th className="num">Median time</th>
                    <th className="num">Left early</th>
                  </tr>
                </thead>
                <tbody>
                  {stages.map((s) => (
                    <tr key={s.stage}>
                      <td>
                        <Link to="/stages/$stage" params={{ stage: s.stage }} search={{ days }}>
                          {s.stage}. {s.name}
                        </Link>
                        <div className="sub">{s.topic}</div>
                      </td>
                      <td className="num">{s.started}</td>
                      <td className="num">{s.cleared}</td>
                      <td className="num">{pct(s.cleared, s.started)}</td>
                      <td className="num">{s.clears ? (s.deaths / s.clears).toFixed(1) : "—"}</td>
                      <td className="num">{formatTime(s.medianTime)}</td>
                      <td className="num">{s.quits}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          {data.platforms.length > 0 ? (
            <section className="card">
              <h2>Platforms</h2>
              <RankedBars
                rows={data.platforms.map((p) => ({ name: p.platform, value: p.players }))}
                label="Players"
                ariaLabel="Players by platform"
              />
            </section>
          ) : null}
        </>
      )}
    </>
  );
}

function pct(part: number, whole: number): string {
  return whole > 0 ? `${Math.round((part / whole) * 100)}%` : "—";
}
