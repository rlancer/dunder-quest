import type { QueryClient } from "@tanstack/react-query";
import { HeadContent, Link, Outlet, Scripts, createRootRouteWithContext } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { RangeSearch } from "../data";
import styles from "../styles.css?url";

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  validateSearch: RangeSearch,
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { name: "robots", content: "noindex" },
      { title: "Ember Trail Stats" },
    ],
    links: [
      { rel: "stylesheet", href: styles },
      {
        rel: "icon",
        href: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Ccircle cx='8' cy='9' r='6' fill='%23e0672c'/%3E%3C/svg%3E",
      },
    ],
  }),
  component: Root,
});

function Root() {
  return (
    <Document>
      <header className="bar">
        <Link to="/" className="brand">
          Ember Trail <span>stats</span>
        </Link>
        <nav>
          <Link to="/" search={true} activeOptions={{ exact: true, includeSearch: false }}>
            Overview
          </Link>
          <Link to="/questions" search={true} activeOptions={{ includeSearch: false }}>
            Duel questions
          </Link>
        </nav>
      </header>
      <main>
        <Outlet />
      </main>
    </Document>
  );
}

function Document({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}
