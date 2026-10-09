/**
 * An error whose message is written for the person using the app, so a mobile route may show it.
 * A plain `throw new Error("...")` in this codebase counts too; errors of any other class (a library's
 * own, a system error) are answered with a generic 500 so their wording stays in the server log.
 */
export class UserFacingError extends Error {}

/** Raised when someone has tried something too often. Mobile routes answer it with HTTP 429. */
export class RateLimitedError extends UserFacingError {
  constructor(message = "Too many attempts. Try again later.") {
    super(message);
    this.name = "RateLimitedError";
  }
}
