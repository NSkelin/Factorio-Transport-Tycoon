data:extend({
        {
            type = "int-setting",
            name = "minimum-city-distance",
            setting_type = "runtime-global",
            default_value = 100,
            order = "a",
        },
        {
            type = "int-setting",
            name = "probability-of-city-placement",
            setting_type = "runtime-global",
            default_value = 50,
            order = "b",
        },
        {
            type = "bool-setting",
            name = "start-with-trains",
            setting_type = "runtime-global",
            default_value = false,
            order = "c",
        },
        {
            type = "bool-setting",
            name = "map-tags",
            setting_type = "runtime-global",
            default_value = true,
            order = "d",
        },
        {
            type = "int-setting",
            name = "base-item-values-seed",
            setting_type = "startup",
            default_value = 1,
            order = "a",
        },
        {
            type = "int-setting",
            name = "max-trades-per-page",
            default_value = 100,
            maximum_value = 1000,
            minimum_value = 20,
            setting_type = "runtime-per-user",
        }
})