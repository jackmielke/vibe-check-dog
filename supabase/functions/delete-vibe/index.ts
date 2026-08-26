/**
 * Deletes a poster's own leaderboard entries, photos included.
 *
 * This exists so the app can offer real account deletion, which App Store
 * guideline 5.1.1(v) requires of anything with Sign in with Apple. A caller can
 * only delete rows whose owner_key matches the one they present, and owner_key
 * is never returned by any read endpoint, so it is not guessable from the app.
 */

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
    const { ownerKey, id } = await req.json();
    if (!ownerKey || String(ownerKey).length < 8) {
      return json({ error: "ownerKey is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const auth = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` };

    // Scope every operation by owner_key, plus optionally a single row id.
    let filter = `owner_key=eq.${encodeURIComponent(String(ownerKey))}`;
    if (id) filter += `&id=eq.${encodeURIComponent(String(id))}`;

    const found = await fetch(`${supabaseUrl}/rest/v1/leaderboard?${filter}&select=id,image_url`, {
      headers: auth,
    });
    if (!found.ok) return json({ error: "Lookup failed" }, 502);
    const rows: Array<{ id: string; image_url: string | null }> = await found.json();

    // Remove the stored photos first; an orphaned row is easier to reason about
    // than an orphaned public image.
    for (const row of rows) {
      const file = row.image_url?.split("/vibe-photos/")[1];
      if (!file) continue;
      const del = await fetch(`${supabaseUrl}/storage/v1/object/vibe-photos/${file}`, {
        method: "DELETE",
        headers: auth,
      });
      if (!del.ok) console.error("Photo delete failed:", file, del.status);
    }

    const deleted = await fetch(`${supabaseUrl}/rest/v1/leaderboard?${filter}`, {
      method: "DELETE",
      headers: { ...auth, Prefer: "return=representation" },
    });
    if (!deleted.ok) {
      console.error("Row delete failed:", deleted.status, await deleted.text());
      return json({ error: "Delete failed" }, 502);
    }

    return json({ success: true, deleted: (await deleted.json()).length });
  } catch (error) {
    console.error("Error in delete-vibe:", error);
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
