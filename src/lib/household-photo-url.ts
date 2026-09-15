export function hasHouseholdPhoto(photo: string | null | undefined) {
  if (!photo) return false;
  return isManagedHouseholdPhoto(photo, "") || looksLikeLocalHouseholdPhoto(photo, "");
}

export function looksLikeLocalHouseholdPhoto(url: string, householdId: string) {
  try {
    const parsed = new URL(url);
    const prefix = householdId
      ? `/household-photos/${householdId}/`
      : "/household-photos/";
    return parsed.pathname.startsWith(prefix);
  } catch {
    return false;
  }
}

export function isManagedHouseholdPhoto(url: string, householdId: string) {
  try {
    const parsed = new URL(url);
    const prefix = householdId
      ? `/households/${householdId}/`
      : "/households/";
    return (
      parsed.protocol === "https:" &&
      parsed.hostname.endsWith(".public.blob.vercel-storage.com") &&
      parsed.pathname.startsWith(prefix)
    );
  } catch {
    return false;
  }
}
