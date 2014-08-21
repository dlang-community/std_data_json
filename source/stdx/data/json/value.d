/**
 * Defines a generic JSON value type.
 *
 * Synopsis:
 * ---
 * ...
 * ---
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/value.d)
 */
module stdx.data.json.value;

import stdx.data.json.foundation;


/**
 * Represents a generic JSON value.
 *
 * The $(D JSONValue) type is based on $(D std.variant.Algebraic) and as such
 * provides the usual binary and unary operators for handling the contained
 * raw value.
 *
 * Raw values can be either $(D null), $(D bool), $(D double), $(D string),
 * $(D JSONValue[]) or $(D JSONValue[string]).
*/
struct JSONValue {
    import std.variant : Algebraic;
    import stdx.data.json.lexer : JSONToken;

    alias Payload = Algebraic!(
        typeof(null),
        bool,
        double,
        string,
        JSONValue[],
        JSONValue[string]
    );

    Payload payload;
    Location location;

    alias payload this;

    /**
     * Constructs a JSONValue from the given raw value.
     */
    this(typeof(null), Location loc = Location.init) { payload = Payload(null); location = loc; }
    /// ditto
    this(bool value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    this(double value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    this(string value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    this(JSONValue[] value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    this(JSONValue[string] value, Location loc = Location.init) { payload = Payload(value); location = loc; }
}

///
unittest {
    JSONValue a = 12;
    JSONValue b = 13;

    assert(a == 12.0);
    assert(b == 13.0);
    //assert(a + b == 25.0);

    auto c = JSONValue([a, b]);
    //assert(c[0] == 12);
    //assert(c[1] == 13);

    auto d = JSONValue(["a": a, "b": b]);
    //assert(d["a"] == 12);
    //assert(d["b"] == 13);
}

