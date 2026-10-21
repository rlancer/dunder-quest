import { queryOptions } from "@tanstack/react-query";
import { createServerFn } from "@tanstack/react-start";
import * as v from "valibot";
import { overview, questions, stageDetail } from "./server/stats.server";

/** The time windows the dashboard offers, in days; 0 is all time. */
export const RANGES = [7, 30, 90, 0] as const;
export type Days = (typeof RANGES)[number];
export const Range = v.fallback(v.picklist(RANGES), 30);
export const RangeSearch = v.object({ days: v.optional(Range, 30) });

const getOverview = createServerFn({ method: "GET" })
  .validator(v.object({ days: Range }))
  .handler(({ data }) => overview(data.days));

const getStage = createServerFn({ method: "GET" })
  .validator(v.object({ stage: v.pipe(v.number(), v.integer(), v.minValue(1)), days: Range }))
  .handler(({ data }) => stageDetail(data.stage, data.days));

const getQuestions = createServerFn({ method: "GET" })
  .validator(v.object({ days: Range }))
  .handler(({ data }) => questions(data.days));

// Players report every few seconds; a minute keeps the page fresh without churning D1.
const staleTime = 60_000;

export const overviewQuery = (days: Days) =>
  queryOptions({ queryKey: ["overview", days], queryFn: () => getOverview({ data: { days } }), staleTime });

export const stageQuery = (stage: number, days: Days) =>
  queryOptions({ queryKey: ["stage", stage, days], queryFn: () => getStage({ data: { stage, days } }), staleTime });

export const questionsQuery = (days: Days) =>
  queryOptions({ queryKey: ["questions", days], queryFn: () => getQuestions({ data: { days } }), staleTime });
