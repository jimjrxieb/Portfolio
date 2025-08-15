export const API_BASE = import.meta.env.VITE_API_BASE || "";

export type ChatRequest = {
  message: string;
  namespace?: string;
  k?: number;
  filters?: Record<string, unknown>;
};

export type Citation = { text: string; score: number; metadata?: Record<string, unknown> };
export type ChatResponse = { answer: string; citations: Citation[]; model: string };

export async function chat(req: ChatRequest, signal?: AbortSignal): Promise<ChatResponse> {
  const r = await fetch(`${API_BASE}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(req),
    signal
  });
  if (!r.ok) {
    const detail = await safeJson(r);
    throw new Error(`Chat failed (${r.status}): ${JSON.stringify(detail)}`);
  }
  return r.json();
}

export async function makeAvatar(form: FormData): Promise<{ avatar_id: string }> {
  const r = await fetch(`${API_BASE}/api/actions/avatar/create`, {
    method: "POST",
    body: form
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
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  if (!r.ok) {
    const detail = await safeJson(r);
    throw new Error(`Avatar talk failed: ${JSON.stringify(detail)}`);
  }
  return r.json();
}

async function safeJson(r: Response) {
  try { return await r.json(); } catch { return await r.text(); }
}