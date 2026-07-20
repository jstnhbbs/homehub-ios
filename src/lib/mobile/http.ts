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
  await requireMobileUser();
  const household = await getCurrentHousehold();
  if (!household) {
    throw mobileError("Household required", 404);
  }
  await ensureMemberProfiles(household.id);
  return household;
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
  return {
    id: household.id,
    name: household.name,
    timezone: household.timezone,
    calendarSyncIntervalMinutes: household.calendarSyncIntervalMinutes,
    weekStartsOn: household.weekStartsOn,
    inviteCode: household.inviteCode,
    guestInviteCode: household.guestInviteCode,
    snackOptions: household.snackOptions,
    role: household.role,
  };
}

export async function parseJsonBody<T>(request: Request): Promise<T> {
  return (await request.json()) as T;
}

export { getCurrentHousehold };
