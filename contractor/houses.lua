-- =============================================================================
-- houses.lua  --  The 11 construction contract houses, by contract ID.
--
-- The contract ID is CON_CONTRACTS_CURRENT_ID (0 = no contract). Only IDs 6 and 7
-- have been confirmed in game; the rest follow the order of the spot variables.
-- The plugin also works out the house from the spot names (prefix), so a wrong
-- ID here only prints a warning.
--
--   name, town  -- as on the contract scroll
--   directions  -- the scroll's directions (from the wiki)
--   prefix      -- spot variables start with CON_CONTRACTS_<prefix>_
--   bed         -- what a plain "BED" spot is in this house (large or small)
--   overrides   -- spot types that mean something different in this house
--   minX..maxZ  -- a box around the building in world tiles (every wiki spot + 1)
-- =============================================================================

return {
    [1] = {
        name = "Bob", town = "Lumbridge", prefix = "LUMBRIDGE_BOB",
        directions = "Can be found west of the Lumbridge graveyard.",
        bed = "Bed (large)",
        minX = 3226, maxX = 3234, minZ = 3200, maxZ = 3206,
    },
    [2] = {
        name = "Victoria", town = "Lumbridge", prefix = "LUMBRIDGE_VICTORIA",
        directions = "Can be found south of the Lumbridge lodestone.",
        bed = "Bed (large)",
        minX = 3228, maxX = 3235, minZ = 3205, maxZ = 3210,
    },
    [3] = {
        name = "Father Aereck", town = "Lumbridge", prefix = "LUMBRIDGE_AERECK",
        directions = "Can be found outside the Lumbridge courtyard.",
        minX = 3241, maxX = 3250, minZ = 3203, maxZ = 3216,
    },
    [4] = {
        name = "The shopkeeper", town = "Lumbridge", prefix = "LUMBRIDGE_SHOPKEEPER",
        directions = "Can be found north of the castle.",
        -- The wiki has 2 counters and no tables downstairs here
        overrides = { DOWNSTAIRS_TABLE = "Counter" },
        minX = 3210, maxX = 3220, minZ = 3238, maxZ = 3244,
    },
    [5] = {
        name = "Charos", town = "Varrock", prefix = "VARROCK_CHAROS",
        directions = "Can be found south of the Varrock estate agent.",
        -- Here the names are the other way round from everywhere else
        overrides = { DOWNSTAIRS_SHELVES = "Shelf", DOWNSTAIRS_LARGE_SHELF = "Shelves" },
        minX = 3235, maxX = 3244, minZ = 3445, maxZ = 3455,
    },
    [6] = {
        name = "The shopkeeper", town = "Varrock", prefix = "VARROCK_SHOPKEEPER",
        directions = "Can be found southeast of the main square.",
        bed = "Bed (small)",
        minX = 3213, maxX = 3221, minZ = 3409, maxZ = 3420,
    },
    [7] = {
        name = "The bartender", town = "Varrock", prefix = "VARROCK_BLUE_MOON_INN",
        directions = "Can be found on the road leading north from the Varrock lodestone.",
        minX = 3217, maxX = 3233, minZ = 3392, maxZ = 3404,
    },
    [8] = {
        name = "Ned", town = "Draynor", prefix = "DRAYNOR_NED",
        directions = "Can be found northeast of the bank.",
        bed = "Bed (large)",
        minX = 3095, maxX = 3103, minZ = 3253, maxZ = 3261,
    },
    [9] = {
        name = "Aggie", town = "Draynor", prefix = "DRAYNOR_AGGIE",
        directions = "Can be found to the west of the town centre.",
        bed = "Bed (large)",
        minX = 3080, maxX = 3089, minZ = 3256, maxZ = 3263,
    },
    [10] = {
        name = "The wise old man", town = "Draynor", prefix = "DRAYNOR_WOM",
        directions = "Can be found north of the bank.",
        minX = 3085, maxX = 3095, minZ = 3250, maxZ = 3256,
    },
    [11] = {
        name = "The shopkeeper", town = "Edgeville", prefix = "EDGEVILLE_SHOPKEEPER",
        directions = "Can be found north-west of the bank.",
        minX = 3075, maxX = 3085, minZ = 3506, maxZ = 3514,
    },
}
