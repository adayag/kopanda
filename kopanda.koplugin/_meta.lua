-- No `name` key: the runtime name is the folder's (frontend/pluginloader.lua:210, :249), and a `name`
-- here is ignored with a warning (:256-259). The repo's copy says 0.0.0-dev; a release's bundle rewrites
-- the version line, and the device takes a version that isn't X.Y.Z as older than any release.
return {
    fullname = "KoPanda",
    description = "The owner's own interface for KOReader: a home screen over the file browser.",
    version = "0.0.0-dev",
}
