import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { getCurrentHousehold } from "@/lib/household";
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

export function handleMobileError(error: unknown) {
  if (error instanceof Response) return error;
  if (error instanceof NextResponse) return error;
  const message = error instanceof Error ? error.message : "Request failed.";
  const status = message === "Unauthorized" ? 401 : 400;
  return mobileError(message, status);
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
