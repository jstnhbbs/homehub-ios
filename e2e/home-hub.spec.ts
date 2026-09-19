import { randomUUID } from "node:crypto";
import { expect, test } from "@playwright/test";

test("a parent can create a household and manage family profiles", async ({ page }) => {
  const birthdayParts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Chicago",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const birthdayMonth = birthdayParts.find((part) => part.type === "month")!.value;
  const birthdayDay = birthdayParts.find((part) => part.type === "day")!.value;
  const birthday = `2020-${birthdayMonth}-${birthdayDay}`;

  await page.goto("/sign-in");
  await page.getByRole("button", { name: /create an account/i }).click();
  await page.getByLabel("Your name").fill("Jamie");
  await page.getByLabel("Email").fill(`jamie-${randomUUID()}@example.com`);
  await page.getByLabel("Password").fill("family-test-password");
  await page.getByRole("button", { name: "Create parent account" }).click();

  await expect(page).toHaveURL(/onboarding/);
  await page.getByPlaceholder("The Hobbs family").fill("The Test Family");
  await page
    .getByPlaceholder("First child’s name (optional)")
    .fill("Alex");
  await page.getByRole("button", { name: "Create our hub" }).click();

  await expect(page).toHaveURL(/settings$/);
  await expect(page.getByText("The Test Family").first()).toBeVisible();
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth <=
        document.documentElement.clientWidth,
    ),
  ).toBe(true);

  await expect(page.getByText("Jamie", { exact: true }).first()).toBeVisible();

  await page.getByPlaceholder("Name").fill("Taylor");
  await page.getByRole("group", { name: "Profile type", exact: true })
    .getByText("adult", { exact: true }).click();
  await expect(page.getByRole("radio", { name: "adult", exact: true })).toBeChecked();
  await page.getByRole("button", { name: "Add family member" }).click();
  await expect(page.getByText("Taylor", { exact: true })).toBeVisible();

  const response = await page.request.get("/api/mobile/v1/profiles");
  expect(response.ok()).toBe(true);
  const profiles: { id: string; name: string }[] = await response.json();
  const child = profiles.find((profile) => profile.name === "Alex");
  expect(child).toBeDefined();
  await page.goto(`/settings/profiles/${child!.id}`);
  await page.getByLabel("Name").fill("Avery");
  await page.getByLabel("Birthday").fill(birthday);
  await page.getByTitle("Lavender").click();
  await page.getByRole("button", { name: "Save changes" }).click();

  await expect(page).toHaveURL(/settings$/);
  await expect(page.getByText("Avery")).toBeVisible();

  await page.goto("/dashboard");
  await expect(page.getByRole("heading", { name: "Today lives in the iOS app." })).toBeVisible();
});

test("the sign-in screen fits the active viewport", async ({ page }) => {
  await page.goto("/sign-in");
  await expect(page.getByRole("heading", { name: "Your week, together." })).toBeVisible();
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth <=
        document.documentElement.clientWidth,
    ),
  ).toBe(true);
});
