type WeatherResponse = {
  current?: {
    temperature_2m?: number;
    apparent_temperature?: number;
    precipitation?: number;
    weather_code?: number;
  };
  daily?: {
    temperature_2m_max?: number[];
    temperature_2m_min?: number[];
    precipitation_probability_max?: number[];
  };
};

type ZipLookupResponse = {
  places?: Array<{
    "place name"?: string;
    "state abbreviation"?: string;
    latitude?: string;
    longitude?: string;
  }>;
};

const WEATHER_LABELS = new Map<number, string>([
  [0, "Clear"],
  [1, "Mostly clear"],
  [2, "Partly cloudy"],
  [3, "Cloudy"],
  [45, "Fog"],
  [48, "Fog"],
  [51, "Drizzle"],
  [61, "Rain"],
  [63, "Rain"],
  [65, "Heavy rain"],
  [71, "Snow"],
  [73, "Snow"],
  [75, "Heavy snow"],
  [80, "Showers"],
  [95, "Storms"],
]);

export type HouseholdWeather = {
  location: string;
  temperature: number;
  feelsLike: number;
  high: number | null;
  low: number | null;
  precipitationChance: number | null;
  label: string;
};

export function normalizeUsZipCode(value: string) {
  const zip = value.trim().match(/\d{5}/)?.[0];
  return zip ?? "";
}

export async function resolveUsZipCode(zipCode: string) {
  const zip = normalizeUsZipCode(zipCode);
  if (!zip) return null;

  try {
    const response = await fetch(`https://api.zippopotam.us/us/${zip}`, {
      next: { revalidate: 60 * 60 * 24 * 7 },
    });
    if (!response.ok) return null;
    const data = (await response.json()) as ZipLookupResponse;
    const place = data.places?.[0];
    if (!place?.latitude || !place.longitude) return null;
    const cityState = [place["place name"], place["state abbreviation"]]
      .filter(Boolean)
      .join(", ");
    return {
      zipCode: zip,
      location: cityState ? `${cityState} ${zip}` : zip,
      latitude: place.latitude,
      longitude: place.longitude,
    };
  } catch {
    return null;
  }
}

export async function fetchHouseholdWeather({
  location,
  latitude,
  longitude,
}: {
  location: string;
  latitude: string;
  longitude: string;
}): Promise<HouseholdWeather | null> {
  const resolved =
    latitude && longitude
      ? null
      : await resolveUsZipCode(location);
  const lat = Number(resolved?.latitude ?? latitude);
  const lon = Number(resolved?.longitude ?? longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;

  const params = new URLSearchParams({
    latitude: String(lat),
    longitude: String(lon),
    current:
      "temperature_2m,apparent_temperature,precipitation,weather_code",
    daily:
      "temperature_2m_max,temperature_2m_min,precipitation_probability_max",
    temperature_unit: "fahrenheit",
    timezone: "auto",
    forecast_days: "1",
  });

  try {
    const response = await fetch(
      `https://api.open-meteo.com/v1/forecast?${params.toString()}`,
      { next: { revalidate: 900 } },
    );
    if (!response.ok) return null;
    const data = (await response.json()) as WeatherResponse;
    const temperature = data.current?.temperature_2m;
    const feelsLike = data.current?.apparent_temperature;
    if (temperature == null || feelsLike == null) return null;

    return {
      location: resolved?.location ?? location,
      temperature: Math.round(temperature),
      feelsLike: Math.round(feelsLike),
      high:
        data.daily?.temperature_2m_max?.[0] == null
          ? null
          : Math.round(data.daily.temperature_2m_max[0]),
      low:
        data.daily?.temperature_2m_min?.[0] == null
          ? null
          : Math.round(data.daily.temperature_2m_min[0]),
      precipitationChance:
        data.daily?.precipitation_probability_max?.[0] ?? null,
      label: WEATHER_LABELS.get(data.current?.weather_code ?? -1) ?? "Weather",
    };
  } catch {
    return null;
  }
}
