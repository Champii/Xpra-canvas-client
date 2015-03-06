class XpraHandlers extends EventEmitter

  windows: {}

  constructor: (@xpra) ->

  hello: ->

  ping: (args) ->
    @xpra.proto.Send.apply @xpra.proto, ['ping_echo', args[1], 0, 0, 0, 0]

  "new-window": (args) ->
    params =
      wid:        args[1]
      x:          args[2]
      y:          args[3]
      width:      args[4]
      height:     args[5]
      properties: args[6]
      xpra:       @xpra

    # console.log 'new win', @xpra.XpraWindow
    newWin = new XpraWindow params

    @windows[newWin.wid + ''] = newWin

    newWin.on 'focus', =>
      @xpra.keyboard.topwindow = newWin.wid

    newWin.on 'close', =>
      delete @windows[newWin.wid]

    @xpra.emit 'new-window', newWin

    args[0] = 'map-window'
    args[6] = args[7]
    args[6]["encodings.rgb_formats"] = ["RGBX", "RGBA"]

    args.splice 7, 1

    @xpra.proto.Send.apply @xpra.proto, args

  draw: (args) ->
    now = new Date().getTime()
    params =
      wid:              args[1]
      x:                args[2]
      y:                args[3]
      width:            args[4]
      height:           args[5]
      coding:           args[6]
      data:             args[7]
      paquet_sequence:  args[8]
      rowstride:        args[9]

    win = @windows[params.wid]

    if typeof params.data is 'string'
      uint = new Uint8Array(params.data.length);
      for i in [0...params.data.length]
        uint[i] = params.data .charCodeAt(i);

      params.data  = uint;

    params.data = new Zlib.Inflate(params.data).decompress();

    # console.log params
    win.Draw params

    toSend = []
    toSend.push 'damage-sequence'
    toSend.push args[8]
    toSend.push args[1]
    toSend.push args[4]
    toSend.push args[5]

    # fixme: get the decode time
    toSend.push (new Date().getTime()) - now

    @xpra.proto.Send.apply @xpra.proto, toSend

  'startup-complete': (args) ->
    # console.log 'STARTUP COMPLETE', @windows
    for wid, win of @windows
      win.Focus()
      break

  'lost-window': (args) ->
    wid = args[1]
    @windows[wid].Close()

  #TODO
  'window-metadata': (args) ->
  'window-icon': (args) ->
  'raise-window': (args) ->
  cursor: (args) ->
  bell: (args) ->
  'desktop_size': (args) ->
  'disconnect': (args) ->
