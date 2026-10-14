# Wi-Fi pull with staged apply and rollback

## Summary

Getting a profile onto its Kindle: the plugin gets a Studio menu where the owner names the Mac's host
and port, pulls the profile's settings bundle and the plugin build, verifies and stages them, and a
restart applies them with rollback (design §6 Push). This is what makes the studio the switch-over gate.

## Behavior

- The studio serves, for a profile, a bundle (settings file, fonts and icons if changed, the plugin
  build) with a manifest and hashes, on the LAN only.
- On the device, Tools → KoPanda → Studio: enter host and port once, see the profiles the studio
  offers, pick one; the plugin downloads, verifies every hash, stages into a holding folder, and arms
  an apply step for the next start.
- The next start applies the staged bundle, keeps the previous plugin and settings as a rollback set,
  and reports success on the home screen; a start that fails to draw the home restores the rollback
  set and says so.
- A bundle whose manifest or hashes don't verify is refused and nothing is staged.
- Specs cover verification, staging, apply, rollback and refusal on the emulator.

## Notes

The theme studio's companion (`lua/themestudio.koplugin/apply.lua`, `sync.lua`) is the reference and
much of it ports; it was reviewed at full depth once and the port gets the same review. Whether the
plugin build is replaced wholesale or by file is specify-time.
