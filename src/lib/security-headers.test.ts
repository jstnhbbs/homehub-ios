import { describe, expect, it } from "vitest";
import nextConfig from "../../next.config";

describe("security headers", () => {
  it("are set on every path, including the API", async () => {
    const rules = await nextConfig.headers!();
    expect(rules).toHaveLength(1);
    // Next's own pattern for "everything"; a narrower one would leave pages or API routes out.
    expect(rules[0].source).toBe("/:path*");
  });

  it("stop sniffing, framing and cross-site form posts", async () => {
    const [rule] = await nextConfig.headers!();
    const headers = Object.fromEntries(rule.headers.map((h) => [h.key, h.value]));
    expect(headers["X-Content-Type-Options"]).toBe("nosniff");
    expect(headers["X-Frame-Options"]).toBe("DENY");
    expect(headers["Referrer-Policy"]).toBe("strict-origin-when-cross-origin");
    expect(headers["Content-Security-Policy"]).toContain("frame-ancestors 'none'");
    expect(headers["Content-Security-Policy"]).toContain("form-action 'self'");
  });

  it("does not set a script policy, which would break the inline theme script", async () => {
    const [rule] = await nextConfig.headers!();
    const csp = rule.headers.find((h) => h.key === "Content-Security-Policy")!.value;
    expect(csp).not.toMatch(/script-src|default-src/);
  });
});
