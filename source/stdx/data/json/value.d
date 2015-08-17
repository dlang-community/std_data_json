/**
 * Defines a generic value type for builing and holding JSON documents in memory.
 *
 * Copyright: Copyright 2012 - 2015, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/value.d)
 */
module stdx.data.json.value;
@safe:

///
unittest {
    // build a simple JSON document
    auto aa = ["a": JSONValue("hello"), "b": JSONValue(true)];
    auto obj = JSONValue(aa);

    // JSONValue behaves almost as the contained native D types
    assert(obj["a"] == "hello");
    assert(obj["b"] == true);
}

import stdx.data.json.foundation;
import std.typecons : Nullable;
import taggedalgebraic;


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
    import std.exception : enforce;
    import stdx.data.json.lexer : JSONToken;

    /**
      * Defines the possible types contained in a `JSONValue`
      */
    union PayloadUnion {
        typeof(null) null_; /// A JSON `null` value
        bool boolean; /// JSON `true` or `false` values
        double double_; /// The default field for storing numbers
        long integer; /// Only used if `LexOptions.useLong` was set for parsing
        WrappedBigInt bigInt; /// Only used if `LexOptions.useBigInt` was set for parsing
        @disableIndex .string string; /// String value
        JSONValue[] array; /// Array or JSON values
        JSONValue[.string] object; /// Dictionary of JSON values (object)
    }

    /**
     * Alias for a $(D TaggedAlgebraic) able to hold all possible JSON
     * value types.
     */
    alias Payload = TaggedAlgebraic!PayloadUnion;

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

    ///
    alias payload this;

    /**
     * Constructs a JSONValue from the given raw value.
     */
    this(T)(T value, Location loc = Location.init) { payload = Payload(value); location = loc; }
    /// ditto
    void opAssign(T)(T value) { payload = value; }

    /// Tests if the stored value is of a given type.
    bool hasType(T)() const { return .hasType!T(payload); }

    /**
      * Returns the raw contained value.
      *
      * This must only be called if the type of the stored value matches `T`.
      * Use `.hasType!T` or `.typeID` for that purpose.
      */
    ref inout(T) get(T)() inout { return .get!T(payload); }

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
    assert(c[0] == 12.0);
    assert(c[1] == 13.0);
    assert(c[0] == a);
    assert(c[1] == b);

    auto d = JSONValue(["a": a, "b": b]);
    assert(d["a"] == 12.0);
    assert(d["b"] == 13.0);
    assert(d["a"] == a);
    assert(d["b"] == b);
}


/// Proxy structure that stores BigInt as a pointer to save space in JSONValue
static struct WrappedBigInt {
    import std.bigint;
    private BigInt* _pvalue;
    ///
    this(BigInt value) { _pvalue = new BigInt(value); }
    ///
    @property ref inout(BigInt) value() inout { return *_pvalue; }
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
            if (val.typeID != JSONValue.Type.object)
                return Nullable!JSONValue.init;
            auto pv = keys[i] in val;
            if (pv is null) return Nullable!JSONValue.init;
            val = *pv;
        }
        else static if (is(T : size_t))
        {
            size_t idx = keys[i]; // convert to unsigned first
            if (val.typeID != JSONValue.Type.array)
                return Nullable!JSONValue.init;
            if (idx >= val.length)
                return Nullable!JSONValue.init;
            val = val[idx];
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
    JSONValue subarr = [JSONValue(3.0), JSONValue(4.0), JSONValue(null)];
    JSONValue obj = ["a": subobj, "b": subarr];

    assert(obj.opt("x").isNull);
    assert(obj.opt("a", "b") == 1.0);
    assert(obj.opt("a", "c") == 2.0);
    assert(obj.opt("a", "x", "y").isNull);
    assert(obj.opt("b", 0) == 3.0);
    assert(obj.opt("b", 1) == 4.0);
    assert(!obj.opt("b", 2).isNull);
    assert(obj.opt("b", 2) == null);
    assert(obj.opt("b", 3).isNull);
}


/**
  * Alternative version of `opt` that works using dot and index notation.index
  */
auto opt2(JSONValue val)
{
    alias NJ = Nullable!JSONValue;

    static struct S(string path) {
        private NJ _val;

        @property bool exists() const { return !_val.isNull; }

        inout(JSONValue) get() inout
        {
            if (_val.isNull())
                throw new .Exception("Missing JSON value at "~path~".");
            return _val.get();
        }

        inout(T) get(T)(T def_value) inout
        {
            if (_val.isNull || !_val.hasType!T)
                return def_value;
            return _val.get.get!T;
        }

        alias get this;

        auto opDispatch(string name)()
        {
            enum newpath = path ~ "." ~ name;
            alias SR = S!newpath;
            if (_val.isNull()) return SR.init;
            if (_val.typeID != JSONValue.Type.object)
                return SR.init;
            if (auto pv = name in _val)
                return SR(NJ(*pv));
            return SR.init;
        }

        auto opIndex()(size_t idx)
        {
            enum newpath = path ~ "[]";
            alias SR = S!newpath;
            if (_val.isNull()) return SR.init;
            if (_val.typeID != JSONValue.Type.array)
                return SR.init;
            if (idx >= _val.length)
                return SR.init;
            return SR(NJ(_val[idx]));
        }

        auto opIndex()(string name)
        {
            enum newpath = path ~ "[$]";
            alias SR = S!newpath;
            if (_val.isNull()) return SR.init;
            if (_val.typeID != JSONValue.Type.object)
                return SR.init;
            if (auto pv = name in _val)
                return SR(NJ(*pv));
            return SR.init;
        }
    }
    return S!""(NJ(val));
}

///
unittest
{
    import std.exception : assertThrown;

    JSONValue subobj = ["b": JSONValue(1.0), "c": JSONValue(2.0)];
    JSONValue subarr = [JSONValue(3.0), JSONValue(4.0), JSONValue(null)];
    JSONValue obj = ["a": subobj, "b": subarr];

    // access nested fields using member access syntax
    assert(obj.opt2.a.b == 1.0);
    assert(obj.opt2.a.c == 2.0);

    // get can be used with a default value
    assert(obj.opt2.a.c.get(-1.0) == 2.0); // matched path and type
    assert(obj.opt2.a.c.get(null) == null); // mismatched type -> return default value
    assert(obj.opt2.a.d.get(-1.0) == -1.0); // mismatched path -> return default value

    // explicit existence check
    assert(!obj.opt2.x.exists);
    assert(!obj.opt2.a.x.y.exists); // works for nested missing paths, too

    // instead of using member syntax, index syntax can be used
    assert(obj.opt2["a"]["b"] == 1.0);

    // integer indices work, too
    assert(obj.opt2.b[0] == 3.0);
    assert(obj.opt2.b[1] == 4.0);
    assert(obj.opt2.b[2].exists);
    assert(obj.opt2.b[2] == null);
    assert(!obj.opt2.b[3].exists);

    // accessing a missing path throws an exception
    assertThrown(obj.opt2.b[3] == 3);
}
