import { useSuspenseQuery } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import {
  createColumnHelper,
  createSortedRowModel,
  rowSortingFeature,
  tableFeatures,
  useTable,
} from "@tanstack/react-table";
import { RankedBars } from "../components/charts";
import { RangePicker } from "../components/RangePicker";
import { Empty } from "../components/Stat";
import { questionsQuery } from "../data";

export const Route = createFileRoute("/questions")({
  loaderDeps: ({ search }) => ({ days: search.days }),
  loader: ({ context, deps }) => context.queryClient.ensureQueryData(questionsQuery(deps.days)),
  component: Questions,
});

type Row = {
  stage: number;
  q: number;
  stageName: string;
  code: string;
  prompt: string;
  answer: string;
  commonWrong: string;
  answers: number;
  missRate: number;
  hinted: number;
};

const features = tableFeatures({ rowSortingFeature, sortedRowModel: createSortedRowModel() });
const helper = createColumnHelper<typeof features, Row>();
const columns = helper.columns([
  helper.accessor("stageName", { header: "Stage" }),
  helper.accessor("prompt", {
    header: "Question",
    enableSorting: false,
    cell: ({ row }) => (
      <>
        <pre>{row.original.code}</pre>
        <div>{row.original.prompt}</div>
        <div className="sub">
          Answer: <code>{row.original.answer}</code>
          {row.original.commonWrong ? (
            <>
              {" · Most picked wrong: "}
              <code>{row.original.commonWrong}</code>
            </>
          ) : null}
        </div>
      </>
    ),
  }),
  helper.accessor("answers", { header: "Answers" }),
  helper.accessor("missRate", { header: "Missed", cell: ({ getValue }) => `${Math.round(getValue() * 100)}%` }),
  helper.accessor("hinted", { header: "Used a hint" }),
]);

const TEXT_COLUMNS = new Set(["stageName", "prompt"]);

function Questions() {
  const { days } = Route.useSearch();
  const { data } = useSuspenseQuery(questionsQuery(days));
  const table = useTable({
    features,
    columns,
    data,
    initialState: { sorting: [{ id: "missRate", desc: true }] },
  });
  const hardest = data
    .filter((q) => q.answers >= 3)
    .sort((a, b) => b.missRate - a.missRate)
    .slice(0, 8)
    .map((q) => ({ name: `${q.stageName} #${q.q + 1}`, value: Math.round(q.missRate * 100) }));

  return (
    <>
      <div className="title-row">
        <h1>Duel questions</h1>
        <RangePicker />
      </div>

      {data.length === 0 ? (
        <Empty>No duel answers in this window yet.</Empty>
      ) : (
        <>
          {hardest.length ? (
            <section className="card">
              <h2>Hardest questions</h2>
              <p className="hint">Share of answers that were wrong, for questions answered at least 3 times.</p>
              <RankedBars rows={hardest} label="Missed (%)" ariaLabel="Questions most often answered wrong" />
            </section>
          ) : null}

          <section className="card">
            <h2>Every question asked</h2>
            <div className="table-wrap">
              <table>
                <thead>
                  {table.getHeaderGroups().map((group) => (
                    <tr key={group.id}>
                      {group.headers.map((header) => {
                        const sorted = header.column.getIsSorted();
                        return (
                          <th key={header.id} className={TEXT_COLUMNS.has(header.column.id) ? "" : "num"}>
                            {header.column.getCanSort() ? (
                              <button className="sort" onClick={header.column.getToggleSortingHandler()}>
                                <table.FlexRender header={header} />
                                {sorted === "asc" ? " ↑" : sorted === "desc" ? " ↓" : ""}
                              </button>
                            ) : (
                              <table.FlexRender header={header} />
                            )}
                          </th>
                        );
                      })}
                    </tr>
                  ))}
                </thead>
                <tbody>
                  {table.getRowModel().rows.map((row) => (
                    <tr key={row.id}>
                      {row.getAllCells().map((cell) => (
                        <td key={cell.id} className={cell.column.id === "prompt" ? "question" : TEXT_COLUMNS.has(cell.column.id) ? "" : "num"}>
                          <table.FlexRender cell={cell} />
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </>
  );
}
