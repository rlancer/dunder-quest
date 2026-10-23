import { createFileRoute, redirect } from "@tanstack/react-router";

// Social cards moved under Brand; keep old links working.
export const Route = createFileRoute("/og")({
  beforeLoad: () => {
    throw redirect({ to: "/brand/og", statusCode: 301 });
  },
});
