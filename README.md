# Xpra-html-client
HTML5 client abstraction

Largely copied and adapted from [http://xpra.org/trac/ticket/473](http://xpra.org/trac/ticket/473)

No usable version yet, project under heavy development.

___
# Concept

`Xpra` is a seemless `X11 server`, allowing you to remotely access to your applications.

This client is based on `HTML5 canvas` for modern browsers, and allow to render and interact with your `X11` application directly inside your browser.

This library is `Event` based and try to provide a full and easy-to-learn encapsulation for every part of the `Xpra` protocol, and don't let the user deal with every other low-level programing problems.

Its core allows to deal with high-level `Window` encapsulations.


___
# Features
- Window object encapsulation
- Event based interactions
- Keyboard inputs
- Window pixmap drawn and updated on offscreen canvas

___
# Getting started

Here is a snippet to show how to use this library :

```coffeescript
# Take a host and a port
@client = new Xpra '1.1.1.1', 1234

@client.on 'new-window', (win) ->
  # Deal with this plain window object
  console.log win
  # Show for exemple :
    # _events: Object
    # height: 316
    # offscreen: canvas
    # properties: Object
    # wid: 2
    # width: 484
    # x: 0
    # ray: 30
```

Supported events from now :
- On client itselft :
  - 'new-window'

- On windows :
  - 'focus'
  - 'drawn'


___
# TODO

- Full working keyboard events
- Window on close
- Configuration
- Mouse
-
