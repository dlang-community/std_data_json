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

    /// Tests if the stored value is of kind `Kind.null_`.
    bool isNull() const { return payload.kind == Kind.null_; }

    /**
      * Returns the raw contained value.
      *
      * This must only be called if the type of the stored value matches `T`.
      * Use `.hasType!T` or `.typeID` for that purpose.
      */
    ref inout(T) get(T)() inout { return .get!T(payload); }
}

/// Shows the basic construction and operations on JSON values.
unittest
{
    JSONValue a = 12;
    JSONValue b = 13;

    assert(a == 12.0);
    assert(b == 13.0);
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
  * Allows safe access of sub paths of a `JSONValue`.
  *
  * Missing intermediate values will not cause an error, but will instead
  * just cause the final path node to be marked as non-existent. See the
  * example below for the possbile use cases.
  */
auto opt()(auto ref JSONValue val)
{
    alias C = JSONValue; // this function is generic and could also operate on BSONValue or similar types
    static struct S(F...) {
        private {
            static if (F.length > 0) {
                S!(F[0 .. $-1])* _parent;
                F[$-1] _field;
            }
            else
            {
                C* _container;
            }
        }

        static if (F.length == 0)
        {
            this(ref C container)
            {
                () @trusted { _container = &container; } ();
            }
        }
        else
        {
            this (ref S!(F[0 .. $-1]) s, F[$-1] field)
            {
                () @trusted { _parent = &s; } ();
                _field = field;
            }
        }

        @disable this(); // don't let the reference escape

        @property bool exists() const { return resolve !is null; }

        inout(JSONValue) get() inout
        {
            auto val = this.resolve();
            if (val is null)
                throw new .Exception("Missing JSON value at "~this.path()~".");
            return *val;
        }

        inout(T) get(T)(T def_value) inout
        {
            auto val = resolve();
            if (val is null || !val.hasType!T)
                return def_value;
            return val.get!T;
        }

        alias get this;

        @property auto opDispatch(string name)()
        {
            return S!(F, string)(this, name);
        }

        @property void opDispatch(string name, T)(T value)
        {
            (*resolveWrite(OptWriteMode.dict))[name] = value;
        }

        auto opIndex()(size_t idx)
        {
            return S!(F, size_t)(this, idx);
        }

        auto opIndex()(string name)
        {
            return S!(F, string)(this, name);
        }

        auto opIndexAssign(T)(T value, size_t idx)
        {
            *(this[idx].resolveWrite(OptWriteMode.any)) = value;
        }

        auto opIndexAssign(T)(T value, string name)
        {
            (*resolveWrite(OptWriteMode.dict))[name] = value;
        }

        private inout(C)* resolve()
        inout {
            static if (F.length > 0)
            {
                auto c = this._parent.resolve();
                if (!c) return null;
                static if (is(F[$-1] : long)) {
                    if (!c.hasType!(C[])) return null;
                    if (_field < c.length) return &c.get!(C[])[_field];
                    return null;
                }
                else
                {
                    if (!c.hasType!(C[string])) return null;
                    return this._field in *c;
                }
            }
            else
            {
                return _container;
            }
        }

        private C* resolveWrite(OptWriteMode mode)
        {
            C* v;
            static if (F.length == 0)
            {
                v = _container;
            }
            else
            {
                auto c = _parent.resolveWrite(is(F[$-1] == string) ? OptWriteMode.dict : OptWriteMode.array);
                static if (is(F[$-1] == string))
                {
                    v = _field in *c;
                    if (!v)
                    {
                        (*c)[_field] = mode == OptWriteMode.dict ? C(cast(C[string])null) : C(cast(C[])null);
                        v = _field in *c;
                    }
                }
                else
                {
                    import std.conv : to;
                    if (_field >= c.length)
                        throw new Exception("Array index "~_field.to!string()~" out of bounds ("~c.length.to!string()~") for "~_parent.path()~".");
                    v = &c.get!(C[])[_field];
                }
            }

            final switch (mode)
            {
                case OptWriteMode.dict:
                    if (!v.hasType!(C[string]))
                        throw new .Exception(pname()~" is not a dictionary/object. Cannot set a field.");
                    break;
                case OptWriteMode.array:
                    if (!v.hasType!(C[]))
                        throw new .Exception(pname()~" is not an array. Cannot set an entry.");
                    break;
                case OptWriteMode.any: break;
            }

            return v;
        }

        private string path() const
        {
            static if (F.length > 0)
            {
                import std.conv : to;
                static if (is(F[$-1] == string)) return this._parent.path() ~ "." ~ this._field;
                else return this._parent.path() ~ "[" ~ this._field.to!string ~ "]";
            }
            else
            {
                return "";
            }
        }

        private string pname() const
        {
            static if (F.length > 0) return "Field "~_parent.path();
            else return "Value";
        }
    }

    return S!()(val);
}

///
unittest
{
    import std.exception : assertThrown;

    JSONValue subobj = ["b": JSONValue(1.0), "c": JSONValue(2.0)];
    JSONValue subarr = [JSONValue(3.0), JSONValue(4.0), JSONValue(null)];
    JSONValue obj = ["a": subobj, "b": subarr];

    // access nested fields using member access syntax
    assert(opt(obj).a.b == 1.0);
    assert(opt(obj).a.c == 2.0);

    // get can be used with a default value
    assert(opt(obj).a.c.get(-1.0) == 2.0); // matched path and type
    assert(opt(obj).a.c.get(null) == null); // mismatched type -> return default value
    assert(opt(obj).a.d.get(-1.0) == -1.0); // mismatched path -> return default value

    // explicit existence check
    assert(!opt(obj).x.exists);
    assert(!opt(obj).a.x.y.exists); // works for nested missing paths, too

    // instead of using member syntax, index syntax can be used
    assert(opt(obj)["a"]["b"] == 1.0);

    // integer indices work, too
    assert(opt(obj).b[0] == 3.0);
    assert(opt(obj).b[1] == 4.0);
    assert(opt(obj).b[2].exists);
    assert(opt(obj).b[2] == null);
    assert(!opt(obj).b[3].exists);

    // accessing a missing path throws an exception
    assertThrown(opt(obj).b[3] == 3);

    // assignments work, too
    opt(obj).b[0] = 12;
    assert(opt(obj).b[0] == 12);

    // assignments to non-existent paths automatically create all missing parents
    opt(obj).c.d.opDispatch!"e"( 12);
    assert(opt(obj).c.d.e == 12);

    // writing to paths with conflicting types will throw
    assertThrown(opt(obj).c[2] = 12);

    // writing out of array bounds will also throw
    assertThrown(opt(obj).b[10] = 12);
}

private enum OptWriteMode {
    dict,
    array,
    any
}
