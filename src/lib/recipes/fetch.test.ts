import dns from "node:dns";
import { gzipSync } from "node:zlib";
import http from "node:http";
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import {
  assertImportableUrl,
  BlockedUrlError,
  createSafeLookup,
  fetchRecipeHtml,
  isPrivateAddress,
  type FetchPolicy,
} from "@/lib/recipes/fetch";

describe("isPrivateAddress", () => {
  it.each([
    // IPv4: loopback, private networks, link-local (cloud metadata), CGNAT, reserved
    "127.0.0.1", "127.8.9.10", "0.0.0.0", "10.0.0.1", "10.255.255.255",
    "172.16.0.1", "172.31.255.255", "192.168.1.1", "169.254.169.254", "100.64.0.1", "100.127.255.255",
    "192.0.0.1", "192.0.2.1", "198.18.0.1", "198.19.255.255", "198.51.100.7", "203.0.113.7",
    "224.0.0.1", "239.255.255.250", "240.0.0.1", "255.255.255.255",
    // IPv6 loopback, unspecified, unique local, link-local, multicast
    "::1", "::", "[::1]", "fc00::1", "fd12:3456:789a::1", "fe80::1", "fe80::1%eth0", "ff02::1",
    // IPv6 forms that wrap an IPv4 address
    "::ffff:127.0.0.1", "::ffff:7f00:1", "::ffff:169.254.169.254", "::ffff:10.0.0.1",
    "64:ff9b::7f00:1", "64:ff9b::a9fe:a9fe", "2002:7f00:1::", "2002:a9fe:a9fe::1",
    // other special-purpose IPv6
    "2001:db8::1", "2001::1", "100::1", "::7f00:1",
    // things that are not addresses at all fail closed
    "", "not-an-ip", "1.2.3", "999.1.1.1", "1:2:3",
  ])("blocks %j", (address) => {
    expect(isPrivateAddress(address)).toBe(true);
  });

  it.each([
    "8.8.8.8", "1.1.1.1", "93.184.216.34", "172.15.255.255", "172.32.0.1", "100.63.255.255", "100.128.0.1",
    "169.253.1.1", "192.169.0.1", "198.17.255.255", "198.20.0.1", "223.255.255.255",
    "2606:4700:4700::1111", "2001:4860:4860::8888", "2a00:1450:4001:81b::200e",
    "::ffff:8.8.8.8", "64:ff9b::808:808", "2002:808:808::1",
  ])("allows %j", (address) => {
    expect(isPrivateAddress(address)).toBe(false);
  });
});

describe("assertImportableUrl", () => {
  it.each([
    "http://localhost/recipe",
    "http://LOCALHOST./recipe".replace("LOCALHOST.", "localhost"),
    "http://app.localhost/recipe",
    "http://printer.local/recipe",
    "http://db.internal/recipe",
    "http://127.0.0.1/recipe",
    "http://2130706433/recipe", // 127.0.0.1 written as one number; the URL parser normalises it
    "http://0x7f.1/recipe",
    "http://[::1]/recipe",
    "http://[::ffff:127.0.0.1]/recipe",
    "http://169.254.169.254/latest/meta-data/",
    "http://10.0.0.5/recipe",
    "https://user:secret@example.com/recipe",
    "https://example.com:6379/recipe",
    "http://example.com:8080/recipe",
  ])("blocks %s", (value) => {
    expect(() => assertImportableUrl(value)).toThrow(BlockedUrlError);
  });

  it("rejects things that are not web URLs, with a plain message", () => {
    expect(() => assertImportableUrl("not a url")).toThrow("Enter a valid recipe URL.");
    expect(() => assertImportableUrl("ftp://example.com/recipe")).toThrow("Only http and https URLs are supported.");
    expect(() => assertImportableUrl("file:///etc/passwd")).toThrow("Only http and https URLs are supported.");
  });

  it("accepts an ordinary recipe URL", () => {
    expect(assertImportableUrl("https://example.com/recipes/pancakes").hostname).toBe("example.com");
    expect(assertImportableUrl("http://example.com/recipes/pancakes").port).toBe("");
  });
});

describe("createSafeLookup", () => {
  const allowPublic: FetchPolicy["isAddressAllowed"] = (address) => !isPrivateAddress(address);
  const lookupFor = (answers: Record<string, string[]>) =>
    createSafeLookup(allowPublic, async (hostname) =>
      (answers[hostname] ?? []).map((address) => ({ address, family: address.includes(":") ? 6 : 4 })),
    );
  const run = (lookup: ReturnType<typeof createSafeLookup>, hostname: string, all = true) =>
    new Promise<{ error: unknown; result: unknown }>((resolve) => {
      lookup(hostname, { all }, (error, result) => resolve({ error, result }));
    });

  it("lets a name through when everything it resolves to is public", async () => {
    const { error, result } = await run(lookupFor({ "recipes.example": ["93.184.216.34"] }), "recipes.example");
    expect(error).toBeNull();
    expect(result).toEqual([{ address: "93.184.216.34", family: 4 }]);
  });

  it("answers a single address when that is what was asked for", async () => {
    const { result } = await run(lookupFor({ "recipes.example": ["93.184.216.34"] }), "recipes.example", false);
    expect(result).toBe("93.184.216.34");
  });

  it("refuses a name that resolves to a private address (DNS pointed at the inside)", async () => {
    const { error } = await run(lookupFor({ "evil.example": ["10.0.0.5"] }), "evil.example");
    expect(error).toBeInstanceOf(BlockedUrlError);
  });

  it("refuses a name with one public and one private address, the rebinding trick", async () => {
    const { error } = await run(lookupFor({ "evil.example": ["93.184.216.34", "169.254.169.254"] }), "evil.example");
    expect(error).toBeInstanceOf(BlockedUrlError);
  });

  it("refuses a name that resolves to nothing, and passes real resolver failures on", async () => {
    expect((await run(lookupFor({}), "nothing.example")).error).toBeInstanceOf(BlockedUrlError);
    const failing = createSafeLookup(allowPublic, async () => {
      throw Object.assign(new Error("getaddrinfo ENOTFOUND"), { code: "ENOTFOUND" });
    });
    expect(((await run(failing, "gone.example")).error as NodeJS.ErrnoException).code).toBe("ENOTFOUND");
  });
});

describe("fetchRecipeHtml against a local server", () => {
  // The default policy refuses loopback, so these tests allow it deliberately and only on 127.0.0.1.
  const allowLocal: FetchPolicy = {
    isAddressAllowed: (address) => address === "127.0.0.1",
    isPortAllowed: () => true,
  };
  const allowLocalOnlyForPorts = (): Pick<FetchPolicy, "isPortAllowed"> => ({ isPortAllowed: () => true });
  let server: http.Server;
  let base = "";
  const page = "<html><body>Pancakes</body></html>";

  beforeAll(async () => {
    server = http.createServer((request, response) => {
      const url = request.url ?? "/";
      if (url === "/page") {
        response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" }).end(page);
      } else if (url === "/gzip") {
        response.writeHead(200, { "Content-Type": "text/html", "Content-Encoding": "gzip" }).end(gzipSync(page));
      } else if (url === "/redirect") {
        response.writeHead(302, { Location: "/page" }).end();
      } else if (url === "/loop") {
        response.writeHead(302, { Location: "/loop" }).end();
      } else if (url === "/to-private") {
        response.writeHead(302, { Location: "http://10.0.0.5/admin" }).end();
      } else if (url === "/to-metadata") {
        response.writeHead(302, { Location: "http://169.254.169.254/latest/meta-data/" }).end();
      } else if (url === "/json") {
        response.writeHead(200, { "Content-Type": "application/json" }).end("{}");
      } else if (url === "/big") {
        response.writeHead(200, { "Content-Type": "text/html" });
        response.end("x".repeat(2_500_000));
      } else if (url === "/bomb") {
        // Tiny on the wire, huge once unpacked.
        response.writeHead(200, { "Content-Type": "text/html", "Content-Encoding": "gzip" }).end(gzipSync("x".repeat(5_000_000)));
      } else if (url === "/missing") {
        response.writeHead(404).end();
      } else if (url === "/hang") {
        // Never answers.
      } else {
        response.writeHead(500).end();
      }
    });
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });

  afterAll(() => {
    server.closeAllConnections();
    server.close();
  });

  it("returns the page", async () => {
    expect(await fetchRecipeHtml(`${base}/page`, allowLocal)).toBe(page);
  });

  it("unpacks a compressed page", async () => {
    expect(await fetchRecipeHtml(`${base}/gzip`, allowLocal)).toBe(page);
  });

  it("follows a redirect", async () => {
    expect(await fetchRecipeHtml(`${base}/redirect`, allowLocal)).toBe(page);
  });

  it("gives up on a redirect loop", async () => {
    await expect(fetchRecipeHtml(`${base}/loop`, allowLocal)).rejects.toThrow("redirected too many times");
  });

  it("refuses a redirect that leads to a private address", async () => {
    await expect(fetchRecipeHtml(`${base}/to-private`, allowLocal)).rejects.toBeInstanceOf(BlockedUrlError);
    await expect(fetchRecipeHtml(`${base}/to-metadata`, allowLocal)).rejects.toBeInstanceOf(BlockedUrlError);
  });

  it("refuses to connect to loopback at all under the default policy", async () => {
    await expect(fetchRecipeHtml(`${base}/page`)).rejects.toBeInstanceOf(BlockedUrlError);
  });

  it("refuses pages that are not HTML, missing, or too big", async () => {
    await expect(fetchRecipeHtml(`${base}/json`, allowLocal)).rejects.toThrow("does not look like a recipe page");
    await expect(fetchRecipeHtml(`${base}/missing`, allowLocal)).rejects.toThrow("Could not load that recipe page.");
    await expect(fetchRecipeHtml(`${base}/big`, allowLocal)).rejects.toThrow("too large to import");
  });

  it("stops a compressed page that expands past the limit", async () => {
    await expect(fetchRecipeHtml(`${base}/bomb`, allowLocal)).rejects.toThrow("too large to import");
  });

  describe("when DNS points a public-looking name at this machine", () => {
    // A name that is not an address passes the URL check, so only the connection can stop it.
    const answer = (address: string) =>
      vi.spyOn(dns.promises, "lookup").mockResolvedValue([{ address, family: 4 }] as never);

    it("refuses to connect, on the real connection", async () => {
      const lookup = answer("127.0.0.1");
      const anyPort: FetchPolicy = { ...allowLocalOnlyForPorts(), isAddressAllowed: (a) => !isPrivateAddress(a) };
      const port = new URL(base).port;
      await expect(fetchRecipeHtml(`http://rebind.example:${port}/page`, anyPort)).rejects.toBeInstanceOf(BlockedUrlError);
      expect(lookup).toHaveBeenCalled();
      lookup.mockRestore();
    });

    it("connects to exactly the address it validated when the policy allows it", async () => {
      const lookup = answer("127.0.0.1");
      const port = new URL(base).port;
      expect(await fetchRecipeHtml(`http://rebind.example:${port}/page`, allowLocal)).toBe(page);
      expect(lookup).toHaveBeenCalled();
      lookup.mockRestore();
    });
  });

  it("says so when nothing is listening", async () => {
    const closed = http.createServer();
    await new Promise<void>((resolve) => closed.listen(0, "127.0.0.1", resolve));
    const port = (closed.address() as AddressInfo).port;
    await new Promise<void>((resolve) => closed.close(() => resolve()));
    await expect(fetchRecipeHtml(`http://127.0.0.1:${port}/page`, allowLocal)).rejects.toThrow("Could not reach that website.");
  });
});
