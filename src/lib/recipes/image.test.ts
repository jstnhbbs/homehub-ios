import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const blob = vi.hoisted(() => ({
  list: vi.fn(),
  del: vi.fn(async () => undefined),
  put: vi.fn(),
}));
vi.mock("@vercel/blob", () => blob);

import { deleteAllRecipeImages, sniffImageType } from "@/lib/recipes/image";

const store = "https://abc.public.blob.vercel-storage.com";

beforeEach(() => {
  process.env.BLOB_READ_WRITE_TOKEN = "test-token";
  blob.list.mockReset();
  blob.del.mockClear();
});

afterEach(() => {
  delete process.env.BLOB_READ_WRITE_TOKEN;
  vi.restoreAllMocks();
});

describe("deleteAllRecipeImages", () => {
  it("removes every photo in one recipe's folder, and nothing outside it", async () => {
    blob.list.mockResolvedValueOnce({
      blobs: [{ url: `${store}/recipes/h1/r1/photo-a.jpg` }, { url: `${store}/recipes/h1/r1/photo-b.jpg` }],
      hasMore: false,
    });
    await deleteAllRecipeImages("h1", "r1");
    expect(blob.list).toHaveBeenCalledWith({ prefix: "recipes/h1/r1/", cursor: undefined });
    expect(blob.del).toHaveBeenCalledWith([`${store}/recipes/h1/r1/photo-a.jpg`, `${store}/recipes/h1/r1/photo-b.jpg`]);
  });

  it("follows every page for a whole household", async () => {
    blob.list
      .mockResolvedValueOnce({ blobs: [{ url: `${store}/recipes/h1/r1/a.jpg` }], hasMore: true, cursor: "next" })
      .mockResolvedValueOnce({ blobs: [{ url: `${store}/recipes/h1/r2/b.jpg` }], hasMore: false });
    await deleteAllRecipeImages("h1");
    expect(blob.list).toHaveBeenNthCalledWith(1, { prefix: "recipes/h1/", cursor: undefined });
    expect(blob.list).toHaveBeenNthCalledWith(2, { prefix: "recipes/h1/", cursor: "next" });
    expect(blob.del).toHaveBeenCalledTimes(2);
  });

  it("never fails the delete that called it", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    blob.list.mockRejectedValueOnce(new Error("store unavailable"));
    await expect(deleteAllRecipeImages("h1", "r1")).resolves.toBeUndefined();
  });
});

describe("sniffImageType", () => {
  it("goes by the bytes", () => {
    expect(sniffImageType(new Uint8Array([0xff, 0xd8, 0xff, 0xe0]))).toBe("image/jpeg");
    expect(sniffImageType(new TextEncoder().encode("<svg></svg>"))).toBeNull();
  });
});
