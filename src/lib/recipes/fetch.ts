import dns from "node:dns";
import http, { type IncomingHttpHeaders, type IncomingMessage } from "node:http";
import https from "node:https";
import net from "node:net";
import { Writable } from "node:stream";
import { pipeline } from "node:stream/promises";
import zlib from "node:zlib";

const MAX_BYTES = 2_000_000;
const TIMEOUT_MS = 15_000;
const MAX_REDIRECTS = 5;

/** Raised when a URL, or the address it leads to, is somewhere recipe import must not go. */
export class BlockedUrlError extends Error {
  constructor() {
    super("That URL cannot be imported.");
    this.name = "BlockedUrlError";
  }
}

export type FetchPolicy = {
  /** Whether a connection to this IP address may be made. */
  isAddressAllowed: (address: string) => boolean;
  /** Whether this port (as a number, 80 for an http URL without one) may be used. */
  isPortAllowed: (port: number) => boolean;
};

// MARK: Addresses

function ipv4Octets(address: string) {
  const parts = address.split(".");
  if (parts.length !== 4) return null;
  const octets = parts.map((part) => (/^\d{1,3}$/.test(part) ? Number(part) : NaN));
  return octets.every((octet) => octet >= 0 && octet <= 255) ? octets : null;
}

function isPrivateIpv4(octets: number[]) {
  const [a, b, c] = octets;
  return (
    a === 0 || // "this" network
    a === 10 ||
    (a === 100 && b >= 64 && b <= 127) || // carrier-grade NAT
    a === 127 || // loopback
    (a === 169 && b === 254) || // link-local, which includes cloud metadata services
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 0 && c === 0) || // IETF protocol assignments
    (a === 192 && b === 0 && c === 2) || // documentation
    (a === 192 && b === 168) ||
    (a === 198 && (b === 18 || b === 19)) || // benchmarking
    (a === 198 && b === 51 && c === 100) || // documentation
    (a === 203 && b === 0 && c === 113) || // documentation
    a >= 224 // multicast, reserved and broadcast
  );
}

/** The eight 16-bit groups of an IPv6 address, or null when it does not parse. */
function ipv6Groups(address: string): number[] | null {
  let text = address.toLowerCase();
  const zone = text.indexOf("%");
  if (zone !== -1) text = text.slice(0, zone);

  // A dotted IPv4 tail (::ffff:1.2.3.4) stands for the last two groups.
  const lastColon = text.lastIndexOf(":");
  const tail = text.slice(lastColon + 1);
  if (tail.includes(".")) {
    const octets = ipv4Octets(tail);
    if (!octets) return null;
    text =
      text.slice(0, lastColon + 1) +
      ((octets[0] << 8) | octets[1]).toString(16) +
      ":" +
      ((octets[2] << 8) | octets[3]).toString(16);
  }

  const halves = text.split("::");
  if (halves.length > 2) return null;
  const head = halves[0] ? halves[0].split(":") : [];
  const rest = halves.length === 2 && halves[1] ? halves[1].split(":") : [];
  const missing = 8 - head.length - rest.length;
  if (halves.length === 1 ? missing !== 0 : missing < 1) return null;
  const groups = [...head, ...Array(halves.length === 2 ? missing : 0).fill("0"), ...rest];
  if (groups.length !== 8) return null;
  const numbers = groups.map((group) => (/^[0-9a-f]{1,4}$/.test(group) ? parseInt(group, 16) : NaN));
  return numbers.every((value) => !Number.isNaN(value)) ? numbers : null;
}

function embeddedIpv4(high: number, low: number) {
  return [high >> 8, high & 0xff, low >> 8, low & 0xff];
}

/**
 * Whether an IP address is one a server should never fetch on a stranger's behalf: loopback,
 * private networks, link-local (cloud metadata lives there), multicast, reserved ranges, and any
 * IPv6 form that wraps one of those (IPv4-mapped, NAT64, 6to4). Anything that does not parse as an
 * IP address counts as private, so a mistake here fails closed.
 */
export function isPrivateAddress(address: string) {
  const host = address.replace(/^\[|\]$/g, "");
  if (net.isIPv4(host)) return isPrivateIpv4(ipv4Octets(host)!);
  if (!net.isIPv6(host)) return true;

  const groups = ipv6Groups(host);
  if (!groups) return true;
  const [g0, g1, g2, g3, g4, g5, g6, g7] = groups;

  if (g0 === 0 && g1 === 0 && g2 === 0 && g3 === 0 && g4 === 0) {
    if (g5 === 0xffff) return isPrivateIpv4(embeddedIpv4(g6, g7)); // ::ffff:a.b.c.d
    return true; // ::, ::1 and the deprecated IPv4-compatible block
  }
  if (g0 === 0x64 && g1 === 0xff9b && g2 === 0 && g3 === 0 && g4 === 0 && g5 === 0) {
    return isPrivateIpv4(embeddedIpv4(g6, g7)); // 64:ff9b::/96, NAT64
  }
  if (g0 === 0x2002) return isPrivateIpv4(embeddedIpv4(g1, g2)); // 6to4
  if (g0 === 0x2001 && (g1 === 0 || g1 === 0xdb8)) return true; // Teredo, documentation
  if (g0 === 0x100 && g1 === 0 && g2 === 0 && g3 === 0) return true; // discard-only
  if ((g0 & 0xfe00) === 0xfc00) return true; // unique local fc00::/7
  if ((g0 & 0xffc0) === 0xfe80) return true; // link-local fe80::/10
  if ((g0 & 0xffc0) === 0xfec0) return true; // deprecated site-local
  if ((g0 & 0xff00) === 0xff00) return true; // multicast
  return false;
}

export const defaultPolicy: FetchPolicy = {
  isAddressAllowed: (address) => !isPrivateAddress(address),
  // Recipe sites are on the standard web ports; anything else is how people probe internal services.
  isPortAllowed: (port) => port === 80 || port === 443,
};

type ResolveAll = (hostname: string) => Promise<Array<{ address: string; family: number }>>;

const resolveWithSystem: ResolveAll = (hostname) =>
  dns.promises.lookup(hostname, { all: true, verbatim: true });

/**
 * A `lookup` function for http(s).request. Checking a hostname before connecting leaves a gap: a
 * DNS answer can change between the check and the connection. Doing the check inside the lookup the
 * connection itself uses closes it, and every address returned must pass, so a name that resolves
 * to one public and one private address is refused.
 */
export function createSafeLookup(
  isAddressAllowed: FetchPolicy["isAddressAllowed"],
  resolve: ResolveAll = resolveWithSystem,
) {
  return (
    hostname: string,
    options: dns.LookupOptions,
    callback: (error: NodeJS.ErrnoException | null, address: string | dns.LookupAddress[], family?: number) => void,
  ) => {
    resolve(hostname).then(
      (addresses) => {
        if (addresses.length === 0 || !addresses.every((entry) => isAddressAllowed(entry.address))) {
          callback(new BlockedUrlError(), []);
          return;
        }
        if (options.all) {
          callback(null, addresses);
        } else {
          callback(null, addresses[0].address, addresses[0].family);
        }
      },
      (error: NodeJS.ErrnoException) => callback(error, []),
    );
  };
}

// MARK: URLs

export function assertImportableUrl(value: string, policy: FetchPolicy = defaultPolicy) {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Enter a valid recipe URL.");
  }
  if (!["http:", "https:"].includes(url.protocol)) {
    throw new Error("Only http and https URLs are supported.");
  }
  if (url.username || url.password) throw new BlockedUrlError();

  const port = url.port ? Number(url.port) : url.protocol === "https:" ? 443 : 80;
  if (!policy.isPortAllowed(port)) throw new BlockedUrlError();

  const hostname = url.hostname.replace(/^\[|\]$/g, "").toLowerCase();
  if (hostname === "localhost" || hostname.endsWith(".localhost") || hostname.endsWith(".local") || hostname.endsWith(".internal")) {
    throw new BlockedUrlError();
  }
  // An address written into the URL never goes through DNS, so it has to be judged here.
  if (net.isIP(hostname) && !policy.isAddressAllowed(hostname)) throw new BlockedUrlError();
  return url;
}

// MARK: Fetching

type Page = { status: number; headers: IncomingHttpHeaders; html: string };

function decoderFor(encoding: string | undefined) {
  switch ((encoding ?? "").toLowerCase()) {
    case "gzip":
    case "x-gzip":
      return zlib.createGunzip();
    case "deflate":
      return zlib.createInflate();
    case "br":
      return zlib.createBrotliDecompress();
    default:
      return null;
  }
}

async function readBody(response: IncomingMessage) {
  const chunks: Buffer[] = [];
  let total = 0;
  const sink = new Writable({
    write(chunk: Buffer, _encoding, done) {
      total += chunk.byteLength;
      // Counted after decompression, so a small file that expands enormously is stopped too.
      if (total > MAX_BYTES) {
        done(new Error("That recipe page is too large to import."));
        return;
      }
      chunks.push(chunk);
      done();
    },
  });
  const decoder = decoderFor(response.headers["content-encoding"] as string | undefined);
  await (decoder ? pipeline(response, decoder, sink) : pipeline(response, sink));
  return new TextDecoder("utf-8").decode(Buffer.concat(chunks));
}

function requestOnce(url: URL, policy: FetchPolicy, deadline: number): Promise<Page> {
  return new Promise<Page>((resolve, reject) => {
    const remaining = deadline - Date.now();
    if (remaining <= 0) {
      reject(new Error("The recipe page took too long to load."));
      return;
    }
    const transport = url.protocol === "https:" ? https : http;
    const request = transport.request(
      url,
      {
        method: "GET",
        lookup: createSafeLookup(policy.isAddressAllowed),
        headers: {
          Accept: "text/html,application/xhtml+xml",
          "Accept-Encoding": "gzip, deflate, br",
          "User-Agent": "Beacon Recipe Importer/1.0",
        },
      },
      (response) => {
        const status = response.statusCode ?? 0;
        if (status >= 300 && status < 400) {
          response.resume();
          resolve({ status, headers: response.headers, html: "" });
          return;
        }
        if (status < 200 || status >= 300) {
          response.resume();
          reject(new Error("Could not load that recipe page."));
          return;
        }
        const contentType = String(response.headers["content-type"] ?? "");
        if (contentType && !contentType.includes("text/html") && !contentType.includes("application/xhtml")) {
          response.resume();
          reject(new Error("That URL does not look like a recipe page."));
          return;
        }
        readBody(response).then(
          (html) => resolve({ status, headers: response.headers, html }),
          reject,
        );
      },
    );
    // One clock for the whole import, redirects included.
    const timer = setTimeout(() => {
      request.destroy(new Error("The recipe page took too long to load."));
    }, remaining);
    request.on("close", () => clearTimeout(timer));
    request.on("error", reject);
    request.end();
  });
}

/**
 * Fetches a recipe page for import. The destination is checked before connecting and again for
 * every redirect, the connection itself refuses private addresses (see `createSafeLookup`), and
 * the whole thing is capped in time and size.
 */
export async function fetchRecipeHtml(value: string, policy: FetchPolicy = defaultPolicy) {
  const deadline = Date.now() + TIMEOUT_MS;
  let url = assertImportableUrl(value, policy);

  for (let hop = 0; hop <= MAX_REDIRECTS; hop += 1) {
    let page: Page;
    try {
      page = await requestOnce(url, policy, deadline);
    } catch (error) {
      if (error instanceof BlockedUrlError) throw error;
      const code = (error as NodeJS.ErrnoException)?.code;
      if (typeof code === "string" && /^(ENOTFOUND|EAI_AGAIN|ECONNREFUSED|ECONNRESET|ETIMEDOUT|EHOSTUNREACH|ENETUNREACH|CERT_|ERR_TLS|DEPTH_ZERO|UNABLE_TO|SELF_SIGNED|ERR_SSL)/.test(code)) {
        throw new Error("Could not reach that website.");
      }
      throw error;
    }

    if (page.status >= 300 && page.status < 400) {
      const location = page.headers.location;
      if (!location) throw new Error("Could not load that recipe page.");
      // Each hop is judged like the first request, so a redirect can't lead somewhere private.
      url = assertImportableUrl(new URL(location, url).toString(), policy);
      continue;
    }
    return page.html;
  }
  throw new Error("That recipe page redirected too many times.");
}
