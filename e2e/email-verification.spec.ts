import { randomUUID } from "node:crypto";
import { expect, test } from "@playwright/test";

// With no email provider configured the server accepts the message and prints it, which is enough to
// exercise the whole page: the reminder, asking for another email, and the page the link lands on.

test("someone who has not confirmed their email is reminded, can ask for another link, and the landing page reads well", async ({ page }) => {
  const email = `verify-${randomUUID()}@example.com`;
  await page.goto("/sign-in");
  await page.getByRole("button", { name: /create an account/i }).click();
  await page.getByLabel("Your name").fill("Vera");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill("family-test-password");
  await page.getByRole("button", { name: "Create parent account" }).click();
  await expect(page).toHaveURL(/onboarding/);
  await page.getByPlaceholder("The Hobbs family").fill("The Verify Family");
  await page.getByRole("button", { name: "Create our hub" }).click();
  await expect(page).toHaveURL(/settings$/);

  // Not blocked from the app, but reminded.
  const notice = page.getByRole("status").filter({ hasText: "isn’t confirmed yet" });
  await expect(notice).toBeVisible();
  await expect(notice).toContainText(email);

  await notice.getByRole("button", { name: "Send confirmation email" }).click();
  await expect(page.getByRole("status")).toContainText("We sent a confirmation link");
  await expect(page.getByRole("button", { name: "Send confirmation email" })).toHaveCount(0);

  // The session says the address is unconfirmed, which is what the phone app reads.
  const session = await page.request.get("/api/auth/get-session");
  const body = (await session.json()) as { user: { emailVerified: boolean } };
  expect(body.user.emailVerified).toBe(false);
});

test("the page a confirmation link ends on says what happened", async ({ page }) => {
  await page.goto("/email-verified");
  await expect(page.getByRole("heading", { name: "Email confirmed" })).toBeVisible();

  await page.goto("/email-verified?error=invalid_token");
  await expect(page.getByRole("heading", { name: "That link didn’t work" })).toBeVisible();
  await expect(page.getByText("ask for a new confirmation email")).toBeVisible();
});
