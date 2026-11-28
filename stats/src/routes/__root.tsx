import { type QueryClient, useQuery } from "@tanstack/react-query";
import { HeadContent, Link, Outlet, Scripts, createRootRouteWithContext } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { RangeSearch, newCountQuery } from "../data";
import styles from "../styles.css?url";

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  validateSearch: RangeSearch,
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { name: "robots", content: "noindex" },
      { title: "Dunder Quest Admin" },
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
  // Waiting feedback on the live site; the nav shows it without holding up the page.
  const { data: waiting } = useQuery(newCountQuery());
  return (
    <Document>
      <header className="bar">
        <Link to="/" className="brand">
          Dunder Quest <span>admin</span>
        </Link>
        <nav>
          <Link to="/" search={true} activeOptions={{ exact: true, includeSearch: false }}>
            Overview
          </Link>
          <Link to="/questions" search={true} activeOptions={{ includeSearch: false }}>
            Duel questions
          </Link>
          <Link to="/feedback" activeOptions={{ includeSearch: false }}>
            Feedback
            {waiting ? (
              <span className="count" aria-label={`, ${waiting} new`}>
                {waiting}
              </span>
            ) : null}
          </Link>
          <a href="https://dunderquest.com/brand/">Brand kit</a>
          <Link to="/dev">Dev notes</Link>
          <Link to="/eggs">Easter eggs</Link>
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
