# BeaconBridge.rexx

ARexx notification bridge between MagicBeacon (MorphOS) and Ringhio (AmigaOS 4.1+).

## Requirements

- ARexx (RexxMast)
- RinghioServer (AmigaOS 4.1+) or SendBeacon (MorphOS 3.16+)

## Usage

```
BeaconBridge.rexx "message" [TITLE "title"] [FROM "app.type"] [PRI n]
                    [IMG "path"] [SCREEN "name"] [CLOSEONDC] [LOGONLY]
BeaconBridge.rexx BRIDGE
BeaconBridge.rexx ?
```

`BRIDGE` runs the bridge as a daemon. Without a message the script prints help.

## Bridge mode

`BeaconBridge BRIDGE` always creates the ARexx port of the *other* beacon
system and relays what it receives:

- on AmigaOS 4 -- opens the `MAGICBEACON` port, relaying requests to
  RinghioServer
- on MorphOS -- opens the `RINGHIO` port, relaying requests to MagicBeacon
  (via `SendBeacon`)

So clients written for one platform work on the other without changes.
Run it on every boot (e.g. startup) and stop it by sending `EXIT` or `QUIT`
to the port.

## Example

```
BeaconBridge.rexx "Disk full" FROM=Sys.Error TITLE="Warning" PRI=9
```

## Targets

- **RINGHIO** -- RinghioServer ARexx port (AmigaOS 4.1+); the default when the
  `RINGHIO` port is present
- **MAGICBEACON** -- `SendBeacon` shell command (MorphOS 3.16+); used otherwise

On AmigaOS 4 the bridge auto-registers itself (`BEACONBRIDGE`) with
RinghioServer before sending.

## Priorities

- 0-8 -- auto-dismiss
- 9 -- beep + flash screen
- 10 -- sticky (stay until user closes)

## References

- [RinghioServer ARexx Interface](https://wiki.amigaos.net/wiki/AmigaOS_Manual:_System_Tools#RinghioServer)
- [MagicBeacon](http://geit.de/eng_magicbeacon.html)
- [Ranchero](https://robthenerd.com/projects/ranchero) -- Ringhio-compatible notification for AmigaOS 3