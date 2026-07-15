const MAX_BYTES = 2_000_000;
const FETCH_TIMEOUT_MS = 15_000;

function isPrivateHost(hostname: string) {
  const host = hostname.toLowerCase();
  if (
    host === "localhost" ||
    host.endsWith(".local") ||
    host.endsWith(".internal")
  ) {
    return true;
  }
  if (host.startsWith("127.")) return true;
  if (host.startsWith("10.")) return true;
  if (host.startsWith("192.168.")) return true;
  const match = /^172\.(\d+)\./.exec(host);
  if (match && Number(match[1]) >= 16 && Number(match[1]) <= 31) return true;
  return false;
}

export function assertImportableUrl(value: string) {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Enter a valid recipe URL.");
  }
  if (!["http:", "https:"].includes(url.protocol)) {
    throw new Error("Only http and https URLs are supported.");
  }
  if (isPrivateHost(url.hostname)) {
    throw new Error("That URL cannot be imported.");
  }
  return url;
}

export async function fetchRecipeHtml(url: string) {
  const parsed = assertImportableUrl(url);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const response = await fetch(parsed.toString(), {
      signal: controller.signal,
      redirect: "follow",
      headers: {
        Accept: "text/html,application/xhtml+xml",
        "User-Agent": "HomeHub Recipe Importer/1.0",
      },
    });
    if (!response.ok) {
      throw new Error("Could not load that recipe page.");
    }
    const contentType = response.headers.get("content-type") ?? "";
    if (
      contentType &&
      !contentType.includes("text/html") &&
      !contentType.includes("application/xhtml")
    ) {
      throw new Error("That URL does not look like a recipe page.");
    }

    const reader = response.body?.getReader();
    if (!reader) throw new Error("Could not read the recipe page.");

    const chunks: Uint8Array[] = [];
    let total = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_BYTES) {
        throw new Error("That recipe page is too large to import.");
      }
      chunks.push(value);
    }

    return new TextDecoder("utf-8").decode(
      chunks.reduce((buffer, chunk) => {
        const merged = new Uint8Array(buffer.length + chunk.length);
        merged.set(buffer);
        merged.set(chunk, buffer.length);
        return merged;
      }, new Uint8Array()),
    );
  } catch (error) {
    if (error instanceof Error && error.name === "AbortError") {
      throw new Error("The recipe page took too long to load.");
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}
