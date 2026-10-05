import { expect, test } from "@playwright/test";

// A page and an API route should both carry the headers, and the sign-in page (a client component)
// must still work under them, so a policy that breaks scripts or forms shows up here.
for (const path of ["/sign-in", "/privacy", "/api/mobile/v1/household"]) {
  test(`${path} sends the security headers`, async ({ request }) => {
    const response = await request.get(path);
    const headers = response.headers();
    expect(headers["x-content-type-options"]).toBe("nosniff");
    expect(headers["x-frame-options"]).toBe("DENY");
    expect(headers["referrer-policy"]).toBe("strict-origin-when-cross-origin");
    expect(headers["content-security-policy"]).toContain("frame-ancestors 'none'");
  });
}

test("the sign-in page still works with the headers on", async ({ page }) => {
  const problems: string[] = [];
  page.on("console", (message) => {
    if (/content security policy|refused to/i.test(message.text())) problems.push(message.text());
  });
  await page.goto("/sign-in");
  await expect(page.getByRole("button", { name: /sign in/i }).first()).toBeVisible();
  expect(problems).toEqual([]);
});
