-- Migration steps for the settings file, by the schema version they produce: [n] takes the
-- data table of a version n - 1 file and returns it as version n. settings.lua runs them in
-- order on open and stamps the result. Version 1 has none.
return {}
