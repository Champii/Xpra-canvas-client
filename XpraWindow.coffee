class XpraWindow extends EventEmitter

  constructor: (params) ->
    for key, val of params
      @[key] = val if not @[key]?

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
    console.log 'FOCUS', @
    @xpra.proto.Send.apply @xpra.proto, ["focus", @wid, []]
    @emit 'focus'
