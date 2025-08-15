import { Page } from '@playwright/test';

export async function hookConsoleAndNetwork(page: Page) {
  page.on('console', (msg) => {
    if (['error', 'warning'].includes(msg.type())) {
      console.log(`[browser ${msg.type()}]`, msg.text());
    }
  });
  page.on('pageerror', (err) => {
    console.log('[browser pageerror]', err.message);
  });
  page.on('requestfailed', (req) => {
    console.log('[network failed]', req.url(), req.failure()?.errorText);
  });
}