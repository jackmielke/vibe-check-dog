/**
 * Blocking and reporting - the two levers App Store guideline 1.2 requires of
 * an app with user-generated content.
 *
 * Actions:
 *   block   { ownerKey, posterId, entryId? }  hide every post by that poster
 *   unblock { ownerKey, posterId }            undo it
 *   list    { ownerKey }                      poster_ids this device has blocked
 *   report  { ownerKey, entryId, reason? }    flag one post for the developer
 *
 * A caller can only ever act as itself: blocker_key is whatever ownerKey it
 * presents, and that key is private to the device. posterId is the one-way
 * pseudonym from the leaderboard view, so blocking never reveals the target's
 * owner_key.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/** Reports from this many distinct devices pull a post off the public board. */
const AUTO_HIDE_THRESHOLD = 3;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const { action, ownerKey, posterId, entryId, reason } = await req.json();

    if (!ownerKey || String(ownerKey).length < 8) {
      return json({ error: "ownerKey is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const auth = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` };
    const jsonAuth = { ...auth, "Content-Type": "application/json" };
    const rest = (path: string) => `${supabaseUrl}/rest/v1/${path}`;

    const logEvent = async (event: Record<string, unknown>) => {
      const res = await fetch(rest("moderation_events"), {
        method: "POST",
        headers: jsonAuth,
        body: JSON.stringify(event),
      });
      // A failed audit write must not fail the user's block - the block is the
      // safety-critical half. Log loudly instead.
      if (!res.ok) console.error("moderation_events insert failed:", res.status, await res.text());
    };

    switch (action) {
      case "block": {
        if (!posterId) return json({ error: "posterId is required" }, 400);

        // on_conflict + merge-duplicates makes a repeat block a no-op rather
        // than a 409, so the client never has to care whether it already blocked.
        const res = await fetch(rest("blocked_posters?on_conflict=blocker_key,poster_id"), {
          method: "POST",
          headers: { ...jsonAuth, Prefer: "resolution=merge-duplicates" },
          body: JSON.stringify({ blocker_key: ownerKey, poster_id: posterId }),
        });
        if (!res.ok) {
          console.error("Block failed:", res.status, await res.text());
          return json({ error: "Block failed" }, 502);
        }

        // Apple asks that blocking also notify the developer of the content.
        await logEvent({
          kind: "block",
          poster_id: posterId,
          entry_id: entryId ?? null,
          reporter_key: ownerKey,
          note: "User blocked this poster from the leaderboard.",
        });
        return json({ success: true, blocked: posterId });
      }

      case "unblock": {
        if (!posterId) return json({ error: "posterId is required" }, 400);
        const filter =
          `blocker_key=eq.${encodeURIComponent(String(ownerKey))}` +
          `&poster_id=eq.${encodeURIComponent(String(posterId))}`;
        const res = await fetch(rest(`blocked_posters?${filter}`), { method: "DELETE", headers: auth });
        if (!res.ok) {
          console.error("Unblock failed:", res.status, await res.text());
          return json({ error: "Unblock failed" }, 502);
        }
        await logEvent({ kind: "unblock", poster_id: posterId, reporter_key: ownerKey });
        return json({ success: true, unblocked: posterId });
      }

      case "list": {
        const res = await fetch(
          rest(`blocked_posters?blocker_key=eq.${encodeURIComponent(String(ownerKey))}&select=poster_id`),
          { headers: auth },
        );
        if (!res.ok) return json({ error: "Lookup failed" }, 502);
        const rows: Array<{ poster_id: string }> = await res.json();
        return json({ success: true, data: rows.map((r) => r.poster_id) });
      }

      case "report": {
        if (!entryId) return json({ error: "entryId is required" }, 400);

        await logEvent({
          kind: "report",
          entry_id: entryId,
          reporter_key: ownerKey,
          note: typeof reason === "string" ? reason.slice(0, 500) : null,
        });

        // Count distinct reporters rather than raw reports, so one device
        // cannot take down a post by tapping Report repeatedly.
        const counted = await fetch(
          rest(`moderation_events?entry_id=eq.${encodeURIComponent(String(entryId))}&kind=eq.report&select=reporter_key`),
          { headers: auth },
        );
        let hidden = false;
        if (counted.ok) {
          const rows: Array<{ reporter_key: string | null }> = await counted.json();
          const distinct = new Set(rows.map((r) => r.reporter_key).filter(Boolean));
          if (distinct.size >= AUTO_HIDE_THRESHOLD) {
            const hide = await fetch(rest(`leaderboard?id=eq.${encodeURIComponent(String(entryId))}`), {
              method: "PATCH",
              headers: jsonAuth,
              body: JSON.stringify({ is_hidden: true }),
            });
            hidden = hide.ok;
            if (!hide.ok) console.error("Auto-hide failed:", hide.status, await hide.text());
          }
        }
        return json({ success: true, autoHidden: hidden });
      }

      default:
        return json({ error: "action must be block, unblock, list, or report" }, 400);
    }
  } catch (error) {
    console.error("Error in moderate:", error);
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
