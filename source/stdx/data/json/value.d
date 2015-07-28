/**
 * Defines a generic value type for builing and holding JSON documents in memory.
 *
 * Synopsis:
 * ---
 * // build a simple JSON document
 * auto aa = ["a": JSONValue("hello"), "b": JSONValue(true)];
 * auto obj = JSONValue(aa);
 *
 * // Algebraic currently doesn't allow the desired syntax: obj["a"]
 * assert(obj.get!(JSONValue[string])["a"] == "hello");
 * assert(obj.get!(JSONValue[string])["b"] == true);
 * ---
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/value.d)
 */
module stdx.data.json.value;
@safe

import stdx.data.json.foundation;
import std.typecons : Nullable;


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
struct JSONValue
{
    @safe:
    import std.bigint;
    import std.exception : enforce;
    import std.variant : Algebraic;
    import stdx.data.json.lexer : JSONToken;

    /**
     * Alias for a $(D std.variant.Algebraic) able to hold all possible JSON
     * value types.
     */
    alias Payload = Algebraic!(
        typeof(null),
        bool,
        double,
        long,
        BigInt,
        string,
        JSONValue[],
        JSONValue[string]
    );

    /**
     * Holds the data contained in this value.
     *
     * Note that this is available using $(D alias this), so there is usually no
     * need to access this field directly.
     */
    Payload payload;

    /**
     * Optional location of the corresponding token in the source document.
     *
     * This field will be automatically populated by the JSON parser if location
     * tracking is enabled.
     */
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
    this(long value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    this(BigInt value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    this(string value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    this(JSONValue[] value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    this(JSONValue[string] value, Location loc = Location.init) { payload = Payload(value); location = loc; }

    static if (__VERSION__ < 2067)
    {
        /**
         * Temporary index operations until std.variant is fixed in 2.067
         *
         * These exist only to overcome current shortcomings in the index
         * op for std.variant, which should be fixed in 2.067 and above.
         * See https://github.com/s-ludwig/std_data_json/pull/3#issuecomment-73127624
         */
        ref JSONValue opIndex(size_t idx)
        {
            auto asArray = payload.peek!(JSONValue[]);
            enforce(asArray != null, "JSONValue is not an array");
            return (*asArray)[idx];
        }

        /// Ditto
        ref JSONValue opIndex(string key)
        {
            auto asObject = payload.peek!(JSONValue[string]);
            enforce(asObject != null, "JSONValue is not an object");
            return (*asObject)[key];
        }
    }
}

/// Shows the basic construction and operations on JSON values.
unittest
{
    JSONValue a = 12;
    JSONValue b = 13;

    assert(a == 12.0);
    assert(b == 13.0);
    static if (__VERSION__ >= 2067)
        assert(a + b == 25.0);

    auto c = JSONValue([a, b]);
    assert(c.get!(JSONValue[])[0] == 12.0);
    assert(c.get!(JSONValue[])[1] == 13.0);
    assert(c[0] == a);
    assert(c[1] == b);
    static if (__VERSION__ < 2067) {
        assert(c[0] == 12.0);
        assert(c[1] == 13.0);
    }

    auto d = JSONValue(["a": a, "b": b]);
    assert(d.get!(JSONValue[string])["a"] == 12.0);
    assert(d.get!(JSONValue[string])["b"] == 13.0);
    assert(d["a"] == a);
    assert(d["b"] == b);
    static if (__VERSION__ < 2067) {
        assert(d["a"] == 12.0);
        assert(d["b"] == 13.0);
    }
}


/**
 * Gets a descendant of this value.
 *
 * If any encountered `JSONValue` along the path is not an object or does not
 * have a machting field, a `null` value is returned.
 */
Nullable!JSONValue opt(KEYS...)(JSONValue val, KEYS keys)
    if (KEYS.length > 0)
{
    foreach (i, T; KEYS)
    {
        static if (is(T : string))
        {
            auto obj = val.peek!(JSONValue[string]);
            if (!obj) return Nullable!JSONValue.init;
            auto pv = keys[i] in *obj;
            if (pv is null) return Nullable!JSONValue.init;
            val = *pv;
        }
        else static if (is(T : size_t))
        {
            size_t idx = keys[i]; // convert to unsigned first
            auto arr = val.peek!(JSONValue[]);
            if (!arr || idx >= (*arr).length)
                return Nullable!JSONValue.init;
            val = (*arr)[idx];
        }
        else
        {
            static assert(false, "Only strings and integer indices are allowed as keys, not "~T.stringof);
        }
    }
    return Nullable!JSONValue(val);
}

///
unittest
{
    JSONValue subobj = ["b": JSONValue(1.0), "c": JSONValue(2.0)];
    JSONValue subarr = [JSONValue(3.0), JSONValue(4.0)];
    JSONValue obj = ["a": subobj, "b": subarr];

    assert(obj.opt("x").isNull);
    assert(obj.opt("a", "b") == 1.0);
    assert(obj.opt("a", "c") == 2.0);
    assert(obj.opt("a", "x", "y").isNull);
    assert(obj.opt("b", 0) == 3.0);
    assert(obj.opt("b", 1) == 4.0);
    assert(obj.opt("b", 2).isNull);
}
