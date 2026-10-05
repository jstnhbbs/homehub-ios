import { randomUUID } from "node:crypto";
import { expect, test, type Browser, type Page } from "@playwright/test";

const baseURL = "http://127.0.0.1:3000";

async function signUp(page: Page, name: string) {
  const email = `${name.toLowerCase()}-${randomUUID()}@example.com`;
  await page.goto("/sign-in");
  await page.getByRole("button", { name: /create an account/i }).click();
  await page.getByLabel("Your name").fill(name);
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill("family-test-password");
  await page.getByRole("button", { name: "Create parent account" }).click();
  await expect(page).toHaveURL(/onboarding/);
  return email;
}

async function newPerson(browser: Browser, name: string) {
  const context = await browser.newContext({ baseURL });
  const page = await context.newPage();
  const email = await signUp(page, name);
  return { context, page, email };
}

test("a parent and a guest join with the codes, and the guest never sees what the parent can", async ({ page, browser }) => {
  // The owner makes the household and reads the two codes the way the app does.
  const ownerEmail = await signUp(page, "Owen");
  await page.getByPlaceholder("The Hobbs family").fill("The Join Family");
  await page.getByRole("button", { name: "Create our hub" }).click();
  await expect(page).toHaveURL(/settings$/);

  const codesResponse = await page.request.get("/api/mobile/v1/household");
  expect(codesResponse.ok()).toBe(true);
  const { inviteCode, guestInviteCode } = (await codesResponse.json()) as { inviteCode: string; guestInviteCode: string };
  expect(inviteCode).toMatch(/^[A-HJ-NP-Z2-9]{10}$/);
  expect(guestInviteCode).toMatch(/^[A-HJ-NP-Z2-9]{10}$/);

  // The owner's own settings page shows both, as it should.
  await expect(page.getByText(inviteCode)).toBeVisible();
  await expect(page.getByText(guestInviteCode)).toBeVisible();

  // A second parent joins. The code is typed in lower case with a hyphen, the way people do.
  const parent = await newPerson(browser, "Pat");
  const typed = `${inviteCode.slice(0, 5)}-${inviteCode.slice(5)}`.toLowerCase();
  await parent.page.getByPlaceholder("PARENT12").fill(typed);
  await parent.page.getByRole("button", { name: /join/i }).first().click();
  await expect(parent.page).toHaveURL(/settings$/);
  await expect(parent.page.getByText("The Join Family").first()).toBeVisible();
  // A parent is allowed to see the codes and the members' emails.
  await expect(parent.page.getByText(inviteCode)).toBeVisible();
  await expect(parent.page.getByText(ownerEmail)).toBeVisible();

  // A guest joins with the guest code. The web settings page is not for guests: they are sent to
  // the dashboard, including when they go to /settings themselves.
  const guest = await newPerson(browser, "Gus");
  await guest.page.getByPlaceholder("GUEST12").fill(guestInviteCode);
  await guest.page.getByRole("button", { name: /guest/i }).first().click();
  await expect(guest.page).toHaveURL(/dashboard$/);
  await expect(guest.page.getByText("The Join Family").first()).toBeVisible();

  await guest.page.goto("/settings");
  await expect(guest.page).toHaveURL(/dashboard$/);

  // Nothing on the pages a guest can open lets anyone in or names anyone's address.
  for (const path of ["/dashboard", "/privacy"]) {
    await guest.page.goto(path);
    const html = await guest.page.content();
    for (const secret of [inviteCode, guestInviteCode, ownerEmail, parent.email, guest.email]) {
      expect(html, `${path} should not contain ${secret}`).not.toContain(secret);
    }
  }

  // The same through the API the app uses: the codes and emails come back empty.
  const household = await (await guest.page.request.get("/api/mobile/v1/household")).json();
  expect(household).toMatchObject({ inviteCode: "", guestInviteCode: "", role: "guest" });
  const members = (await (await guest.page.request.get("/api/mobile/v1/household/members")).json()) as Array<{ name: string; email: string; role: string }>;
  expect(members.map((member) => member.name).sort()).toEqual(["Gus", "Owen", "Pat"]);
  expect(members.every((member) => member.email === "")).toBe(true);

  await parent.context.close();
  await guest.context.close();
});
