import { createFileRoute, redirect } from "@tanstack/react-router";

// The social cards moved to the public brand kit, beside the logo and trailer.
export const Route = createFileRoute("/og")({
  beforeLoad: () => {
    throw redirect({ href: "https://dunderquest.com/brand/#cards-h", statusCode: 301 });
  },
});
