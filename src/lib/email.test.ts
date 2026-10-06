import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { outbox, sendEmail } from "@/lib/email";
import { EMAIL_VERIFIED_PATH, verificationEmail, verificationLink } from "@/lib/email-templates";

const message = { to: "pat@example.com", subject: "Hello", text: "Hi", html: "<p>Hi</p>" };

beforeEach(() => {
  outbox.length = 0;
  vi.stubEnv("RESEND_API_KEY", "");
  vi.stubEnv("EMAIL_FROM", "");
});

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("sendEmail", () => {
  it("keeps the message in the outbox when no provider is set up (development and tests)", async () => {
    await expect(sendEmail(message)).resolves.toBe(true);
    expect(outbox).toEqual([message]);
  });

  it("sends nothing in production without a provider, and says so rather than pretending", async () => {
    vi.stubEnv("NODE_ENV", "production");
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    await expect(sendEmail(message)).resolves.toBe(false);
    expect(outbox).toHaveLength(0);
    expect(warn).toHaveBeenCalledWith(expect.stringContaining("RESEND_API_KEY"));
  });

  it("posts the message to Resend with the key and the sender", async () => {
    vi.stubEnv("RESEND_API_KEY", "re_test_key");
    vi.stubEnv("EMAIL_FROM", "Beacon <hello@example.com>");
    const fetchMock = vi.fn().mockResolvedValue(new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    await expect(sendEmail(message)).resolves.toBe(true);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("https://api.resend.com/emails");
    expect((init.headers as Record<string, string>).Authorization).toBe("Bearer re_test_key");
    expect(JSON.parse(init.body as string)).toEqual({
      from: "Beacon <hello@example.com>",
      to: ["pat@example.com"],
      subject: "Hello",
      text: "Hi",
      html: "<p>Hi</p>",
    });
    expect(outbox).toHaveLength(0);
  });

  it("returns false, and does not throw, when the provider refuses", async () => {
    vi.stubEnv("RESEND_API_KEY", "re_test_key");
    vi.stubEnv("EMAIL_FROM", "hello@example.com");
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response('{"message":"domain not verified for pat@example.com"}', { status: 403 })));
    const error = vi.spyOn(console, "error").mockImplementation(() => {});

    await expect(sendEmail(message)).resolves.toBe(false);
    // The log carries the status, not the provider's reply, which can echo the address.
    expect(error).toHaveBeenCalledWith(expect.stringContaining("403"));
    expect(JSON.stringify(error.mock.calls)).not.toContain("pat@example.com");
  });

  it("returns false, and does not throw, when the provider cannot be reached", async () => {
    vi.stubEnv("RESEND_API_KEY", "re_test_key");
    vi.stubEnv("EMAIL_FROM", "hello@example.com");
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("fetch failed")));
    vi.spyOn(console, "error").mockImplementation(() => {});

    await expect(sendEmail(message)).resolves.toBe(false);
  });

  it("gives up on a slow provider", async () => {
    vi.stubEnv("RESEND_API_KEY", "re_test_key");
    vi.stubEnv("EMAIL_FROM", "hello@example.com");
    const fetchMock = vi.fn().mockResolvedValue(new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    await sendEmail(message);
    const init = fetchMock.mock.calls[0][1] as RequestInit;
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });
});

describe("verification email", () => {
  const raw = "https://hobbshomehub.vercel.app/api/auth/verify-email?token=abc.def&callbackURL=%2F";

  it("sends the link to our own confirmation page, whatever the sign-up asked for", () => {
    const link = new URL(verificationLink(raw));
    expect(link.origin + link.pathname).toBe("https://hobbshomehub.vercel.app/api/auth/verify-email");
    expect(link.searchParams.get("token")).toBe("abc.def");
    expect(link.searchParams.get("callbackURL")).toBe(EMAIL_VERIFIED_PATH);
  });

  it("is addressed to the person, with the link in both the text and the html", () => {
    const email = verificationEmail({ to: "pat@example.com", name: "Pat", url: raw });
    expect(email.to).toBe("pat@example.com");
    expect(email.subject).toBe("Confirm your email for Beacon");
    expect(email.text).toContain("Hi Pat,");
    expect(email.text).toContain("token=abc.def");
    expect(email.html).toContain("token=abc.def");
    expect(email.text).toContain("24 hours");
  });

  it("cannot be turned into markup by a name or an address", () => {
    const email = verificationEmail({ to: "x@example.com", name: `<img src=x onerror=alert(1)>"`, url: raw });
    expect(email.html).not.toContain("<img");
    expect(email.html).toContain("&lt;img");
  });

  it("copes with a blank name", () => {
    expect(verificationEmail({ to: "x@example.com", name: "  ", url: raw }).text).toContain("Hi there,");
  });
});
