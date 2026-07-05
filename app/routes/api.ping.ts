import type { Route } from "./+types/api.ping";
import { pingDatabase } from "../lib/db.server";

// GET /api/ping — health check. Proves the backend is answering AND can reach
// Postgres. The deploy script polls this before cutting traffic to a new
// container, so a DB-down container must fail the check: returns 503 when the
// database is unreachable so a broken release is never marked healthy.
export async function loader(_: Route.LoaderArgs) {
  const dbOk = await pingDatabase();
  return Response.json(
    {
      pong: true,
      db: dbOk,
      serverTime: new Date().toISOString(),
      uptimeSeconds: Math.round(process.uptime()),
    },
    { status: dbOk ? 200 : 503 },
  );
}

// POST /api/ping — echoes back whatever { message } you send
export async function action({ request }: Route.ActionArgs) {
  const body = await request.json().catch(() => ({}));
  return Response.json({
    pong: true,
    echo: body?.message ?? null,
    serverTime: new Date().toISOString(),
  });
}
