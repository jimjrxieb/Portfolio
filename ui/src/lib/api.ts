export const API_BASE =
  import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

export type ChatRequest = {
  message: string;
  namespace?: string;
  k?: number;
  filters?: Record<string, unknown>;
};

export type Citation = {
  text: string;
  score: number;
  metadata?: Record<string, unknown>;
};
export type ChatResponse = {
  answer: string;
  citations: Citation[];
  model: string;
};

export async function chat(
  req: ChatRequest,
  signal?: AbortSignal
): Promise<ChatResponse> {
  // Map to our backend API format
  const backendRequest = {
    message: req.message,
    audience_type: 'general',
    context: null,
  };

  const r = await fetch(`${API_BASE}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(backendRequest),
    signal,
  });

  if (!r.ok) {
    const detail = await safeJson(r);
    throw new Error(`Chat failed (${r.status}): ${JSON.stringify(detail)}`);
  }

  const response = await r.json();

  // Map backend response to frontend format
  return {
    answer:
      response.response ||
      response.text_response ||
      "I'm having trouble responding right now.",
    citations: [],
    model: 'sheyla-avatar',
  };
}

export async function makeAvatar(
  form: FormData
): Promise<{ avatar_id: string }> {
  const r = await fetch(`${API_BASE}/api/actions/avatar/create`, {
    method: 'POST',
    body: form,
  });
  if (!r.ok) {
    const detail = await safeJson(r);
    throw new Error(`Avatar create failed: ${JSON.stringify(detail)}`);
  }
  return r.json();
}

export async function talkAvatar(payload: {
  avatar_id: string;
  text: string;
  voice?: string; // server decides default if omitted
}): Promise<{ url: string }> {
  const r = await fetch(`${API_BASE}/api/actions/avatar/talk`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!r.ok) {
    const detail = await safeJson(r);
    throw new Error(`Avatar talk failed: ${JSON.stringify(detail)}`);
  }
  return r.json();
}

async function safeJson(r: Response) {
  try {
    return await r.json();
  } catch {
    return await r.text();
  }
}
