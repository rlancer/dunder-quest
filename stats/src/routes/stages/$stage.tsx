import { useSuspenseQuery } from "@tanstack/react-query";
import { createFileRoute, notFound } from "@tanstack/react-router";
import { AlongStage, RankedBars } from "../../components/charts";
import { RangePicker } from "../../components/RangePicker";
import { Empty, Stat, formatTime } from "../../components/Stat";
import { stageQuery } from "../../data";

export const Route = createFileRoute("/stages/$stage")({
  params: {
    parse: ({ stage }) => {
      const id = Number(stage);
      if (!Number.isInteger(id) || id < 1 || id > 6) throw notFound();
      return { stage: id };
    },
    stringify: ({ stage }) => ({ stage: String(stage) }),
  },
  loaderDeps: ({ search }) => ({ days: search.days }),
  loader: ({ context, params, deps }) => context.queryClient.ensureQueryData(stageQuery(params.stage, deps.days)),
  component: StagePage,
});

function StagePage() {
  const { stage } = Route.useParams();
  const { days } = Route.useSearch();
  const { data } = useSuspenseQuery(stageQuery(stage, days));
  const deaths = data.deaths.reduce((sum, d) => sum + d.count, 0);
  const times = data.times;

  return (
    <>
      <div className="title-row">
        <div>
          <h1>
            {data.stage}. {data.name}
          </h1>
          <p className="sub">{data.topic}</p>
        </div>
        <RangePicker />
      </div>

      <section className="stats">
        <Stat label="Clears" value={times.length} />
        <Stat label="Fastest" value={formatTime(times[0] ?? 0)} />
        <Stat label="Median" value={formatTime(times[Math.floor(times.length / 2)] ?? 0)} />
        <Stat label="Deaths" value={deaths} />
        <Stat
          label="Wizard duels"
          value={`${data.duel.won} won`}
          note={data.duel.downed ? `${data.duel.downed} lost` : undefined}
        />
      </section>

      <section className="card">
        <h2>Where players die</h2>
        {data.deaths.length ? (
          <AlongStage rows={data.deaths} label="Deaths" ariaLabel="Deaths along the stage" />
        ) : (
          <Empty>No deaths recorded.</Empty>
        )}
      </section>

      <section className="card">
        <h2>Where players leave for the map</h2>
        {data.quits.length ? (
          <AlongStage rows={data.quits} label="Players who left" ariaLabel="Where players left the stage" />
        ) : (
          <Empty>Nobody has left this stage early.</Empty>
        )}
      </section>

      <section className="card">
        <h2>Lore scrolls read</h2>
        {data.scrolls.length ? (
          <RankedBars
            rows={data.scrolls.map((s) => ({ name: s.scroll, value: s.players }))}
            label="Players"
            ariaLabel="Players who read each scroll"
          />
        ) : (
          <Empty>No scrolls read yet.</Empty>
        )}
      </section>
    </>
  );
}
