-- The shared geocoding corpus: queries with the URL the place search requests for each, and the
-- recorded Open-Meteo responses under spec/fixtures/geocoding/ with the candidates read from each.
-- spec/unit/studio_geocoding_spec.lua asserts the plugin's LocationSearch gives them and
-- studio/test/server/geocoding.test.ts asserts the studio server's functions do, reading this file
-- with the studio's own reader, so it stays in that reader's subset: literals only.
return {
    urls = {
        {
            query = "  Chicago ",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=Chicago&count=10&language=en&format=json",
        },
        {
            query = "New York",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=New%20York&count=10&language=en&format=json",
        },
        {
            query = "60614",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=60614&count=10&language=en&format=json&countryCode=US",
        },
        {
            query = "\t60614\n",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=60614&count=10&language=en&format=json&countryCode=US",
        },
        {
            query = "606140",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=606140&count=10&language=en&format=json",
        },
        {
            query = "6061A",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=6061A&count=10&language=en&format=json",
        },
        {
            query = "São Paulo",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=S%C3%A3o%20Paulo&count=10&language=en&format=json",
        },
        {
            query = "a&b=c",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=a%26b%3Dc&count=10&language=en&format=json",
        },
        {
            query = "St. John's (NL)!",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=St.%20John%27s%20%28NL%29%21&count=10&language=en&format=json",
        },
        -- A no-break space is not Lua's %s, so trimming keeps it.
        {
            query = "\194\160Chicago",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=%C2%A0Chicago&count=10&language=en&format=json",
        },
        -- A newline inside the query is encoded as CR LF.
        {
            query = "a\nb",
            url = "https://geocoding-api.open-meteo.com/v1/search?name=a%0D%0Ab&count=10&language=en&format=json",
        },
    },
    parses = {
        {
            fixture = "chicago.json",
            candidates = {
                { name = "Chicago, Illinois", latitude = 41.85003, longitude = -87.65005,
                  shown = "Chicago, Illinois, United States" },
                { name = "Willard, Ohio", latitude = 41.05311, longitude = -82.72629,
                  shown = "Willard, Ohio, United States" },
                { name = "Craigmont, Idaho", latitude = 46.24128, longitude = -116.46709,
                  shown = "Craigmont, Idaho, United States" },
                { name = "Saint Francis, Kentucky", latitude = 37.62645, longitude = -85.42774,
                  shown = "Saint Francis, Kentucky, United States" },
                { name = "Chicago, Jalisco", latitude = 22.33944, longitude = -104.15972,
                  shown = "Chicago, Jalisco, Mexico" },
                { name = "Chicago, Niassa Province", latitude = -12.81722, longitude = 34.78583,
                  shown = "Chicago, Niassa Province, Mozambique" },
                { name = "Chicago, Mimaropa", latitude = 13.396, longitude = 121.0984,
                  shown = "Chicago, Mimaropa, Philippines" },
                { name = "Chicago, Tabasco", latitude = 17.4, longitude = -93.46667,
                  shown = "Chicago, Tabasco, Mexico" },
                { name = "Chicago, Oaxaca", latitude = 16.33333, longitude = -94.31667,
                  shown = "Chicago, Oaxaca, Mexico" },
                { name = "Chicago, Belize District", latitude = 17.81524, longitude = -88.31159,
                  shown = "Chicago, Belize District, Belize" },
            },
        },
        {
            fixture = "zip-60614.json",
            candidates = {
                { name = "Chicago, Illinois", latitude = 41.85003, longitude = -87.65005,
                  shown = "Chicago, Illinois, United States" },
            },
        },
        {
            fixture = "none.json",
            candidates = {},
        },
        -- Hand-written from live responses read on 2026-10-16 (Singapore, Tokyo, Hong Kong): a
        -- result without a name and one with a string latitude are skipped; Tokyo's admin1 is its
        -- name, so the country names it; Hong Kong has no admin1 or country; Singapore's country is
        -- already its last part, so shown doesn't repeat it.
        {
            fixture = "edge.json",
            candidates = {
                { name = "Tokyo, Japan", latitude = 35.6895, longitude = 139.69171, shown = "Tokyo, Japan" },
                { name = "Hong Kong", latitude = 22.27832, longitude = 114.17469, shown = "Hong Kong" },
                { name = "Singapore, Singapore", latitude = 1.28967, longitude = 103.85007,
                  shown = "Singapore, Singapore" },
            },
        },
    },
}
