import { test, expect } from '@playwright/test';
import { hookConsoleAndNetwork } from './utils';

test('Chat panel answers a basic prompt', async ({ page, baseURL, request }) => {
  await hookConsoleAndNetwork(page);

  // Ping API health first so failures are obvious
  const apiBase = process.env.API_URL || 'http://localhost:8001';
  const health = await request.get(`${apiBase}/health`);
  expect(health.ok()).toBeTruthy();

  // Go to UI
  await page.goto(baseURL || '/');

  // Ensure chat panel is present
  const input = page.locator('[data-dev="chat-panel"] input, [data-dev="chat-section"] input');
  const askBtn = page.locator('[data-dev="chat-panel"] button:has-text("Ask"), button:has-text("Ask")');
  await expect(input).toBeVisible();

  // Ask a known question
  await input.fill('What is the LinkOps AIBOX for ZRS Management?');
  await askBtn.click();

  // Wait for answer (avoid stale "Error" messages)
  const answer = page.locator('[data-dev="chat-answer"]');
  await expect(answer).toBeVisible({ timeout: 45_000 });
  const text = await answer.textContent();

  expect(text && text.length > 5, 'Empty answer').toBeTruthy();
  expect(text?.toLowerCase()).not.toContain('sorry, chat failed');
  expect(text?.toLowerCase()).not.toContain('llm backend error');
});