export type HouseholdRole = "owner" | "parent" | "guest";

export const householdRoles = ["owner", "parent", "guest"] as const;

export function canManageHousehold(role: HouseholdRole) {
  return role === "owner" || role === "parent";
}

export function isOwner(role: HouseholdRole) {
  return role === "owner";
}

export function isGuest(role: HouseholdRole) {
  return role === "guest";
}

export function roleLabel(role: HouseholdRole) {
  if (role === "owner") return "Owner";
  if (role === "parent") return "Parent";
  return "Guest";
}

export function assignableRoles(actorRole: HouseholdRole): HouseholdRole[] {
  if (actorRole === "owner") return ["owner", "parent", "guest"];
  if (actorRole === "parent") return ["parent", "guest"];
  return [];
}

export function evaluateMemberRoleChange(input: {
  actorRole: HouseholdRole;
  actorUserId: string;
  targetUserId: string;
  targetRole: HouseholdRole;
  nextRole: HouseholdRole;
  ownerCount: number;
}): { ok: true } | { ok: false; error: string } {
  if (!canManageHousehold(input.actorRole)) {
    return { ok: false, error: "You do not have permission to do that." };
  }
  if (input.actorUserId === input.targetUserId) {
    return { ok: false, error: "You cannot change your own role." };
  }
  if (input.targetRole === input.nextRole) {
    return { ok: true };
  }
  if (!assignableRoles(input.actorRole).includes(input.nextRole)) {
    return { ok: false, error: "You cannot assign that role." };
  }
  if (input.actorRole === "parent" && input.targetRole === "owner") {
    return { ok: false, error: "Only an owner can change another owner's role." };
  }
  if (
    input.targetRole === "owner" &&
    input.nextRole !== "owner" &&
    input.ownerCount <= 1
  ) {
    return { ok: false, error: "The household needs at least one owner." };
  }
  return { ok: true };
}
