import { randomUUID } from "node:crypto";
import { expect, test } from "@playwright/test";

test("a parent can create a household and use the hub", async ({ page }) => {
  const birthdayParts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Chicago",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const birthdayMonth = birthdayParts.find((part) => part.type === "month")!.value;
  const birthdayDay = birthdayParts.find((part) => part.type === "day")!.value;
  const birthday = `2020-${birthdayMonth}-${birthdayDay}`;
  const birthdayLabel = new Intl.DateTimeFormat("en-US", {
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${birthday}T12:00:00Z`));

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

  await expect(page).toHaveURL(/dashboard/);
  await expect(page.getByText("Here’s what’s happening today.")).toBeVisible();
  await expect(page.getByText("The Test Family")).toBeVisible();
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth <=
        document.documentElement.clientWidth,
    ),
  ).toBe(true);

  await page.getByRole("link", { name: "Chores", exact: true }).click();
  await page.getByPlaceholder("Feed the dog").fill("Set the table");
  await page.getByRole("button", { name: "Add chore" }).click();
  await page.getByText("Edit Set the table", { exact: true }).click();
  await page.getByLabel("Chore title").fill("Clear the table");
  await page.getByRole("button", { name: "Save chore" }).click();
  await expect(
    page.getByRole("button", { name: /Clear the table/ }),
  ).toBeVisible();

  await page.getByRole("link", { name: "Routines", exact: true }).click();
  await page.getByPlaceholder("Bedtime routine").fill("Morning launch");
  await page
    .getByPlaceholder("Brush teeth\nPack backpack\nPut shoes by the door")
    .fill("Brush teeth\nPack backpack");
  await page.getByRole("button", { name: "Add routine" }).click();
  await page.getByText("Edit Morning launch", { exact: true }).click();
  await page.getByLabel("Routine name").fill("School morning");
  await page.getByLabel("Routine steps").fill("Brush teeth\nGrab lunch");
  await page.getByRole("button", { name: "Save routine" }).click();
  await expect(
    page.getByRole("heading", { name: "School morning" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: /Grab lunch/ }),
  ).toBeVisible();

  await page.getByRole("link", { name: "Settings", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Photo", exact: true }),
  ).toHaveCount(2);
  await expect(page.getByRole("link", { name: "Edit Jamie" })).toBeVisible();

  await page.getByPlaceholder("Name").fill("Taylor");
  await page.getByText("adult", { exact: true }).click();
  await page.getByRole("button", { name: "Add family member" }).click();
  await expect(page.getByRole("link", { name: "Edit Taylor" })).toBeVisible();

  await page.getByRole("link", { name: "Edit Alex" }).click();
  await page.getByLabel("Name").fill("Avery");
  await page.getByLabel("Birthday").fill(birthday);
  await page.getByTitle("Lavender").click();
  await page.getByRole("button", { name: "Save changes" }).click();

  await expect(page).toHaveURL(/settings$/);
  await expect(page.getByText("Avery")).toBeVisible();
  await expect(page.getByText(`Birthday: ${birthdayLabel}`)).toBeVisible();

  await page.getByRole("link", { name: "Calendar", exact: true }).click();
  await expect(page.getByText("Avery’s birthday")).toBeVisible();
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
