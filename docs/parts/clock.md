# SylClock

`sylvaris clock` opens the clock: a live sky, the weather and a calendar.

The sky card plots today from midnight to midnight. The sun and the moon sit at their real altitude for your location right now; their paths so far are solid and the rest of the day is dashed, and anything below the line is under the horizon. The sky colour follows the sun through night, twilight, golden hour and day, and stars come out as it gets dark. The moon is drawn in its current phase, mirrored in the southern hemisphere.

## Weather

Below the sky sits the weather from [Open-Meteo](https://open-meteo.com): now, the next hours as a temperature curve with the chance of rain, and six days ahead.

| Key | Default | Meaning |
|---|---|---|
| `weather.enabled` | `true` | show the weather |
| `weather.units` | `metric` | `metric` or `imperial` |
| `weather.refresh` | `30` | minutes between updates |

This is the only part that talks to the internet on its own, and it only sends your coordinates, rounded to two decimals (about 1 km).

## Location

Your location comes from `location` in `config.json`. Without it, Sylvaris uses the coordinates of your system time zone from `zone1970.tab`, which is close enough to get sunrise and sunset right within minutes.

```nix
programs.sylvaris.settings.location = { latitude = 52.23; longitude = 21.01; };
```

## Calendar

Click a day to see its plans and add to them when the [Diver plugin](../plugins/diver.md) is on. `sylvaris clock day <yyyy-mm-dd|today>` opens the clock on a day. `clock.corner` sets where the clock opens, per screen if you like.
