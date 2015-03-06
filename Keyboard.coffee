class Keyboard

  constructor: (@xpra) ->
    @caps_lock = false
    @topwindow = 2

    document.onkeydown = (args...) =>
      @onkeydown args...
    document.onkeyup = (args...) =>
      @onkeyup args...
    document.onkeypress = (args...) =>
      @onkeypress args...

  ###*
  # Returns the modifiers set for the current event.
  # We get the list of modifiers using "get_event_modifiers"
  # then translate "alt" and "meta" into their keymap name.
  # (usually "mod1")
  ###

  get_modifiers: (event) ->
    #convert generic modifiers "meta" and "alt" into their x11 name:
    modifiers = get_event_modifiers(event)
    #FIXME: look them up!
    alt = 'mod1'
    meta = 'mod1'
    index = modifiers.indexOf('alt')
    if index >= 0
      modifiers[index] = alt
    index = modifiers.indexOf('meta')
    if index >= 0
      modifiers[index] = meta
    #show("get_modifiers() modifiers="+modifiers.toSource());
    modifiers

  ###*
  # Process a key event: key pressed or key released.
  # Figure out the keycode, keyname, modifiers, etc
  # And send the event to the server.
  ###

  processKeyEvent: (pressed, event) ->
    # console.log pressed, event
    # MSIE hack
    if window.event
      event = window.event
    #show("@processKeyEvent("+pressed+", "+event+") keyCode="+event.keyCode+", charCode="+event.charCode+", which="+event.which);
    keyname = ''
    keycode = 0
    if event.which
      keycode = event.which
    else
      keycode = event.keyCode
    # console.log 'keycode', keycode
    if CHARCODE_TO_NAME[keycode]?
      keyname = CHARCODE_TO_NAME[keycode]
    DOM_KEY_LOCATION_RIGHT = 2
    if keyname.match('_L$') and event.location == DOM_KEY_LOCATION_RIGHT
      keyname = keyname.replace('_L', '_R')
    # console.log 'keyname', keyname
    modifiers = @get_modifiers(event)
    if @caps_lock
      modifiers.push 'lock'
    keyval = keycode
    str = String.fromCharCode(event.which)
    group = 0
    shift = modifiers.indexOf('shift') >= 0
    if @caps_lock and shift or !@caps_lock and !shift
      str = str.toLowerCase()
    if @topwindow?
      #show("win="+win.toSource()+", keycode="+keycode+", modifiers=["+modifiers+"], str="+str);
      packet = [
        'key-action'
        @topwindow
        keyname
        pressed
        modifiers
        keyval
        str
        keycode
        group
      ]
      # console.log 'packet', packet
      @xpra.proto.Send.apply @xpra.proto, packet
    return

  onkeydown: (event) ->
    @processKeyEvent true, event
    false

  onkeyup: (event) ->
    @processKeyEvent false, event
    false

  ###*
  # This function is only used for figuring out the @caps_lock state!
  # onkeyup and onkeydown give us the raw keycode,
  # whereas here we get the keycode in lowercase/uppercase depending
  # on the @caps_lock and shift state, which allows us to figure
  # out @caps_lock state since we have shift state.
  ###

  onkeypress: (event) ->
    keycode = 0
    if event.which
      keycode = event.which
    else
      keycode = event.keyCode
    modifiers = @get_modifiers(event)

    ### PITA: this only works for keypress event... ###

    @caps_lock = false
    shift = modifiers.indexOf('shift') >= 0
    if keycode >= 97 and keycode <= 122 and shift
      @caps_lock = true
    else if keycode >= 65 and keycode <= 90 and !shift
      @caps_lock = true
    #show("@caps_lock="+@caps_lock);
    false

window.oncontextmenu = (e) ->
  #showCustomMenu();
  false
