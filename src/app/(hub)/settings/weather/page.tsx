import { Save, Sun } from "lucide-react";
import { saveWeatherSettings } from "@/app/actions";
import { requireHousehold } from "@/lib/household";
import { normalizeUsZipCode } from "@/lib/weather";

export default async function WeatherSettingsPage() {
  const household = await requireHousehold();
  const zipCode = normalizeUsZipCode(household.weatherLocation);
  return (
    <div className="mx-auto max-w-3xl pb-10">
      <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
        Forecast
      </p>
      <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
        Weather location
      </h1>
      <form action={saveWeatherSettings} className="hub-card mt-6 grid gap-4 p-6">
        <Sun className="text-[var(--sun)]" size={30} />
        <input
          name="zipCode"
          className="hub-input"
          defaultValue={zipCode}
          inputMode="numeric"
          pattern="[0-9]{5}"
          maxLength={5}
          placeholder="60601"
          required
        />
        <p className="text-sm font-semibold text-[var(--muted)]">
          Current forecast area: {household.weatherLocation}
        </p>
        <button className="hub-button w-fit">
          <Save size={18} /> Save weather
        </button>
      </form>
    </div>
  );
}
