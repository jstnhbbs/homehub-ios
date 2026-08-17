import { Save, Sun } from "lucide-react";
import { saveWeatherSettings } from "@/app/actions";
import { requireHousehold } from "@/lib/household";

export default async function WeatherSettingsPage() {
  const household = await requireHousehold();
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
          name="location"
          className="hub-input"
          defaultValue={household.weatherLocation}
          placeholder="Chicago, IL"
          required
        />
        <div className="grid grid-cols-2 gap-3 max-sm:grid-cols-1">
          <label className="text-xs font-bold">
            Latitude
            <input name="latitude" className="hub-input mt-1" defaultValue={household.weatherLatitude} required />
          </label>
          <label className="text-xs font-bold">
            Longitude
            <input name="longitude" className="hub-input mt-1" defaultValue={household.weatherLongitude} required />
          </label>
        </div>
        <button className="hub-button w-fit">
          <Save size={18} /> Save weather
        </button>
      </form>
    </div>
  );
}
