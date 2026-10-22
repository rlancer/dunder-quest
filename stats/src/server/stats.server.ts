import { env } from "cloudflare:workers";
import lessons from "../../../data/lessons.json";
import { STAGE_NAMES } from "./stages";


type Lesson = {
  topic: string;
  questions: { code: string[]; prompt: string; options: string[]; answer: number; scroll: string }[];
};
const LESSONS = lessons as Record<string, Lesson>;

/** Epoch ms where a `days` window starts; 0 means all time. */
function since(days: number): number {
  return days > 0 ? Date.now() - days * 86_400_000 : 0;
}

async function all<T>(sql: string, ...params: unknown[]): Promise<T[]> {
  const { results } = await env.DB.prepare(sql)
    .bind(...params)
    .all<T>();
  return results;
}

export async function overview(days: number) {
  const from = since(days);
  const [totals] = await all<{ players: number; sessions: number; events: number }>(
    `SELECT COUNT(DISTINCT install_id) AS players, COUNT(DISTINCT session_id) AS sessions, COUNT(*) AS events
     FROM events WHERE at >= ?`,
    from,
  );
  const daily = await all<{ day: string; players: number }>(
    `SELECT date(at / 1000, 'unixepoch') AS day, COUNT(DISTINCT install_id) AS players
     FROM events WHERE at >= ? GROUP BY day ORDER BY day`,
    from,
  );
  const platforms = await all<{ platform: string; players: number }>(
    `SELECT platform, COUNT(DISTINCT install_id) AS players
     FROM events WHERE at >= ? GROUP BY platform ORDER BY players DESC`,
    from,
  );
  const stageRows = await all<{ stage: number; type: string; players: number; count: number }>(
    `SELECT stage, type, COUNT(DISTINCT install_id) AS players, COUNT(*) AS count
     FROM events WHERE at >= ? AND stage IS NOT NULL AND type IN ('stage_start', 'stage_clear', 'death', 'stage_quit')
     GROUP BY stage, type`,
    from,
  );
  const times = await all<{ stage: number; time: number }>(
    `SELECT stage, json_extract(data, '$.time') AS time
     FROM events WHERE at >= ? AND type = 'stage_clear' AND time > 0`,
    from,
  );

  const stages = Object.entries(STAGE_NAMES).map(([id, name]) => {
    const stage = Number(id);
    const row = (type: string) => stageRows.find((r) => r.stage === stage && r.type === type);
    const clearTimes = times.filter((t) => t.stage === stage).map((t) => t.time);
    return {
      stage,
      name,
      topic: LESSONS[id]?.topic ?? "",
      started: row("stage_start")?.players ?? 0,
      cleared: row("stage_clear")?.players ?? 0,
      clears: row("stage_clear")?.count ?? 0,
      deaths: row("death")?.count ?? 0,
      quits: row("stage_quit")?.count ?? 0,
      medianTime: median(clearTimes),
    };
  });

  return { totals: totals ?? { players: 0, sessions: 0, events: 0 }, daily, platforms, stages };
}

export async function stageDetail(stage: number, days: number) {
  const from = since(days);
  // Deaths and quits bucketed by how far along the stage they happened, in 16px tiles.
  const deaths = await all<{ tile: number; count: number }>(
    `SELECT CAST(json_extract(data, '$.x') / 16 AS INTEGER) AS tile, COUNT(*) AS count
     FROM events WHERE at >= ? AND type = 'death' AND stage = ? GROUP BY tile ORDER BY tile`,
    from,
    stage,
  );
  const quits = await all<{ tile: number; count: number }>(
    `SELECT CAST(json_extract(data, '$.x') / 16 AS INTEGER) AS tile, COUNT(*) AS count
     FROM events WHERE at >= ? AND type = 'stage_quit' AND stage = ? GROUP BY tile ORDER BY tile`,
    from,
    stage,
  );
  const times = await all<{ time: number }>(
    `SELECT json_extract(data, '$.time') AS time
     FROM events WHERE at >= ? AND type = 'stage_clear' AND stage = ? AND time > 0 ORDER BY time`,
    from,
    stage,
  );
  const scrolls = await all<{ scroll: string; players: number }>(
    `SELECT json_extract(data, '$.scroll') AS scroll, COUNT(DISTINCT install_id) AS players
     FROM events WHERE at >= ? AND type = 'scroll_read' AND stage = ? GROUP BY scroll ORDER BY players DESC`,
    from,
    stage,
  );
  const [duel] = await all<{ won: number; downed: number }>(
    `SELECT SUM(type = 'duel_won') AS won, SUM(type = 'duel_downed') AS downed
     FROM events WHERE at >= ? AND stage = ? AND type IN ('duel_won', 'duel_downed')`,
    from,
    stage,
  );
  return {
    stage,
    name: STAGE_NAMES[stage] ?? `Stage ${stage}`,
    topic: LESSONS[String(stage)]?.topic ?? "",
    deaths,
    quits,
    times: times.map((t) => t.time),
    scrolls,
    duel: { won: duel?.won ?? 0, downed: duel?.downed ?? 0 },
  };
}

export async function questions(days: number) {
  const from = since(days);
  const rows = await all<{ stage: number; q: number; answers: number; wrong: number; hinted: number }>(
    `SELECT stage, json_extract(data, '$.q') AS q, COUNT(*) AS answers,
            SUM(json_extract(data, '$.correct') = 0) AS wrong,
            SUM(json_extract(data, '$.hints') > 0) AS hinted
     FROM events WHERE at >= ? AND type = 'duel_answer' GROUP BY stage, q`,
    from,
  );
  const picks = await all<{ stage: number; q: number; chosen: number; count: number }>(
    `SELECT stage, json_extract(data, '$.q') AS q, json_extract(data, '$.chosen') AS chosen, COUNT(*) AS count
     FROM events WHERE at >= ? AND type = 'duel_answer' AND json_extract(data, '$.correct') = 0
     GROUP BY stage, q, chosen`,
    from,
  );
  return rows.map((row) => {
    const question = LESSONS[String(row.stage)]?.questions[row.q];
    const commonWrong = picks
      .filter((p) => p.stage === row.stage && p.q === row.q)
      .sort((a, b) => b.count - a.count)[0];
    return {
      ...row,
      stageName: STAGE_NAMES[row.stage] ?? `Stage ${row.stage}`,
      code: question?.code.join("\n") ?? "",
      prompt: question?.prompt ?? "(question no longer in lessons.json)",
      scroll: question?.scroll ?? "",
      answer: question?.options[question.answer] ?? "",
      commonWrong: commonWrong ? (question?.options[commonWrong.chosen] ?? "") : "",
      missRate: row.answers > 0 ? row.wrong / row.answers : 0,
    };
  });
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}
