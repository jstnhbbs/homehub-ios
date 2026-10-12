import { PROFILE_COLOR_CHOICES, PROFILE_COLORS } from "@/lib/profile-colors";

export function ProfileColorPicker({
  defaultColor = PROFILE_COLORS[0].value,
}: {
  defaultColor?: string;
}) {
  return (
    <fieldset>
      <legend className="mb-2 text-xs font-bold">Profile color</legend>
      <div className="flex flex-wrap gap-2.5">
        {PROFILE_COLOR_CHOICES.map((color) => (
          <label
            key={color.value}
            className="cursor-pointer"
            title={color.label}
          >
            <input
              type="radio"
              name="color"
              value={color.value}
              defaultChecked={color.value === defaultColor}
              className="peer sr-only"
            />
            <span
              className="flex h-10 w-10 items-center justify-center rounded-full border-2 border-white ring-1 ring-[var(--line)] transition peer-checked:ring-4 peer-checked:ring-[var(--foreground)]/30"
              style={{ background: color.value }}
            >
              <span className="sr-only">{color.label}</span>
            </span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}
