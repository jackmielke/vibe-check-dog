/** Public read of the leaderboard, highest score first. */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const params = new URL(req.url).searchParams;
    const limit = Math.min(200, Math.max(1, Number(params.get("limit")) || 100));
    // "top" is the all-time board; "recent" is the feed of what just happened.
    const order = params.get("sort") === "recent"
      ? "created_at.desc"
      : "score.desc,created_at.desc";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const auth = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` };

    // A viewer passes its own owner_key so the board comes back with blocked
    // posters already removed. Filtering here rather than only in the client is
    // what makes a block survive reinstalling the app or reading from a second
    // device, and it means a blocked poster is gone on the very next refresh.
    const viewer = params.get("viewer");
    let blocked: string[] = [];
    if (viewer) {
      const res = await fetch(
        `${supabaseUrl}/rest/v1/blocked_posters?blocker_key=eq.${encodeURIComponent(viewer)}&select=poster_id`,
        { headers: auth },
      );
      if (res.ok) {
        const rows: Array<{ poster_id: string }> = await res.json();
        blocked = rows.map((r) => r.poster_id);
      } else {
        // Failing open on a moderation filter is not acceptable - a blocked
        // poster must not reappear because a lookup blipped.
        console.error("Blocked-poster lookup failed:", res.status, await res.text());
        return json({ error: "Failed to fetch leaderboard" }, 502);
      }
    }

    // owner_key is intentionally not selected - it never leaves the server.
    // poster_id is its one-way pseudonym, which is what the client blocks by.
    // is_hidden lets a row be pulled from the public board without deleting it,
    // which is the moderation lever App Review expects to exist.
    let query =
      `select=id,name,score,created_at,image_url,vibe_analysis,poster_id` +
      `&is_hidden=is.false&order=${order}&limit=${limit}`;
    if (blocked.length > 0) {
      // PostgREST list syntax; quote each value so a stray comma cannot split it.
      query += `&poster_id=not.in.(${blocked.map((p) => `"${p}"`).join(",")})`;
    }

    const res = await fetch(`${supabaseUrl}/rest/v1/leaderboard?${query}`, { headers: auth });
    if (!res.ok) {
      console.error("Leaderboard read failed:", res.status, await res.text());
      return json({ error: "Failed to fetch leaderboard" }, 502);
    }
    const data = await res.json();
    return json({ success: true, count: data.length, data });
  } catch (error) {
    console.error("Error in leaderboard-api:", error);
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
