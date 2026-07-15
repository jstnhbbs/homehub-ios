import { describe, expect, it } from "vitest";
import { decryptSecret, encryptSecret } from "./crypto";

describe("calendar credential encryption", () => {
  it("round trips a secret without storing plaintext", () => {
    process.env.CALENDAR_ENCRYPTION_KEY = "test-key-with-enough-entropy";
    const encrypted = encryptSecret("abcd-efgh-ijkl-mnop");
    expect(encrypted).not.toContain("abcd");
    expect(encrypted.split(".")).toHaveLength(3);
    expect(decryptSecret(encrypted)).toBe("abcd-efgh-ijkl-mnop");
  });

  it("rejects malformed ciphertext", () => {
    process.env.CALENDAR_ENCRYPTION_KEY = "test-key-with-enough-entropy";
    expect(() => decryptSecret("not-valid")).toThrow();
  });
});
