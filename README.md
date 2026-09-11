# BeaconBridge.rexx

ARexx notification bridge between MagicBeacon (MorphOS) and Ringhio (AmigaOS 4.1+).

## Requirements

- ARexx (RexxMast)
- rexxsupport.library
- RinghioServer (AmigaOS 4.1+) or SendBeacon (MorphOS 3.16+)

## Usage

```
BeaconBridge.rexx "message" [TITLE "title"] [FROM "app.type"] [PRI n]
                [IMG "path"] [SCREEN "name"] [CLOSEONDC] [LOGONLY] [NOSRV]
BeaconBridge.rexx LISTEN [TARGET RINGHIO|MAGICBEACON]
BeaconBridge.rexx POLL <file> [INTERVAL n] [TARGET RINGHIO|MAGICBEACON]
BeaconBridge.rexx ?
```

## Modes

- **One-shot**: forward a single notification directly
- **Server**: open an ARexx port (`BEACONBRIDGE`) and accept commands
- **Polling**: watch a file for line changes and notify

## Server commands

`ADDRESS BEACONBRIDGE` to send:

- `SEND <message> [TITLE=...] [PRI=...] [IMG=...] [CLOSEONDC] [LOGONLY]`
- `SHOW` -- print status
- `QUIT` -- shut down

## Cross-machine bridging

Use [NetFS](https://morph.zone/modules/news/article_storyid_2498.html) ARexx port sharing or a socket tunnel to bridge across a network.

## Priorities

- 0-8 -- auto-dismiss
- 9 -- beep + flash screen
- 10 -- sticky (stay until user closes)

## References

- [RinghioServer ARexx Interface](https://wiki.amigaos.net/wiki/AmigaOS_Manual:_System_Tools#RinghioServer)
- [MagicBeacon](http://geit.de/eng_magicbeacon.html)
- [Ranchero](https://robthenerd.com/projects/ranchero) -- Ringhio-compatible notification for AmigaOS 3
