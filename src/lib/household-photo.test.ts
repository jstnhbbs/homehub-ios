import { describe, expect, it } from "vitest";
import { hasHouseholdPhoto } from "@/lib/household-photo-url";

describe("hasHouseholdPhoto", () => {
  it("accepts managed blob URLs", () => {
    expect(
      hasHouseholdPhoto(
        "https://abc.public.blob.vercel-storage.com/households/hh-1/photo.jpg",
      ),
    ).toBe(true);
  });

  it("rejects profile photo blob URLs", () => {
    expect(
      hasHouseholdPhoto(
        "https://abc.public.blob.vercel-storage.com/profiles/p-1/photo.jpg",
      ),
    ).toBe(false);
  });

  it("accepts local development household photos", () => {
    expect(
      hasHouseholdPhoto("http://localhost:3000/household-photos/hh-1/photo.jpg"),
    ).toBe(true);
  });

  it("treats empty values as no photo", () => {
    expect(hasHouseholdPhoto(null)).toBe(false);
    expect(hasHouseholdPhoto("")).toBe(false);
    expect(hasHouseholdPhoto("sparkles")).toBe(false);
  });
});
