/* BeaconBridge.rexx - One-shot notification bridge: MagicBeacon (MorphOS) <-> Ringhio (AmigaOS 4)
 * $VER: BeaconBridge.rexx 0.1 (11.09.2026)
 *
 *  Usage:
 *    BeaconBridge.rexx "message" [TITLE "title"] [FROM "app.type"] [PRI n]
 *                                [IMG "path"] [SCREEN "name"] [CLOSEONDC] [LOGONLY]
 *
 *  Sends to RinghioServer (RINGHIO ARexx port) when running on AmigaOS 4.1+,
 *  or to MagicBeacon (SendBeacon shell command) when running on MorphOS 3.16+.
 */

options results
signal on error

APP         = 'BeaconBridge'
RINGHIO     = 'RINGHIO'
SENDAPP     = 'BEACONBRIDGE'
DEFAULT_PRI = 3

message   = ''
title     = ''
from      = ''
pri       = DEFAULT_PRI
img       = ''
imgv      = ''
screen    = ''
target    = ''
closeondc = 0
nosrv     = 0
logonly   = 0

/* ------------------------------------------------------------------ */
/*  Parse arguments                                                      */
/* ------------------------------------------------------------------ */
parse arg opts
opts = strip(opts)
if opts = '' | opts = '?' then do
  say APP || ': MagicBeacon <-> Ringhio notification bridge'
  say
  say 'Usage: BeaconBridge "message" [TITLE "title"] [FROM "app.type"] [PRI 0-10]'
  say '                       [IMG "path"] [SCREEN "name"] [CLOSEONDC] [LOGONLY]'
  say
  say 'Targets:'
  say '  RINGHIO      RinghioServer ARexx port   (AmigaOS 4.1+)'
  say '  MAGICBEACON  SendBeacon shell command   (MorphOS 3.16+)'
  say '               (default: whichever is detected on this system)'
  say
  say 'Priorities: 0-8 auto-dismiss, 9 beep+flash, 10 sticky'
  exit 0
end

tokens = opts
do while tokens ~= ''
  parse var tokens tok tokens

  /* KEY="value ..." */
  if pos('="', tok) > 0 then do
    parse var tok kw '="' v
    rest = tokens
    if right(tok, 1) = '"' then
      v = strip(substr(v, 1, length(v) - 1))
    else do
      v = strip(v)
      do forever
        if rest = '' then leave
        parse var rest t rest
        if right(t, 1) = '"' then do
          t = substr(t, 1, length(t) - 1)
          if v ~= '' then v = v ' ' t
          else v = t
          leave
        end
        if v ~= '' then v = v ' ' t
        else v = t
      end
      tokens = rest
    end
    ku = translate(kw)
    select
      when ku = 'TITLE'  then title  = v
      when ku = 'FROM'   then from   = v
      when ku = 'IMG'    then img    = v
      when ku = 'SCREEN' then screen = v
      otherwise nop
    end
    iterate
  end

  /* KEY=value */
  if pos('=', tok) > 0 then do
    parse var tok kw '=' v
    ku = translate(kw)
    select
      when ku = 'PRI'       then pri    = v
      when ku = 'IMGVALIGN' then imgv   = v
      when ku = 'TARGET'    then target = translate(v)
      otherwise nop
    end
    iterate
  end

  /* Bare flags / message words */
  ut = translate(tok)
  select
    when ut = 'CLOSEONDC' then closeondc = 1
    when ut = 'LOGONLY'   then logonly = 1
    when ut = 'NOSRV'     then nosrv = 1
    otherwise do
      if message = '' then message = tok
      else message = message ' ' tok
    end
  end
end

if message = '' then do
  say APP || ': no message given'
  exit 5
end

if prize(pri) < 0 then pri = DEFAULT_PRI
if prize(pri) > 10 then pri = 10

/* Detect target if not given */
if target = '' then do
  if show('PORTS', RINGHIO) then target = 'RINGHIO'
  else target = 'MAGICBEACON'
end

/* ------------------------------------------------------------------ */
/*  Forward to the chosen target                                        */
/* ------------------------------------------------------------------ */
rc = 7
select
  when target = 'RINGHIO' then do
    if ~show('PORTS', RINGHIO) then do
      say APP || ': RinghioServer is not running'
      exit 7
    end
    call register_ringhio
    rc = send_ringhio(message, title, pri, img, imgv, screen, closeondc, logonly)
  end
  when target = 'MAGICBEACON' then
    rc = send_magicbeacon(message, from, nosrv)
  otherwise do
    say APP || ': unknown target "' || target || '"'
  end
end
exit rc

/* ================================================================== */
/*  Helpers                                                             */
/* ================================================================== */

prize: procedure
  parse arg v
  if v = '' then return -1
  if dataType(v, 'N') then return v
  return -1

/* Register with RinghioServer (required before sending) */
register_ringhio: procedure expose APP RINGHIO SENDAPP
  if show('PORTS', RINGHIO) then do
    address value RINGHIO
    'REGISTERAPP APP=' || SENDAPP || ' BeaconBridge notification relay.'
    if left(RESULT, 2) ~= 'OK' & right(RESULT, 22) ~= 'APP ALREADY REGISTERED' then
      say APP || ': Ringhio registration: ' || RESULT
  end

/* Send via Ringhio ARexx port */
send_ringhio: procedure expose APP SENDAPP
  parse arg message, title, pri, img, imgv, screen, closeondc, logonly

  cmd = 'RINGHIO APP=' || SENDAPP || ' PRI=' || pri
  if title  ~= '' then cmd = cmd ' TITLE="' || title || '"'
  if img    ~= '' then cmd = cmd ' IMG="' || img || '"'
  if imgv   ~= '' then cmd = cmd ' IMGVALIGN=' || imgv
  if screen ~= '' then cmd = cmd ' SCREEN="' || screen || '"'
  if closeondc    then cmd = cmd ' CLOSEONDC'
  if logonly      then cmd = cmd ' LOGONLY'
  cmd = cmd ' ' message

  address value RINGHIO
  cmd

  if left(RESULT, 2) = 'OK' then return 0
  say APP || ': Ringhio: ' || RESULT
  return 7

/* Send via MagicBeacon (SendBeacon shell command) */
send_magicbeacon: procedure expose APP
  parse arg message, from, nosrv

  cmd = 'SendBeacon "' || message || '"'
  if from ~= '' then cmd = cmd ' FROM="' || from || '"'
  if nosrv     then cmd = cmd ' NORESULT'

  address command cmd
  if RC ~= 0 then say APP || ': SendBeacon returned ' || RC
  return RC

error:
  say APP || ': error at line ' || sigl || ' (' || condition('D') || ') ' || condition('E')
  exit 10