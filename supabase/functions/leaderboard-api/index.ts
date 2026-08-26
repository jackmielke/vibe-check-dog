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

    // owner_key is intentionally not selected - it never leaves the server.
    // is_hidden lets a row be pulled from the public board without deleting it,
    // which is the moderation lever App Review expects to exist.
    const query =
      `select=id,name,score,created_at,image_url,vibe_analysis` +
      `&is_hidden=is.false&order=${order}&limit=${limit}`;

    const res = await fetch(`${supabaseUrl}/rest/v1/leaderboard?${query}`, {
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
    });
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
