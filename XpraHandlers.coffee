class XpraHandlers extends EventEmitter

  windows: {}
  focused: -1

  constructor: (@xpra) ->

  hello: ->

  ping: (args) ->
    @xpra.proto.Send.apply @xpra.proto, ['ping_echo', args[1], 0, 0, 0, 0]

  "new-window": (args) ->
    @_NewWindow args, false

  "new-override-redirect": (args) ->
    @_NewWindow args, true

  _NewWindow: (args, override) ->
    params =
      wid:        args[1]
      x:          args[2]
      y:          args[3]
      width:      args[4]
      height:     args[5]
      properties: args[6]
      override:   override
      xpra:       @xpra

    newWin = new XpraWindow params

    @windows[newWin.wid + ''] = newWin

    newWin.on 'close', =>
      delete @windows[newWin.wid]

    # newWin.Focus()

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
      options:          args[10]

    win = @windows[params.wid]
    return if not win?

    if typeof params.data is 'string'
      uint = new Uint8Array(params.data.length);
      for i in [0...params.data.length]
        uint[i] = params.data.charCodeAt(i);

      params.data  = uint;

    if params.options?['zlib'] > 0
      params.data = new Zlib.Inflate(params.data).decompress();

    # console.log params
    win.Draw params
    win.emit 'draw'

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
      win.emit
      break

  'lost-window': (args) ->
    wid = args[1]
    @windows[wid].Close()
    @windows[wid].emit 'close'

  #TODO
  'window-metadata': (args) ->
  'window-icon': (args) ->
  'raise-window': (args) ->
  cursor: (args) ->
  bell: (args) ->
  'desktop_size': (args) ->
  'disconnect': (args) ->
