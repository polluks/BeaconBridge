/* $VER: BeaconBridge.rexx 0.1 (11.09.2026) MagicBeacon <-> Ringhio notification bridge */
/* BeaconBridge.rexx - Bridge between MagicBeacon (MorphOS) and Ringhio (AmigaOS 4)
 *
 *  Forwards notifications between the two systems via ARexx.
 *    Ringhio      -> RinghioServer ARexx port "RINGHIO"  (AmigaOS 4.1+)
 *    MagicBeacon  -> "SendBeacon" shell command  (MorphOS 3.16+, SendBeacon)
 *
 *  Usage:
 *    One-shot:  BeaconBridge.rexx "message" [TITLE "title"] [FROM "app.type"]
 *                                      [PRI n] [IMG "path"] [SCREEN "name"]
 *                                      [CLOSEONDC] [LOGONLY] [NOSRV]
 *    Server:    BeaconBridge.rexx LISTEN [TARGET RINGHIO|MAGICBEACON]
 *    Polling:   BeaconBridge.rexx POLL <file> [INTERVAL n] [TARGET ...]
 *
 *  Examples:
 *    BeaconBridge.rexx "Disk full" FROM=Sys.Error TITLE="Warning" PRI=9
 *    BeaconBridge.rexx LISTEN TARGET=MAGICBEACON      (Ringhio -> MagicBeacon)
 *    BeaconBridge.rexx LISTEN TARGET=RINGHIO           (MagicBeacon -> Ringhio)
 *
 *  Server mode opens an ARexx port named BEACONBRIDGE. Other scripts can
 *  talk to it with:  ADDRESS BEACONBRIDGE "SEND TITLE=... PRI=... text"
 *
 *  Cross-machine bridging works with NetFS ARexx-port sharing, or an ARexx
 *  socket tunnel. Ringhio-compatible notification for OS3: Ranchero.
 */

options results
signal on error

/* ------------------------------------------------------------------ */
/*  Configuration                                                       */
/* ------------------------------------------------------------------ */
APP         = 'BeaconBridge'
PORT        = 'BEACONBRIDGE'
RINGHIO     = 'RINGHIO'
SENDAPP     = 'BEACONBRIDGE'
DEFAULT_PRI = 3

/* ------------------------------------------------------------------ */
/*  Load rexxsupport.library (server-port functions)                    */
/* ------------------------------------------------------------------ */
if ~show('L', 'rexxsupport.library') then do
  if ~addlib('rexxsupport.library', 0, -30, 0) then do
    say APP || ': cannot open rexxsupport.library'
    exit 20
  end
end

/* ------------------------------------------------------------------ */
/*  Parse arguments                                                      */
/* ------------------------------------------------------------------ */
parse arg opts
opts = strip(opts)
if opts = '' | opts = '?' then do
  say APP || ': MagicBeacon <-> Ringhio notification bridge'
  say
  say 'One-shot:'
  say '  BeaconBridge "message" [TITLE "title"] [FROM "app.type"] [PRI 0-10]'
  say '                     [IMG "path"] [SCREEN "name"] [CLOSEONDC] [LOGONLY] [NOSRV]'
  say
  say 'Server:'
  say '  BeaconBridge LISTEN [TARGET RINGHIO|MAGICBEACON]'
  say '  BeaconBridge POLL <file> [INTERVAL n] [TARGET RINGHIO|MAGICBEACON]'
  say
  say 'Targets:'
  say '  RINGHIO      RinghioServer ARexx port   (AmigaOS 4.1+)'
  say '  MAGICBEACON  SendBeacon shell command   (MorphOS 3.16+)'
  say '               (default: whichever is detected on this system)'
  say
  say 'Priorities: 0-8 auto-dismiss, 9 beep+flash, 10 sticky'
  exit 0
end

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
listen    = 0
poll      = ''
interval  = 300
update    = 0
logonly   = 0

tokens = opts
do while tokens ~= ''
  parse var tokens tok tokens

  /* KEY="value ..." */
  if pos('="', tok) > 0 then do
    parse var tok kw '="' v
    rest = tokens
    if right(tok, 1) = '"' then do
      v = strip(substr(v, 1, length(v) - 1))
    end
    else do
      v = strip(v)
      do forever
        if rest = '' then leave
        parse var rest t rest
        if right(t, 1) = '"' then do
          t = substr(t, 1, length(t) - 1)
          if v = '' then v = t
          else v = v ' ' t
          leave
        end
        if v = '' then v = t
        else v = v ' ' t
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
      when ku = 'PRI'       then pri      = strip(v)
      when ku = 'IMGVALIGN' then imgv     = strip(v)
      when ku = 'TARGET'    then target   = translate(strip(v))
      when ku = 'POLL'      then poll     = strip(v)
      when ku = 'INTERVAL'  then interval = strip(v)
      otherwise nop
    end
    iterate
  end

  /* Bare flags / message words */
  ut = translate(tok)
  select
    when ut = 'NOSRV' | ut = 'QUICK' | ut = 'NORESULT' then nosrv = 1
    when ut = 'LISTEN'    then listen  = 1
    when ut = 'UPDATE'    then update  = 1
    when ut = 'LOGONLY'   then logonly = 1
    when ut = 'CLOSEONDC' then closeondc = 1
    otherwise do
      if message = '' then message = tok
      else message = message ' ' tok
    end
  end
end

/* ------------------------------------------------------------------ */
/*  Detect target if not given                                          */
/* ------------------------------------------------------------------ */
if target = '' then do
  if show('PORTS', RINGHIO) then target = 'RINGHIO'
  else target = 'MAGICBEACON'
end

if prize(pri) < 0 then pri = DEFAULT_PRI

/* ------------------------------------------------------------------ */
/*  One-shot mode                                                        */
/* ------------------------------------------------------------------ */
if ~listen & poll = '' then do
  if message = '' then do
    say APP || ': no message given'
    exit 5
  end
  rc = forward(message, title, from, pri, img, imgv, screen, closeondc, target, nosrv, update, logonly)
  exit rc
end

/* ------------------------------------------------------------------ */
/*  Server / polling mode                                                */
/* ------------------------------------------------------------------ */
if poll = '' then do
  if ~show('PORTS', PORT) then do
    if ~openport(PORT) then do
      say APP || ': cannot open ARexx port ' || PORT
      exit 20
    end
  end
end

if target = 'RINGHIO' then call register_ringhio PORT

if poll = '' then say APP || ': listening on port ' || PORT || ', target=' || target
else say APP || ': polling ' || poll || ', interval=' || interval || ', target=' || target

/* ------------------------------------------------------------------ */
/*  Main loop                                                            */
/* ------------------------------------------------------------------ */
do forever
  signal on error

  if poll ~= '' then do
    call check_poll
    call delayer interval
  end
  else do
    call waitpkt PORT
    pkt = getpkt(PORT)
    if pkt = '00000000'x then iterate

    c = getarg(pkt)
    call reply pkt, 0

    parse var c command rest
    command = translate(command)

    select
      when command = 'SEND' | command = 'FORWARD' then do
        rc = parse_and_forward(rest)
        say APP || ': forwarded (rc=' || rc || ')'
      end
      when command = 'SHOW' then
        say APP || ': server on ' || PORT || ', target=' || target || ', time=' || time('N')
      when command = 'QUIT' | command = 'EXIT' then do
        say APP || ': shutting down'
        exit 0
      end
      when command = 'HELP' then
        say APP || ': commands: SEND <msg> [TITLE=] [FROM=] [PRI=] [IMG=] [SCREEN=] [CLOSEONDC] [LOGONLY] [UPDATE], SHOW, QUIT'
      otherwise
        say APP || ': unknown command "' || command || '"'
    end
  end
end

exit 0

/* ================================================================== */
/*  Helpers                                                             */
/* ================================================================== */

/* Returns a numeric priority, or -1 if argument is not numeric. */
prize: procedure
  parse arg v
  if v = '' then return -1
  if dataType(v, 'N') then return v
  return -1

/* ------------------------------------------------------------------ */
/*  Register with RinghioServer                                         */
/* ------------------------------------------------------------------ */
register_ringhio: procedure expose APP RINGHIO SENDAPP
  parse arg portname
  if ~show('PORTS', RINGHIO) then do
    say APP || ': RinghioServer not running - skipping registration'
    return 0
  end
  address value RINGHIO
  'REGISTERAPP APP=' || SENDAPP || ' AREXXPORT=' || portname || ' BeaconBridge notification relay.'
  if left(RESULT, 2) = 'OK' then do
    say APP || ': registered with RinghioServer'
    return 1
  end
  say APP || ': Ringhio registration failed: ' || RESULT
  return 0

/* ------------------------------------------------------------------ */
/*  Forward a notification to the target system                          */
/* ------------------------------------------------------------------ */
forward: procedure expose APP SENDAPP
  parse arg message, title, from, pri, img, imgv, screen, closeondc, target, nosrv, update, logonly

  if prize(pri) < 0 then pri = DEFAULT_PRI
  if prize(pri) > 10 then pri = 10
  if prize(pri) < 0  then pri = 0

  select
    when target = 'RINGHIO' then do
      if ~show('PORTS', RINGHIO) then do
        say APP || ': RinghioServer is not running'
        return 7
      end
      return send_ringhio(message, title, pri, img, imgv, screen, closeondc, update, logonly)
    end

    when target = 'MAGICBEACON' then
      return send_magicbeacon(message, from, nosrv)

    otherwise do
      say APP || ': unknown target "' || target || '"'
      return 7
    end
  end

/* ------------------------------------------------------------------ */
/*  Send via Ringhio ARexx port                                         */
/* ------------------------------------------------------------------ */
send_ringhio: procedure expose APP SENDAPP
  parse arg message, title, pri, img, imgv, screen, closeondc, update, logonly

  cmd = 'RINGHIO APP=' || SENDAPP || ' PRI=' || pri
  if title  ~= '' then cmd = cmd ' TITLE="' || title || '"'
  if img    ~= '' then cmd = cmd ' IMG="' || img || '"'
  if imgv   ~= '' then cmd = cmd ' IMGVALIGN=' || imgv
  if screen ~= '' then cmd = cmd ' SCREEN="' || screen || '"'
  if closeondc    then cmd = cmd ' CLOSEONDC'
  if update       then cmd = cmd ' UPDATE'
  if logonly      then cmd = cmd ' LOGONLY'
  cmd = cmd ' ' message

  address value RINGHIO
  cmd

  if left(RESULT, 2) = 'OK' then return 0
  say APP || ': Ringhio: ' || RESULT
  return 7

/* ------------------------------------------------------------------ */
/*  Send via MagicBeacon ("SendBeacon" shell command)                    */
/* ------------------------------------------------------------------ */
send_magicbeacon: procedure expose APP
  parse arg message, from, nosrv

  cmd = 'SendBeacon "' || message || '"'
  if from ~= '' then cmd = cmd ' FROM="' || from || '"'
  if nosrv     then cmd = cmd ' NORESULT'

  address command cmd
  if RC ~= 0 then say APP || ': SendBeacon returned ' || RC
  return RC

/* ------------------------------------------------------------------ */
/*  Parse an incoming "SEND ..." command line and forward it             */
/* ------------------------------------------------------------------ */
parse_and_forward: procedure expose APP SENDAPP target DEFAULT_PRI
  parse arg rest

  p_title  = ''
  p_from   = ''
  p_pri    = DEFAULT_PRI
  p_img    = ''
  p_imgv   = ''
  p_screen = ''
  p_msg    = ''
  p_close  = 0
  p_upd    = 0
  p_log    = 0

  tokens = strip(rest)
  do while tokens ~= ''
    parse var tokens tok tokens

    /* KEY="value ..." */
    if pos('="', tok) > 0 then do
      parse var tok kw '="' v
      r = tokens
      if right(tok, 1) = '"' then do
        v = strip(substr(v, 1, length(v) - 1))
      end
      else do
        v = strip(v)
        do forever
          if r = '' then leave
          parse var r t r
          if right(t, 1) = '"' then do
            t = substr(t, 1, length(t) - 1)
            if v = '' then v = t
            else v = v ' ' t
            leave
          end
          if v = '' then v = t
          else v = v ' ' t
        end
        tokens = r
      end
      ku = translate(kw)
      select
        when ku = 'TITLE'  then p_title  = v
        when ku = 'FROM'   then p_from   = v
        when ku = 'IMG'    then p_img    = v
        when ku = 'SCREEN' then p_screen = v
        otherwise nop
      end
      iterate
    end

    /* KEY=value */
    if pos('=', tok) > 0 then do
      parse var tok kw '=' v
      ku = translate(kw)
      select
        when ku = 'PRI'       then p_pri  = strip(v)
        when ku = 'IMGVALIGN' then p_imgv = strip(v)
        otherwise nop
      end
      iterate
    end

    /* Flags / message words */
    ut = translate(tok)
    select
      when ut = 'CLOSEONDC' then p_close = 1
      when ut = 'UPDATE'    then p_upd   = 1
      when ut = 'LOGONLY'   then p_log   = 1
      otherwise do
        if p_msg = '' then p_msg = tok
        else p_msg = p_msg ' ' tok
      end
    end
  end

  return forward(p_msg, p_title, p_from, p_pri, p_img, p_imgv, p_screen, p_close, target, 0, p_upd, p_log)

/* ------------------------------------------------------------------ */
/*  File-change poll helper (counts lines)                               */
/* ------------------------------------------------------------------ */
check_poll: procedure expose APP SENDAPP poll interval target DEFAULT_PRI lastsize
  if poll = '' then return

  size = 0
  if exists(poll) then do
    if open(h, poll, 'R') then do
      do while ~eof(h)
        call readln h
        size = size + 1
      end
      call close h
    end
  end

  if size ~= lastsize then do
    delta = size - lastsize
    lastsize = size
    say APP || ': file changed: ' || poll || ' (+' || delta || ' lines)'
    rc = forward('File changed: ' || poll || ' (' || delta || ' lines)',
                 '', 'BeaconBridge.FilePoll', DEFAULT_PRI, '', '', '', 0, target, 0, 0, 0)
  end

/* ------------------------------------------------------------------ */
/*  Delay in seconds (Shell "Wait" builtin; 1 tick = 1/50 s)             */
/* ------------------------------------------------------------------ */
delayer: procedure
  parse arg seconds
  if dataType(seconds, 'N') = 0 | seconds < 1 then seconds = 1
  ticks = trunc(seconds * 50)
  address command 'Wait' ticks

/* ------------------------------------------------------------------ */
/*  Error handler                                                        */
/* ------------------------------------------------------------------ */
error:
  say APP || ': error at line ' || sigl || ' (' || condition('D') || ') ' || condition('E')
  exit 10
