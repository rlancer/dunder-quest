import { Link, Outlet, createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/brand")({
  component: Brand,
});

function Brand() {
  return (
    <>
      <nav className="tabs">
        <Link to="/brand" activeOptions={{ exact: true, includeSearch: false }}>
          Identity
        </Link>
        <Link to="/brand/trailer" activeOptions={{ includeSearch: false }}>
          Trailer
        </Link>
        <Link to="/brand/og" activeOptions={{ includeSearch: false }}>
          Social cards
        </Link>
      </nav>
      <Outlet />
    </>
  );
}
