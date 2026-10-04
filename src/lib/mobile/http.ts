import { headers } from "next/headers";
import { APIError } from "better-auth/api";
import { NextResponse } from "next/server";
import { ZodError } from "zod";
import { auth } from "@/lib/auth";
import { getCurrentHousehold } from "@/lib/household";
import { RateLimitedError } from "@/lib/errors";
import { canManageHousehold } from "@/lib/household-roles";
import { ensureMemberProfiles } from "@/lib/member-profiles";

export async function getMobileSession() {
  return auth.api.getSession({ headers: await headers() });
}

export async function requireMobileUser() {
  const session = await getMobileSession();
  if (!session) {
    throw mobileError("Unauthorized", 401);
  }
  return session.user;
}

export async function requireMobileHousehold() {
  const user = await requireMobileUser();
  const household = await getCurrentHousehold(user.id);
  if (!household) {
    throw mobileError("Household required", 404);
  }
  await ensureMemberProfiles(household.id);
  return household;
}

/** The session user and their household from a single session lookup, for routes that need both. */
export async function requireMobileContext() {
  const user = await requireMobileUser();
  const household = await getCurrentHousehold(user.id);
  if (!household) {
    throw mobileError("Household required", 404);
  }
  await ensureMemberProfiles(household.id);
  return { user, household };
}

export async function requireMobileParentHousehold() {
  const household = await requireMobileHousehold();
  if (!canManageHousehold(household.role)) {
    throw mobileError("You do not have permission to do that.", 403);
  }
  return household;
}

export function mobileError(message: string, status = 400) {
  return NextResponse.json({ error: message }, { status });
}

export function mobileJson<T>(data: T, status = 200) {
  return NextResponse.json(data, { status });
}

/** Errors that mean the server or its database failed, not that the request was wrong. */
function isInfrastructureError(error: unknown) {
  if (
    error instanceof TypeError ||
    error instanceof ReferenceError ||
    error instanceof RangeError ||
    error instanceof URIError ||
    error instanceof EvalError
  ) {
    return true;
  }
  let current: unknown = error;
  // Drizzle wraps the driver's error, so look through `cause` too.
  for (let depth = 0; depth < 4 && current instanceof Error; depth += 1) {
    const code = (current as { code?: unknown }).code;
    if (
      current.name === "LibsqlError" ||
      current.name === "DrizzleQueryError" ||
      (typeof code === "string" && code.startsWith("SQLITE_"))
    ) {
      return true;
    }
    current = current.cause;
  }
  return false;
}

function describeValidationError(error: ZodError) {
  const issue = error.issues[0];
  if (!issue) return "The request was not valid.";
  const field = issue.path.join(".");
  return field ? `Check ${field}: ${issue.message}` : issue.message;
}

export function handleMobileError(error: unknown) {
  if (error instanceof Response) return error;
  if (error instanceof NextResponse) return error;
  if (error instanceof ZodError) return mobileError(describeValidationError(error), 400);
  if (error instanceof SyntaxError) {
    return mobileError("The request could not be read.", 400);
  }
  if (error instanceof RateLimitedError) return mobileError(error.message, 429);
  if (error instanceof APIError) {
    // Better Auth's own errors (wrong password and the like) already carry a status and a message.
    return mobileError(error.body?.message ?? error.message, error.statusCode);
  }
  if (isInfrastructureError(error)) {
    // The detail (SQL, column names, stack) stays in the server log, not in the response.
    console.error("[mobile api]", error);
    return mobileError("Something went wrong on our end. Try again in a moment.", 500);
  }
  const message = error instanceof Error ? error.message : "Request failed.";
  return mobileError(message, message === "Unauthorized" ? 401 : 400);
}

export function serializeHousehold(
  household: NonNullable<Awaited<ReturnType<typeof getCurrentHousehold>>>,
) {
  // Invite codes let whoever holds them join (the parent code as a parent), so only people who can
  // already manage the household get them. Guests get empty strings rather than missing keys,
  // because older app versions decode both fields as required.
  const canSeeInviteCodes = canManageHousehold(household.role);
  return {
    id: household.id,
    name: household.name,
    timezone: household.timezone,
    weekStartsOn: household.weekStartsOn,
    inviteCode: canSeeInviteCodes ? household.inviteCode : "",
    guestInviteCode: canSeeInviteCodes ? household.guestInviteCode : "",
    snackOptions: household.snackOptions,
    snacksPerChild: household.snacksPerChild,
    ownerName: household.ownerName,
    photo: household.photo,
    role: household.role,
  };
}

export async function parseJsonBody<T>(request: Request): Promise<T> {
  return (await request.json()) as T;
}

export { getCurrentHousehold };
