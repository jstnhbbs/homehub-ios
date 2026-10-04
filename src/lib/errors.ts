/** Raised when someone has tried something too often. Mobile routes answer it with HTTP 429. */
export class RateLimitedError extends Error {
  constructor(message = "Too many attempts. Try again later.") {
    super(message);
    this.name = "RateLimitedError";
  }
}
