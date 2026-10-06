import { randomUUID } from "node:crypto";
import { expect, test } from "@playwright/test";

// Everything except Settings lives in the iOS app. The old web addresses (and the one a guest lands on
// after signing in) should say so, and anything that was never a page should still be a plain 404.

test("old section addresses explain that the page moved to the iOS app", async ({ page }) => {
  const email = `shell-${randomUUID()}@example.com`;
  await page.goto("/sign-in");
  await page.getByRole("button", { name: /create an account/i }).click();
  await page.getByLabel("Your name").fill("Shelly");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill("family-test-password");
  await page.getByRole("button", { name: "Create parent account" }).click();
  await expect(page).toHaveURL(/onboarding/);
  await page.getByPlaceholder("The Hobbs family").fill("The Shell Family");
  await page.getByRole("button", { name: "Create our hub" }).click();
  await expect(page).toHaveURL(/settings$/);

  for (const [path, title] of [
    ["/dashboard", "Today lives in the iOS app."],
    ["/calendar", "Calendar lives in the iOS app."],
    ["/naps", "Sleep lives in the iOS app."],
    ["/meals/recipes", "Meals lives in the iOS app."],
    ["/snacks", "Snacks lives in the iOS app."],
  ] as const) {
    await page.goto(path);
    await expect(page.getByRole("heading", { name: title })).toBeVisible();
  }

  const missing = await page.goto("/definitely-not-a-page");
  expect(missing?.status()).toBe(404);

  // The web header keeps the date but no longer carries a wall clock.
  await page.goto("/settings");
  await expect(page.locator("header").getByText(/\d{1,2}:\d{2}:\d{2}/)).toHaveCount(0);

  // No installable-app manifest any more.
  const manifest = await page.request.get("/manifest.webmanifest");
  expect(manifest.status()).toBe(404);
});
