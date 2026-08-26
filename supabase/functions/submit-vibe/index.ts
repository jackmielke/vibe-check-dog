/**
 * Scores a photo, then puts it on the public leaderboard.
 *
 * Deliberately delegates scoring to `analyze-vibe` rather than duplicating the
 * prompt: that function also runs the content-safety screen, so routing through
 * it means an unsafe photo can never reach storage or the leaderboard.
 *
 * Clients hold only the publishable key and have no write policy on the table
 * or bucket, so this function is the sole path in.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_IMAGE_BYTES = 8 * 1024 * 1024;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const { imageData, name, ownerKey } = await req.json();
    if (!imageData) return json({ error: "imageData is required" }, 400);

    const cleanName = String(name ?? "").trim().slice(0, 40) || "Anonymous";

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1. Score + safety screen.
    const scored = await fetch(`${supabaseUrl}/functions/v1/analyze-vibe`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${serviceKey}` },
      body: JSON.stringify({ imageData }),
    });
    const rating = await scored.json();
    // Pass the rejection straight through: 422 means the safety screen said no.
    if (!scored.ok) return json(rating, scored.status);

    // 2. Decode once we know the photo is allowed through.
    const base64 = String(imageData).replace(/^data:image\/\w+;base64,/, "");
    let bytes: Uint8Array;
    try {
      const binary = atob(base64);
      bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
    } catch {
      return json({ error: "imageData is not valid base64" }, 400);
    }
    if (bytes.byteLength > MAX_IMAGE_BYTES) return json({ error: "Photo is too large" }, 413);

    // 3. Upload. The filename is random rather than derived from the poster's
    // name, so a public URL leaks nothing about who posted it.
    const file = `${Date.now()}-${crypto.randomUUID().slice(0, 8)}.jpg`;
    const upload = await fetch(`${supabaseUrl}/storage/v1/object/vibe-photos/${file}`, {
      method: "POST",
      headers: {
        // This project uses the new sb_secret_ key format, which Storage will
        // not accept as a bearer JWT - it has to arrive as `apikey`.
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "image/jpeg",
        "x-upsert": "false",
      },
      body: bytes,
    });
    if (!upload.ok) {
      console.error("Upload failed:", upload.status, await upload.text());
      return json({ error: "Could not store the photo" }, 502);
    }
    const publicUrl = `${supabaseUrl}/storage/v1/object/public/vibe-photos/${file}`;

    // 4. Insert the row.
    const insert = await fetch(`${supabaseUrl}/rest/v1/leaderboard`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        name: cleanName,
        score: rating.score,
        vibe_analysis: rating.analysis,
        image_url: publicUrl,
        owner_key: ownerKey ? String(ownerKey).slice(0, 128) : null,
      }),
    });
    if (!insert.ok) {
      console.error("Insert failed:", insert.status, await insert.text());
      return json({ error: "Could not save to the leaderboard" }, 502);
    }
    const [row] = await insert.json();
    return json({ success: true, data: row });
  } catch (error) {
    console.error("Error in submit-vibe:", error);
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
