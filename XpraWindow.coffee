class XpraWindow extends EventEmitter

  constructor: (params) ->

    accepted = [
      'wid'
      'width'
      'height'
      'x'
      'y'
      'offscreen'
      'properties'
      'xpra'
      'override'
    ]

    for key, val of params when key in accepted
      @[key] = val
 
    @offscreen = document.createElement('canvas')
    @offscreen.width = @width
    @offscreen.height = @height

  Draw: (params) ->
    ctx = @offscreen.getContext('2d')

    image = ctx.createImageData params.width, params.height

    image.data.set params.data

    ctx.putImageData image, params.x, params.y

    @emit 'draw', params

  Focus: ->
    @xpra.proto.Send.apply @xpra.proto, ["focus", @wid, []]
    @emit 'focus'

  ResizeMove: (model) ->
    console.log ["configure-window", model.wid, model.x, model.y, model.width, model.height, model.properties]
    @xpra.proto.Send.apply @xpra.proto, ["configure-window", model.wid, model.x, model.y, model.width, model.height, model.properties]
    
  Close: -> 
    @emit 'close'

  MouseDown: (params) ->
    @Focus()
    @xpra.proto.Send.apply @xpra.proto, ["button-action", @wid, params.button, true, [params.x, params.y], [], []]

  MouseUp: (params) ->
    @xpra.proto.Send.apply @xpra.proto, ["button-action", @wid, params.button, false, [params.x, params.y], [], []]

  MouseMove: (params) ->
    @xpra.proto.Send.apply @xpra.proto, ["pointer-position", @wid, [params.x, params.y], [], []]
