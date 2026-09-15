import { hasHouseholdPhoto } from "@/lib/household-photo-url";

function householdInitial(name: string) {
  const ignored = new Set([
    "the",
    "family",
    "household",
    "house",
    "home",
    "fam",
  ]);
  const parts = name
    .split(/[\s/]+/)
    .filter((part) => part && !ignored.has(part.toLowerCase()));
  const last = parts.at(-1);
  return (last?.[0] ?? name[0] ?? "H").toUpperCase();
}

export function HouseholdMark({
  name,
  photo,
  size = 56,
  className = "",
}: {
  name: string;
  photo?: string | null;
  size?: number;
  className?: string;
}) {
  const showPhoto = hasHouseholdPhoto(photo);
  return (
    <span
      className={`relative flex shrink-0 items-center justify-center overflow-hidden rounded-[32%] bg-[var(--sage)] font-extrabold text-white ${className}`}
      style={{ width: size, height: size, fontSize: size * 0.5 }}
      aria-label={`${name} household photo`}
    >
      {showPhoto && photo ? (
        // Local and blob household photos both live at public URLs.
        // eslint-disable-next-line @next/next/no-img-element
        <img src={photo} alt="" className="h-full w-full object-cover" />
      ) : (
        householdInitial(name)
      )}
    </span>
  );
}
