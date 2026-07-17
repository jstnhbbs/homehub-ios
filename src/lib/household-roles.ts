export type HouseholdRole = "owner" | "parent" | "guest";

export function canManageHousehold(role: HouseholdRole) {
  return role === "owner" || role === "parent";
}

export function isGuest(role: HouseholdRole) {
  return role === "guest";
}

export function roleLabel(role: HouseholdRole) {
  if (role === "owner") return "Owner";
  if (role === "parent") return "Parent";
  return "Guest";
}
