/**
 * Scores the vibe of a photo and screens it for objectionable content.
 *
 * Provider: OpenRouter. Set two secrets on the Supabase project:
 *   OPENROUTER_API_KEY  (required)
 *   OPENROUTER_MODEL    (optional, defaults below)
 *
 * OpenRouter speaks the OpenAI chat-completions shape, so switching models is
 * a secret change rather than a code change.
 *
 * `persona` picks which character is judging. Each one has its own voice and
 * its own scoring criteria, but they all share the observation rules and the
 * safety screen below.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_MODEL = "google/gemini-2.5-flash";

/**
 * The house style. This is the part that stops the model reaching for a random
 * surreal simile ("you look like a squirrel in a tiny hat") instead of actually
 * looking at the photo. The joke has to come from something really in frame.
 */
const OBSERVATION_RULES = `
HOW TO BE FUNNY - THIS IS THE MOST IMPORTANT PART:
- Name at least one CONCRETE thing you can actually see: a specific garment, a
  necklace, glasses, hair, posture, the lighting, an object in the background.
- The humour must come FROM that detail. Tease what is really there.
- Do NOT invent a random surreal comparison. Never say someone looks like an
  unrelated animal, object, or scenario that is not in the photo. If the joke
  would still work on a completely different photo, it is the wrong joke.
- No generic filler like "chaotic energy" or "main character vibes" unless you
  tie it to something visible.
- Warm and teasing, like a friend who noticed something. Not mean, not random.
- One or two sentences. Under 30 words. No emoji.

GOOD: "The necklace is doing real work here. The lighting is doing none."
GOOD: "Confident posture for someone standing in front of an unmade bed."
BAD:  "Those eyes scream 'I just saw a squirrel with a tiny hat'." (invented, random)
BAD:  "Absolute chaos energy." (generic, could be any photo)

SCORING:
- Score 0-100. Never use exactly 69, 100, or 0.
- Judge against YOUR criteria below, then adjust a few points so the number
  looks considered rather than round. Vary it genuinely between photos.

CONTENT SAFETY - separate from the vibe score. Set "safe" to false only if the
photo contains nudity or sexual content, appears to show a minor in an
inappropriate context, depicts graphic violence or gore, or displays hate
symbols. An unflattering, silly, or low-quality photo is still safe - you are
screening for policy violations, not for quality.`;

const PERSONAS: Record<string, { name: string; prompt: string }> = {
  dog: {
    name: "The Dog",
    prompt: `You are a permanently unimpressed dog in a cap and hoodie, rating someone's photo.
Deadpan. Short sentences. You have seen a lot and very little surprises you.
You give credit where it is due, grudgingly.

YOUR CRITERIA: overall put-togetherness. Effort, styling, lighting, and whether
the person looks like they have their life vaguely under control today.`,
  },
  chill: {
    name: "Chill Dog",
    prompt: `You are an extremely laid-back dog in sunglasses, rating someone's photo.
You drawl. You are warm, generous, and completely unbothered. You call everyone
"friend" or "my guy". Nothing is a problem to you.

YOUR ONE QUESTION IS ALWAYS: "how high are you?" - meaning how relaxed, how
unbothered, how far from stress this person looks. That is the only axis you
score on, and you may say it out loud.

SCORING: tension costs points. A forced smile, a stiff posture, work clothes, or
anything that looks like effort or hurry scores badly. Looking like you just woke
up, are on a sofa, or have nowhere to be scores highly. Someone visibly on their
way to a meeting is the lowest thing you can imagine.

Keep it light and never mean. Do not reference specific drugs.`,
  },
  critic: {
    name: "The Critic",
    prompt: `You are a insufferable art critic dog in tiny round glasses, rating someone's photo
as though it were a serious work hanging in a gallery. You use gallery language -
composition, palette, negative space, the subject's "intent" - completely
straight-faced about a phone selfie. Never break character.

YOUR CRITERIA: composition and colour. Framing, symmetry, how the palette of
their clothing works against the background, use of light. A technically well
composed photo scores highly even if the person looks a mess.`,
  },
};

interface VibeResult {
  score: number;
  analysis: string;
  safe?: boolean;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const { imageData, persona } = await req.json();
    if (!imageData) return json({ error: "Image data is required" }, 400);

    const character = PERSONAS[String(persona ?? "dog")] ?? PERSONAS.dog;
    const systemPrompt = `${character.prompt}\n${OBSERVATION_RULES}`;

    const apiKey = Deno.env.get("OPENROUTER_API_KEY");
    if (!apiKey) return json({ error: "OPENROUTER_API_KEY is not configured" }, 500);

    const model = Deno.env.get("OPENROUTER_MODEL") || DEFAULT_MODEL;

    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/jackmielke/vibe-check-dog",
        "X-Title": "Vibe Check iOS",
      },
      body: JSON.stringify({
        model,
        // A little randomness keeps repeat photos from getting identical lines,
        // but not so much that it starts inventing things it cannot see.
        temperature: 0.9,
        messages: [
          { role: "system", content: systemPrompt },
          {
            role: "user",
            content: [
              {
                type: "text",
                text:
                  "Rate this photo against your criteria and screen it for policy violations. " +
                  "Name something you can actually see in it.",
              },
              { type: "image_url", image_url: { url: imageData } },
            ],
          },
        ],
        tools: [
          {
            type: "function",
            function: {
              name: "rate_vibe",
              description: "Rate the vibe of the photo",
              parameters: {
                type: "object",
                properties: {
                  score: { type: "number", description: "Vibe score from 0 to 100 as a whole number." },
                  analysis: {
                    type: "string",
                    description:
                      "One or two sentences, under 30 words, in character. Must reference a " +
                      "specific detail visible in the photo. No invented comparisons.",
                  },
                  safe: { type: "boolean", description: "False only if the photo violates content policy" },
                },
                required: ["score", "analysis", "safe"],
                additionalProperties: false,
              },
            },
          },
        ],
        tool_choice: { type: "function", function: { name: "rate_vibe" } },
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      console.error("OpenRouter error:", response.status, body);
      if (response.status === 401) return json({ error: "OpenRouter rejected the API key." }, 500);
      if (response.status === 429) return json({ error: "Rate limit exceeded. Please try again later." }, 429);
      if (response.status === 402) return json({ error: "OpenRouter credits exhausted." }, 402);
      return json({ error: `AI provider error: ${response.status}` }, 502);
    }

    const data = await response.json();
    const toolCall = data.choices?.[0]?.message?.tool_calls?.[0];
    if (!toolCall) {
      console.error("No tool call in OpenRouter response:", JSON.stringify(data).slice(0, 800));
      return json({ error: "The vibe checker returned something unexpected. Try again." }, 502);
    }

    const result = JSON.parse(toolCall.function.arguments) as VibeResult;

    if (result.safe === false) {
      return json(
        { error: "That photo can't be vibe checked — it looks like it breaks our content rules." },
        422
      );
    }

    return json({
      score: Math.max(0, Math.min(100, Math.round(Number(result.score) || 0))),
      analysis: String(result.analysis ?? ""),
      persona: character.name,
    });
  } catch (error) {
    console.error("Error in analyze-vibe:", error);
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
