import { describe, expect, it } from "vitest";
import { webUrl } from "@/lib/web-url";

describe("webUrl", () => {
  it.each(["https://example.com/recipe", "http://example.com", "HTTPS://EXAMPLE.COM/x"])("accepts %s", (value) => {
    expect(webUrl.safeParse(value).success).toBe(true);
  });

  it.each([
    "file:///etc/passwd",
    "javascript:alert(1)",
    "sms:+15555550123",
    "tel:+15555550123",
    "ftp://example.com/x",
    "not a url",
    `https://example.com/${"a".repeat(2100)}`,
  ])("rejects %s", (value) => {
    expect(webUrl.safeParse(value).success).toBe(false);
  });
});
