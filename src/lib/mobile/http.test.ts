import { APIError } from "better-auth/api";
import { afterEach, describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { RateLimitedError } from "@/lib/errors";
import { handleMobileError } from "@/lib/mobile/http";

async function answer(error: unknown) {
  const response = handleMobileError(error);
  return { status: response.status, body: (await response.json()) as { error: string } };
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe("handleMobileError", () => {
  it("keeps the message and 400 for an error a route threw on purpose", async () => {
    expect(await answer(new Error("Child profile not found."))).toEqual({
      status: 400,
      body: { error: "Child profile not found." },
    });
  });

  it("keeps the message of the app's own error classes", async () => {
    const { BlockedUrlError } = await import("@/lib/recipes/fetch");
    const { AccountDeletionBlockedError } = await import("@/lib/account-deletion");
    expect(await answer(new BlockedUrlError())).toEqual({
      status: 400,
      body: { error: "That URL cannot be imported." },
    });
    expect((await answer(new AccountDeletionBlockedError("Make another owner first."))).body.error).toBe(
      "Make another owner first.",
    );
  });

  it("keeps 401 for Unauthorized", async () => {
    expect((await answer(new Error("Unauthorized"))).status).toBe(401);
  });

  it("passes a Response a route threw (permission and household checks) straight through", async () => {
    const thrown = Response.json({ error: "You do not have permission to do that." }, { status: 403 });
    const response = handleMobileError(thrown);
    expect(response).toBe(thrown);
  });

  it("turns a validation failure into one readable sentence", async () => {
    const parsed = z.object({ profileId: z.string().uuid() }).safeParse({ profileId: "nope" });
    const result = await answer(parsed.error);
    expect(result.status).toBe(400);
    expect(result.body.error).toBe("Check profileId: Invalid UUID");
  });

  it("treats a body that is not JSON as a bad request, not a crash", async () => {
    const result = await answer(new SyntaxError("Unexpected token < in JSON at position 0"));
    expect(result).toEqual({ status: 400, body: { error: "The request could not be read." } });
  });

  it("answers too many attempts with 429", async () => {
    expect((await answer(new RateLimitedError("Slow down."))).status).toBe(429);
  });

  it("keeps the status and message of an authentication error", async () => {
    const result = await answer(new APIError("BAD_REQUEST", { message: "Invalid password" }));
    expect(result).toEqual({ status: 400, body: { error: "Invalid password" } });
    const unauthorized = await answer(new APIError("UNAUTHORIZED", { message: "Session expired" }));
    expect(unauthorized.status).toBe(401);
  });

  describe("server failures never leak their detail", () => {
    const sql = 'insert into "household_members" ("household_id", "user_id") values (?, ?)';

    it.each([
      [
        "a database error",
        Object.assign(new Error(`SQLITE_CONSTRAINT: UNIQUE constraint failed: users.email — ${sql}`), {
          name: "LibsqlError",
          code: "SQLITE_CONSTRAINT",
        }),
      ],
      [
        "a database error wrapped by Drizzle",
        Object.assign(new Error(`Failed query: ${sql}`), {
          name: "DrizzleQueryError",
          cause: Object.assign(new Error("no such table: household_members"), { name: "LibsqlError" }),
        }),
      ],
      ["a coding mistake", new TypeError("Cannot read properties of undefined (reading 'id')")],
      [
        "a library's own error",
        new (class BlobServiceNotAvailable extends Error {})("Vercel Blob: store_abc123 is not available (undefined)"),
      ],
      [
        "a system error",
        Object.assign(new Error("connect ECONNREFUSED 10.0.0.4:443 household_members"), { code: "ECONNREFUSED" }),
      ],
    ])("%s", async (_label, error) => {
      const log = vi.spyOn(console, "error").mockImplementation(() => {});
      const result = await answer(error);
      expect(result.status).toBe(500);
      expect(result.body.error).toBe("Something went wrong on our end. Try again in a moment.");
      expect(JSON.stringify(result.body)).not.toMatch(/SQLITE|household_members|undefined|users\.email/);
      // The detail still reaches the server log, which is where it belongs.
      expect(log).toHaveBeenCalledTimes(1);
    });
  });
});
