import { expect, test } from "@playwright/test";

test("a parent can create a household and use the hub", async ({ page }) => {
  await page.goto("/sign-in");
  await page.getByRole("button", { name: /create an account/i }).click();
  await page.getByLabel("Your name").fill("Jamie");
  await page.getByLabel("Email").fill(`jamie-${Date.now()}@example.com`);
  await page.getByLabel("Password").fill("family-test-password");
  await page.getByRole("button", { name: "Create parent account" }).click();

  await expect(page).toHaveURL(/onboarding/);
  await page.getByPlaceholder("The Hobbs family").fill("The Test Family");
  await page
    .getByPlaceholder("First child’s name (optional)")
    .fill("Alex");
  await page.getByRole("button", { name: "Create our hub" }).click();

  await expect(page).toHaveURL(/dashboard/);
  await expect(page.getByText("Here’s what’s happening today.")).toBeVisible();
  await expect(page.getByText("The Test Family")).toBeVisible();

  await page.getByRole("link", { name: "Chores", exact: true }).click();
  await page.getByPlaceholder("Feed the dog").fill("Set the table");
  await page.getByRole("button", { name: "Add chore" }).click();
  await expect(page.getByText("Set the table")).toBeVisible();
});

test("the sign-in screen fits an iPad landscape viewport", async ({ page }) => {
  await page.goto("/sign-in");
  await expect(page.getByRole("heading", { name: "Your week, together." })).toBeVisible();
  expect((await page.locator("body").evaluate((body) => body.scrollWidth))).toBeLessThanOrEqual(1366);
});
