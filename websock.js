/*
 * Websock: high-performance binary WebSockets
 * Copyright (C) 2012 Joel Martin
 * Copyright (c) 2014 Joshua Higgins <josh@kxes.net>
 * Licensed under MPL 2.0 (see LICENSE.txt)
 *
 * * This version is modified to
 * * - remove references to window object for worker use
 * * - removes dependency on noVNC's Util helper
 * * - rQpeekBytes() to peek an arbitrary number of bytes
 *
 * Websock is similar to the standard WebSocket object but Websock
 * enables communication with raw TCP sockets (i.e. the binary stream)
 * via websockify. This is accomplished by base64 encoding the data
 * stream between Websock and websockify.
 *
 * Websock has built-in receive queue buffering; the message event
 * does not contain actual data but is simply a notification that
 * there is new data available. Several rQ* methods are available to
 * read binary data off of the receive queue.
 *
 */

/*jslint browser: true, bitwise: false, plusplus: false */
/*global Util, Base64 */


// Workers cannot access window object, so assume native websocket
// is available
Websock_native = true;


function Websock(host, port) {
"use strict";

var api = {},         // Public API
    websocket = null, // WebSocket object
    mode = 'binary',  // Current WebSocket mode: 'binary', 'base64'
    rQ = [],          // Receive queue
    rQi = 0,          // Receive queue index
    rQmax = 10000,    // Max receive queue size before compacting
    sQ = [],          // Send queue

    eventHandlers = {
        'message' : function() {},
        'open'    : function() {},
        'close'   : function() {},
        'error'   : function() {}
    },

    test_mode = false;

//
// Queue public functions
//

function get_sQ() {
    return sQ;
}

function get_rQ() {
    return rQ;
}
function get_rQi() {
    return rQi;
}
function set_rQi(val) {
    rQi = val;
}

function rQlen() {
    return rQ.length - rQi;
}

function rQpeek8() {
    return (rQ[rQi]      );
}
function rQpeekBytes(len) {
    return rQ.slice(rQi, rQi+len);
}
function rQshift8() {
    return (rQ[rQi++]      );
}
function rQunshift8(num) {
    if (rQi === 0) {
        rQ.unshift(num);
    } else {
        rQi -= 1;
        rQ[rQi] = num;
    }

}
function rQshift16() {
    return (rQ[rQi++] <<  8) +
           (rQ[rQi++]      );
}
function rQshift32() {
    return (rQ[rQi++] << 24) +
           (rQ[rQi++] << 16) +
           (rQ[rQi++] <<  8) +
           (rQ[rQi++]      );
}
function rQshiftStr(len) {
    if (typeof(len) === 'undefined') { len = rQlen(); }
    var arr = rQ.slice(rQi, rQi + len);
    rQi += len;
    return String.fromCharCode.apply(null, arr);
}
function rQshiftBytes(len) {
    if (typeof(len) === 'undefined') { len = rQlen(); }
    rQi += len;
    return rQ.slice(rQi-len, rQi);
}

function rQslice(start, end) {
    if (end) {
        return rQ.slice(rQi + start, rQi + end);
    } else {
        return rQ.slice(rQi + start);
    }
}

// Check to see if we must wait for 'num' bytes (default to FBU.bytes)
// to be available in the receive queue. Return true if we need to
// wait (and possibly print a console.log message), otherwise false.
function rQwait(msg, num, goback) {
    var rQlen = rQ.length - rQi; // Skip rQlen() function call
    if (rQlen < num) {
        if (goback) {
            if (rQi < goback) {
                throw("rQwait cannot backup " + goback + " bytes");
            }
            rQi -= goback;
        }
        //console.log("   waiting for " + (num-rQlen) +
        //           " " + msg + " byte(s)");
        return true;  // true means need more data
    }
    return false;
}

//
// Private utility routines
//

function encode_message() {
    // console.log(">> encode_message: ",  sQ);
    if (mode === 'binary') {
        // Put in a binary arraybuffer
        return (new Uint8Array(sQ)).buffer;
    } else {
        // base64 encode
        return Base64.encode(sQ);
    }
}

function decode_message(data) {
    // console.log(">> decode_message: ",  data);
    if (mode === 'binary') {
        // push arraybuffer values onto the end
        var u8 = new Uint8Array(data);
        // console.log('u8', u8);
        for (var i = 0; i < u8.length; i++) {
            // console.log(String.fromCharCode(u8[i]))
            rQ.push(u8[i]);
        }
        // console.log('rQ', rQ);
    } else {
        // base64 decode and concat to the end
        rQ = rQ.concat(Base64.decode(data, 0));
    }
    //console.log(">> decode_message, rQ: " + rQ);
}


//
// Public Send functions
//

function flush() {
    if (websocket.bufferedAmount !== 0) {
        // console.log("bufferedAmount: " + websocket.bufferedAmount);
    }
    if (websocket.bufferedAmount < api.maxBufferedAmount) {
        //console.log("arr: " + arr);
        //console.log("sQ: " + sQ);
        if (sQ.length > 0) {
            websocket.send(encode_message(sQ));
            sQ = [];
        }
        return true;
    } else {
        // console.log("Delaying send, bufferedAmount: " +
        //         websocket.bufferedAmount);
        return false;
    }

    // flush buffer immediately
    //websocket.send(encode_message(sQ));
    //sQ = [];
    //return true;
}

// overridable for testing
function send(arr) {
    //console.log(">> send_array: " + arr);
    sQ = sQ.concat(arr);
    return flush();
    //websocket.send(arr);
}

function send_string(str) {
    //console.log(">> send_string: " + str);
    api.send(str.split('').map(
        function (chr) { return chr.charCodeAt(0); } ) );
}

//
// Other public functions

function recv_message(e) {
    //console.log(">> recv_message: " + e.data.length);
    // console.log("recv", e);
    try {
        decode_message(e.data);
        if (rQlen() > 0) {
            eventHandlers.message();
            // Compact the receive queue
            if (rQ.length > rQmax) {
                //console.log("Compacting receive queue");
                rQ = rQ.slice(rQi);
                rQi = 0;
            }
        } else {
            console.log("Ignoring empty message");
        }
    } catch (exc) {
        if (typeof exc.stack !== 'undefined') {
            console.log("recv_message, caught exception: " + exc.stack);
        } else if (typeof exc.description !== 'undefined') {
            console.log("recv_message, caught exception: " + exc.description);
        } else {
            console.log("recv_message, caught exception:" + exc);
        }
        if (typeof exc.name !== 'undefined') {
            eventHandlers.error(exc.name + ": " + exc.message);
        } else {
            eventHandlers.error(exc);
        }
    }
    //console.log("<< recv_message");
}


// Set event handlers
function on(evt, handler) {
    eventHandlers[evt] = handler;
}

function init(protocols) {
    rQ         = [];
    rQi        = 0;
    sQ         = [];
    websocket  = null;
}

function open(url, protocols) {
    init();

    if (test_mode) {
        websocket = {};
    } else {
        websocket = new WebSocket(url, protocols);
        if (protocols.indexOf('binary') >= 0) {
            websocket.binaryType = 'arraybuffer';
        }
    }

    websocket.onmessage = recv_message;
    websocket.onopen = function() {
        console.log(">> WebSock.onopen");
        if (websocket.protocol) {
            mode = websocket.protocol;
            console.log("Server chose sub-protocol: " + websocket.protocol);
        } else {
            mode = 'base64';
            console.log("Server select no sub-protocol!: " + websocket.protocol);
        }
        eventHandlers.open();
        console.log("<< WebSock.onopen");
    };
    websocket.onclose = function(e) {
        console.log(">> WebSock.onclose");
        eventHandlers.close(e);
        console.log("<< WebSock.onclose");
    };
    websocket.onerror = function(e) {
        console.log(">> WebSock.onerror: " + e);
        eventHandlers.error(e);
        console.log("<< WebSock.onerror");
    };
}

function close() {
    if (websocket) {
        if ((websocket.readyState === WebSocket.OPEN) ||
            (websocket.readyState === WebSocket.CONNECTING)) {
            console.log("Closing WebSocket connection");
            websocket.close();
        }
        websocket.onmessage = function (e) { return; };
    }
}

// Override internal functions for testing
// Takes a send function, returns reference to recv function
function testMode(override_send, data_mode) {
    test_mode = true;
    mode = data_mode;
    api.send = override_send;
    api.close = function () {};
    return recv_message;
}

function constructor() {
    // Configuration settings
    api.maxBufferedAmount = 200;

    // Direct access to send and receive queues
    api.get_sQ       = get_sQ;
    api.get_rQ       = get_rQ;
    api.get_rQi      = get_rQi;
    api.set_rQi      = set_rQi;

    // Routines to read from the receive queue
    api.rQlen        = rQlen;
    api.rQpeek8      = rQpeek8;
    api.rQpeekBytes  = rQpeekBytes;
    api.rQshift8     = rQshift8;
    api.rQunshift8   = rQunshift8;
    api.rQshift16    = rQshift16;
    api.rQshift32    = rQshift32;
    api.rQshiftStr   = rQshiftStr;
    api.rQshiftBytes = rQshiftBytes;
    api.rQslice      = rQslice;
    api.rQwait       = rQwait;

    api.flush        = flush;
    api.send         = send;
    api.send_string  = send_string;

    api.on           = on;
    api.init         = init;
    api.open         = open;
    api.close        = close;
    api.testMode     = testMode;

    return api;
}

return constructor();

}
