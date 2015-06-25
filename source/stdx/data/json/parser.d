/**
 * Provides various means for parsing JSON documents.
 *
 * This module contains two different parser implementations. The first
 * implementation returns a single JSON document in the form of a
 * $(D JSONValue), while the second implementation returns a stream
 * of nodes. The stream based parser is particularly useful for
 * deserializing with few allocations or for processing large documents.
 *
 * Synopsis:
 * ---
 * // Parse a JSON string to a single value
 * JSONValue value = parseJSONValue(`{"name": "D", "kind": "language"}`);
 *
 * // Parse a JSON string to a node stream
 * auto nodes = parseJSONStream(`{"name": "D", "kind": "language"}`);
 * with (JSONParserNode.Kind) {
 *     assert(nodes.map!(n => n.kind).equal(
 *         [objectStart, key, literal, key, literal, objectEnd]));
 * }
 *
 * // Parse a list of tokens instead of a string
 * auto tokens = lexJSON(`{"name": "D", "kind": "language"}`);
 * JSONValue value2 = parseJSONValue(tokens);
 * assert(value == value2);
 * ---
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/parser.d)
 */
module stdx.data.json.parser;
@safe:

import stdx.data.json.lexer;
import stdx.data.json.value;
import std.array : appender;
import std.range : isInputRange;


/**
 * Parses a JSON string or token range and returns the result as a
 * $(D JSONValue).
 *
 * The input string must be a valid JSON document. In particular, it must not
 * contain any additional text other than whitespace after the end of the
 * JSON document.
 *
 * See_also: $(D parseJSONValue)
 */
JSONValue toJSONValue(LexOptions options = LexOptions.init, Input)(Input input, string filename = "")
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    auto tokens = lexJSON!options(input, filename);
    return toJSONValue(tokens);
}
/// ditto
JSONValue toJSONValue(Input)(Input tokens)
    if (isJSONTokenInputRange!Input)
{
    import stdx.data.json.foundation;
    auto ret = parseJSONValue(tokens);
    enforceJson(tokens.empty, "Unexpected characters following JSON", tokens.location);
    return ret;
}

///
@trusted /*2.065*/ unittest
{
    // parse a simple number
    JSONValue a = toJSONValue(`1.0`);
    assert(a == 1.0);

    // parse an object
    JSONValue b = toJSONValue(`{"a": true, "b": "test"}`);
    auto bdoc = b.get!(JSONValue[string]);
    assert(bdoc.length == 2);
    assert(bdoc["a"] == true);
    assert(bdoc["b"] == "test");

    // parse an array
    JSONValue c = toJSONValue(`[1, 2, null]`);
    auto cdoc = c.get!(JSONValue[]);
    assert(cdoc.length == 3);
    assert(cdoc[0] == 1.0);
    assert(cdoc[1] == 2.0);
    assert(cdoc[2] == null);
}

unittest
{
    import std.exception;
    assertNotThrown(toJSONValue("{} \t\r\n"));
    assertThrown(toJSONValue(`{} {}`));
}


/**
 * Parses a JSON string and returns the result as a $(D JSONValue).
 *
 * The input string must start with a valid JSON document. Any characters
 * occurring after this document will be left in the input range.
 */
JSONValue parseJSONValue(LexOptions options = LexOptions.init, Input)(ref Input input, string filename = "")
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    import stdx.data.json.foundation;

    auto tokens = lexJSON!options(input, filename);
    auto ret = parseJSONValue(tokens);
    input = tokens.input;
    return ret;
}

/// Parse an object
@trusted /*2.065*/ unittest
{
    // parse an object
    string str = `{"a": true, "b": "test"}`;
    JSONValue v = parseJSONValue(str);
    assert(!str.length); // the input has been consumed

    auto obj = v.get!(JSONValue[string]);
    assert(obj.length == 2);
    assert(obj["a"] == true);
    assert(obj["b"] == "test");
}

/// Parse multiple consecutive values
unittest
{
    string str = `1.0 2.0`;
    JSONValue v1 = parseJSONValue(str);
    assert(v1 == 1.0);
    JSONValue v2 = parseJSONValue(str);
    assert(v2 == 2.0);
}


/**
 * Parses a stream of JSON tokens and returns the result as a $(D JSONValue).
 *
 * All tokens belonging to the document will be consumed from the input range.
 * Any tokens after the end of the first JSON document will be left in the
 * input token range for possible later consumption.
*/
JSONValue parseJSONValue(Input)(ref Input tokens)
    if (isJSONTokenInputRange!Input)
{
    import std.array;
    import stdx.data.json.foundation;

    enforceJson(!tokens.empty, "Missing JSON value before EOF", tokens.location);

    JSONValue ret;

    final switch (tokens.front.kind) with (JSONToken.Kind)
    {
        case none: assert(false);
        case error: enforceJson(false, "Invalid token encountered", tokens.front.location); assert(false);
        case null_: ret = JSONValue(null); break;
        case boolean: ret = JSONValue(tokens.front.boolean); break;
        case number:
            final switch (tokens.front.number.type)
            {
                case JSONNumber.Type.double_: ret = JSONValue(tokens.front.number.doubleValue); break;
                case JSONNumber.Type.long_: ret = JSONValue(tokens.front.number.longValue); break;
                case JSONNumber.Type.bigInt: ret = JSONValue(tokens.front.number.bigIntValue); break;
            }
            break;
        case string: ret = JSONValue(tokens.front.string); break;
        case objectStart:
            auto loc = tokens.front.location;
            bool first = true;
            JSONValue[.string] obj;
            tokens.popFront();
            while (true)
            {
                enforceJson(!tokens.empty, "Missing closing '}'", loc);
                if (tokens.front.kind == objectEnd) break;

                if (!first)
                {
                    enforceJson(tokens.front.kind == comma, "Expected ',' or '}'", tokens.front.location);
                    tokens.popFront();
                    enforceJson(!tokens.empty, "Expected field name", tokens.location);
                }
                else first = false;

                enforceJson(tokens.front.kind == string, "Expected field name string", tokens.front.location);
                auto key = tokens.front.string;
                tokens.popFront();
                enforceJson(!tokens.empty && tokens.front.kind == colon, "Expected ':'",
                    tokens.empty ? tokens.location : tokens.front.location);
                tokens.popFront();
                obj[key] = parseJSONValue(tokens);
            }
            ret = JSONValue(obj, loc);
            break;
        case arrayStart:
            auto loc = tokens.front.location;
            bool first = true;
            auto array = appender!(JSONValue[]);
            tokens.popFront();
            while (true)
            {
                enforceJson(!tokens.empty, "Missing closing ']'", loc);
                if (tokens.front.kind == arrayEnd) break;

                if (!first)
                {
                    enforceJson(tokens.front.kind == comma, "Expected ',' or ']'", tokens.front.location);
                    tokens.popFront();
                }
                else first = false;

                () @trusted { array ~= parseJSONValue(tokens); }();
            }
            ret = JSONValue(array.data, loc);
            break;
        case objectEnd, arrayEnd, colon, comma:
            enforceJson(false, "Expected JSON value", tokens.front.location);
            assert(false);
    }

    tokens.popFront();
    return ret;
}

///
unittest
{
    // lex
    auto tokens = lexJSON(`[1, 2, 3]`);

    // parse
    auto doc = parseJSONValue(tokens);

    auto arr = doc.get!(JSONValue[]);
    assert(arr.length == 3);
    assert(arr[0] == 1.0);
    assert(arr[1] == 2.0);
    assert(arr[2] == 3.0);
}

unittest
{
    import std.exception;

    assertThrown(toJSONValue(`]`));
    assertThrown(toJSONValue(`}`));
    assertThrown(toJSONValue(`,`));
    assertThrown(toJSONValue(`:`));
    assertThrown(toJSONValue(`{`));
    assertThrown(toJSONValue(`[`));
    assertThrown(toJSONValue(`[1,]`));
    assertThrown(toJSONValue(`[1,,]`));
    assertThrown(toJSONValue(`[1,`));
    assertThrown(toJSONValue(`[1 2]`));
    assertThrown(toJSONValue(`{1: 1}`));
    assertThrown(toJSONValue(`{"a": 1,}`));
    assertThrown(toJSONValue(`{"a" 1}`));
    assertThrown(toJSONValue(`{"a": 1 "b": 2}`));
}

/**
 * Parses a JSON document using a lazy parser node range.
 *
 * This mode parsing mode is similar to a streaming XML (StAX) parser. It can
 * be used to parse JSON documents of unlimited size. The memory consumption
 * grows linearly with the nesting level (about 4 bytes per level), but is
 * independent of the number of values in the JSON document.
 *
 * The resulting range of nodes is guaranteed to be ordered according to the
 * following grammar, where uppercase terminals correspond to the node kind
 * (See $(D JSONParserNode.Kind)).
 *
 * $(UL
 *   $(LI list → value*)
 *   $(LI value → LITERAL | array | object)
 *   $(LI array → ARRAYSTART (value)* ARRAYEND)
 *   $(LI object → OBJECTSTART (KEY value)* OBJECTEND)
 * )
 */
JSONParserRange!(JSONLexerRange!(Input, options, appenderFactory))
    parseJSONStream(LexOptions options = LexOptions.init, alias appenderFactory = () => appender!string(), Input)
        (Input input, string filename = null)
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    return parseJSONStream(lexJSON!(options, appenderFactory)(input, filename));
}
/// ditto
JSONParserRange!Input parseJSONStream(Input)(Input tokens)
    if (isJSONTokenInputRange!Input)
{
    return JSONParserRange!Input(tokens);
}

///
unittest
{
    import std.algorithm;

    auto rng1 = parseJSONStream(`{ "a": 1, "b": [null] }`);
    with (JSONParserNode.Kind)
    {
        assert(rng1.map!(n => n.kind).equal(
            [objectStart, key, literal, key, arrayStart, literal, arrayEnd,
            objectEnd]));
    }

    auto rng2 = parseJSONStream(`1 {"a": 2} null`);
    with (JSONParserNode.Kind)
    {
        assert(rng2.map!(n => n.kind).equal(
            [literal, objectStart, key, literal, objectEnd, literal]));
    }
}

unittest
{
    auto rng = parseJSONStream(`{"a": 1, "b": [null, true], "c": {"d": {}}}`);
    with (JSONParserNode.Kind)
    {
        rng.popFront();
        assert(rng.front.kind == key && rng.front.key == "a"); rng.popFront();
        assert(rng.front.kind == literal && rng.front.literal.number == 1.0); rng.popFront();
        assert(rng.front.kind == key && rng.front.key == "b"); rng.popFront();
        assert(rng.front.kind == arrayStart); rng.popFront();
        assert(rng.front.kind == literal && rng.front.literal.kind == JSONToken.Kind.null_); rng.popFront();
        assert(rng.front.kind == literal && rng.front.literal.boolean == true); rng.popFront();
        assert(rng.front.kind == arrayEnd); rng.popFront();
        assert(rng.front.kind == key && rng.front.key == "c"); rng.popFront();
        assert(rng.front.kind == objectStart); rng.popFront();
        assert(rng.front.kind == key && rng.front.key == "d"); rng.popFront();
        assert(rng.front.kind == objectStart); rng.popFront();
        assert(rng.front.kind == objectEnd); rng.popFront();
        assert(rng.front.kind == objectEnd); rng.popFront();
        assert(rng.front.kind == objectEnd); rng.popFront();
        assert(rng.empty);
    }
}

unittest
{
    auto rng = parseJSONStream(`[]`);
    with (JSONParserNode.Kind)
    {
        import std.algorithm;
        assert(rng.map!(n => n.kind).equal([arrayStart, arrayEnd]));
    }
}

@trusted unittest
{
    import std.array;
    import std.exception;

    assertThrown(parseJSONStream(`]`).array);
    assertThrown(parseJSONStream(`}`).array);
    assertThrown(parseJSONStream(`,`).array);
    assertThrown(parseJSONStream(`:`).array);
    assertThrown(parseJSONStream(`{`).array);
    assertThrown(parseJSONStream(`[`).array);
    assertThrown(parseJSONStream(`[1,]`).array);
    assertThrown(parseJSONStream(`[1,,]`).array);
    assertThrown(parseJSONStream(`[1,`).array);
    assertThrown(parseJSONStream(`[1 2]`).array);
    assertThrown(parseJSONStream(`{1: 1}`).array);
    assertThrown(parseJSONStream(`{"a": 1,}`).array);
    assertThrown(parseJSONStream(`{"a" 1}`).array);
    assertThrown(parseJSONStream(`{"a": 1 "b": 2}`).array);
    assertThrown(parseJSONStream(`{"a": 1, "b": [null, true], "c": {"d": {}}}}`).array);
}

unittest { // test for @nogc interface
   static struct MyAppender
   {
        @nogc:
        void put(string s) { }
        void put(dchar ch) {}
        void put(char ch) {}
        @property string data() { return null; }
    }
    static MyAppender createAppender() @nogc { return MyAppender.init; }

    static struct EmptyStream
    {
        @nogc:
        @property bool empty() { return true; }
        @property dchar front() { return ' '; }
        void popFront() { assert(false); }
        @property EmptyStream save() { return this; }
    }

    void test(T)()
    {
        T t;
        auto str = parseJSONStream!(LexOptions.noThrow, createAppender)(t);
        while (!str.empty) {
            auto f = str.front;
            str.popFront();
        }
    }
    // just instantiate, don't run
    auto t1 = &test!string;
    auto t2 = &test!wstring;
    auto t3 = &test!dstring;
    auto t4 = &test!EmptyStream;
}


/**
 * Lazy input range of JSON parser nodes.
 *
 * See $(D parseJSONStream) for more information.
 */
struct JSONParserRange(Input)
    if (isJSONTokenInputRange!Input)
{
    import stdx.data.json.foundation;

    private {
        Input _input;
        JSONToken.Kind[] _containerStack;
        size_t _containerStackFill = 0;
        JSONParserNode.Kind _prevKind;
        JSONParserNode _node;
    }

    /**
     * Constructs a new parser range.
     */
    this(Input input)
    {
        _input = input;
    }

    /**
     * Determines of the range has been exhausted.
     */
    @property bool empty() { return _containerStackFill == 0 && _input.empty; }

    /**
     * Returns the current node from the stream.
     */
    @property ref const(JSONParserNode) front()
    {
        ensureFrontValid();
        return _node;
    }

    /**
     * Skips to the next node in the stream.
     */
    void popFront()
    {
        ensureFrontValid();
        _prevKind = _node.kind;
        _node.kind = JSONParserNode.Kind.none;
    }

    private void ensureFrontValid()
    {
        if (_node.kind == JSONParserNode.Kind.none)
        {
            readNext();
            assert(_node.kind != JSONParserNode.Kind.none);
        }
    }

    private void readNext()
    {
        if (_containerStackFill)
        {
            if (_containerStack[_containerStackFill-1] == JSONToken.Kind.objectStart)
                readNextInObject();
            else readNextInArray();
        }
        else readNextValue();
    }

    private void readNextInObject() @trusted
    {
        enforceJson(!_input.empty, "Missing closing '}'", _input.location);
        switch (_prevKind)
        {
            default: assert(false);
            case JSONParserNode.Kind.objectStart:
                if (_input.front.kind == JSONToken.Kind.objectEnd)
                {
                    _node.kind = JSONParserNode.Kind.objectEnd;
                    _containerStackFill--;
                }
                else
                {
                    enforceJson(_input.front.kind == JSONToken.Kind.string,
                        "Expected field name", _input.front.location);
                    _node.key = _input.front.string;
                }
                _input.popFront();
                break;
            case JSONParserNode.Kind.key:
                enforceJson(_input.front.kind == JSONToken.Kind.colon,
                    "Expected ':'", _input.front.location);
                _input.popFront();
                readNextValue();
                break;
            case JSONParserNode.Kind.literal, JSONParserNode.Kind.objectEnd, JSONParserNode.Kind.arrayEnd:
                if (_input.front.kind == JSONToken.Kind.objectEnd)
                {
                    _node.kind = JSONParserNode.Kind.objectEnd;
                    _containerStackFill--;
                }
                else
                {
                    enforceJson(_input.front.kind == JSONToken.Kind.comma,
                        "Expected ',' or '}'", _input.front.location);
                    _input.popFront();
                    enforceJson(!_input.empty && _input.front.kind == JSONToken.Kind.string,
                        "Expected field name", _input.front.location);
                    _node.key = _input.front.string;
                }
                _input.popFront();
                break;
        }
    }

    private void readNextInArray()
    {
        enforceJson(!_input.empty, "Missing closing ']'", _input.location);
        switch (_prevKind)
        {
            default: assert(false);
            case JSONParserNode.Kind.arrayStart:
                if (_input.front.kind == JSONToken.Kind.arrayEnd)
                {
                    _node.kind = JSONParserNode.Kind.arrayEnd;
                    _containerStackFill--;
                    _input.popFront();
                }
                else
                {
                    readNextValue();
                }
                break;
            case JSONParserNode.Kind.literal, JSONParserNode.Kind.objectEnd, JSONParserNode.Kind.arrayEnd:
                if (_input.front.kind == JSONToken.Kind.arrayEnd)
                {
                    _node.kind = JSONParserNode.Kind.arrayEnd;
                    _containerStackFill--;
                    _input.popFront();
                }
                else
                {
                    enforceJson(_input.front.kind == JSONToken.Kind.comma,
                        "Expected ',' or ']'", _input.front.location);
                    _input.popFront();
                    enforceJson(!_input.empty, "Missing closing ']'", _input.location);
                    readNextValue();
                }
                break;
        }
    }

    private void readNextValue()
    {
        switch (_input.front.kind)
        {
            default:
                throw new JSONException("Expected JSON value", _input.location);
            case JSONToken.Kind.none: assert(false);
            case JSONToken.Kind.null_, JSONToken.Kind.boolean,
                    JSONToken.Kind.number, JSONToken.Kind.string:
                _node.literal = _input.front;
                _input.popFront();
                break;
            case JSONToken.Kind.objectStart:
                _node.kind = JSONParserNode.Kind.objectStart;
                pushContainer(JSONToken.Kind.objectStart);
                _input.popFront();
                break;
            case JSONToken.Kind.arrayStart:
                _node.kind = JSONParserNode.Kind.arrayStart;
                pushContainer(JSONToken.Kind.arrayStart);
                _input.popFront();
                break;
        }
    }

    private void pushContainer(JSONToken.Kind kind)
    {
        import std.algorithm/*.comparison*/ : max;
        if (_containerStackFill >= _containerStack.length)
            _containerStack.length = max(32, _containerStack.length*3/2);
        _containerStack[_containerStackFill++] = kind;
    }
}


/**
 * Represents a single node of a JSON parse tree.
 *
 * See $(D parseJSONStream) and $(D JSONParserRange) more information.
 */
struct JSONParserNode
{
    @safe:
    import std.algorithm/*.comparison*/ : among;
    import stdx.data.json.foundation : Location;

    /**
     * Determines the kind of a parser node.
     */
    enum Kind
    {
        none,        /// Used internally, never occurs in a node stream
        key,         /// An object key
        literal,     /// A literal value ($(D null), $(D boolean), $(D number) or $(D string))
        objectStart, /// The start of an object value
        objectEnd,   /// The end of an object value
        arrayStart,  /// The start of an array value
        arrayEnd,    /// The end of an array value
    }

    private
    {
        Kind _kind = Kind.none;
        union
        {
            string _key;
            JSONToken _literal;
        }
    }

    /**
     * The kind of this node.
     */
    @property Kind kind() const nothrow { return _kind; }
    /// ditto
    @property Kind kind(Kind value) nothrow
        in { assert(!value.among(Kind.key, Kind.literal)); }
        body { return _kind = value; }

    /**
     * The key identifier for $(D Kind.key) nodes.
     *
     * Setting the key will automatically switch the node kind.
     */
    @property string key() const @trusted nothrow
    {
        assert(_kind == Kind.key);
        return _key;
    }
    /// ditto
    @property string key(string value) nothrow
    {
        _kind = Kind.key;
        return _key = value;
    }

    /**
     * The literal token for $(D Kind.literal) nodes.
     *
     * Setting the literal will automatically switch the node kind.
     */
    @property ref inout(JSONToken) literal() inout @trusted nothrow
    {
        assert(_kind == Kind.literal);
        return _literal;
    }
    /// ditto
    @property ref JSONToken literal(JSONToken literal) nothrow
    {
        _kind = Kind.literal;
        return _literal = literal;
    }

    @property Location location()
    const @trusted nothrow {
        if (_kind == Kind.literal) return _literal.location;
        return Location.init;
    }

    /**
     * Enables equality comparisons.
     *
     * Note that the location is considered part of the token and thus is
     * included in the comparison.
     */
    bool opEquals(in ref JSONParserNode other)
    const nothrow
    {
        if (this.kind != other.kind) return false;

        switch (this.kind)
        {
            default: return true;
            case Kind.literal: return this.literal == other.literal;
            case Kind.key: return this.key == other.key;
        }
    }
    /// ditto
    bool opEquals(JSONParserNode other) const nothrow { return opEquals(other); }

    unittest
    {
        JSONToken t1, t2, t3;
        t1.string = "test";
        t2.string = "test".idup;
        t3.string = "other";

        JSONParserNode n1, n2;
        n2.literal = t1; assert(n1 != n2);
        n1.literal = t1; assert(n1 == n2);
        n1.literal = t3; assert(n1 != n2);
        n1.literal = t2; assert(n1 == n2);
        n1.kind = Kind.objectStart; assert(n1 != n2);
        n1.key = "test"; assert(n1 != n2);
        n2.key = "other"; assert(n1 != n2);
        n2.key = "test".idup; assert(n1 == n2);
    }

    /**
     * Enables usage of $(D JSONToken) as an associative array key.
     */
    size_t toHash() const nothrow @trusted
    {
        hash_t ret = 723125331 + cast(int)_kind * 3962627;

        switch (_kind)
        {
            default: return ret;
            case Kind.literal: return ret + _literal.toHash();
            case Kind.key: return ret + typeid(.string).getHash(&_key);
        }
    }

    /**
     * Converts the node to a string representation.
     *
     * Note that this representation is NOT the JSON representation, but rather
     * a representation suitable for printing out a node.
     */
    string toString() const
    {
        import std.string;
        switch (this.kind)
        {
            default: return format("%s", this.kind);
            case Kind.key: return format("[key \"%s\"]", this.key);
            case Kind.literal: return literal.toString();
        }
    }
}


/// Tests if a given type is an input range of $(D JSONToken).
enum isJSONTokenInputRange(R) = isInputRange!R && is(typeof(R.init.front) : JSONToken);

static assert(isJSONTokenInputRange!(JSONLexerRange!string));

/// Tests if a given type is an input range of $(D JSONParserNode).
enum isJSONParserNodeInputRange(R) = isInputRange!R && is(typeof(R.init.front) : JSONParserNode);

static assert(isJSONParserNodeInputRange!(JSONParserRange!(JSONLexerRange!string)));

// Workaround for https://issues.dlang.org/show_bug.cgi?id=14425
private alias Workaround_14425 = JSONParserRange!(JSONLexerRange!string);


/**
 * Skips a single JSON value in a parser stream.
 *
 * The value pointed to by `nodes.front` will be skipped. All JSON types will
 * be skipped, which means in particular that arrays and objects will be
 * skipped recursively.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 */
void skipValue(R)(ref R nodes) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", nodes.front.literal.location);

    auto k = nodes.front.kind;
    nodes.popFront();

    with (JSONParserNode.Kind) {
        if (k != arrayStart && k != objectStart) return;

        int depth = 1;
        while (!nodes.empty) {
            k = nodes.front.kind;
            nodes.popFront();
            if (k == arrayStart || k == objectStart) depth++;
            else if (k == arrayEnd || k == objectEnd) {
                if (--depth == 0) break;
            }
        }
    }
}

///
unittest
{
    auto j = parseJSONStream(q{
            [
                [1, 2, 3],
                "foo"
            ]
        });

    assert(j.front.kind == JSONParserNode.Kind.arrayStart);
    j.popFront();
    
    // skips the whole [1, 2, 3] array
    j.skipValue();

    string value = j.readString;
    assert(value == "foo");

    assert(j.front.kind == JSONParserNode.Kind.arrayEnd);
    j.popFront();

    assert(j.empty);
}


/**
 * Skips all entries in an object until a certain key is reached.
 *
 * The node range must either point to the start of an object
 * (`JSONParserNode.Kind.objectStart`), or to a key within an object
 * (`JSONParserNode.Kind.key`).
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *   key = Name of the key to find
 *
 * Returns:
 *   `true` is returned if and only if the specified key has been found.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 */
bool skipToKey(R)(ref R nodes, string key) if (isJSONParserNodeInputRange!R)
{
    import std.algorithm/*.comparison*/ : among;
    import stdx.data.json.foundation;

    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind.among!(JSONParserNode.Kind.objectStart, JSONParserNode.Kind.key) > 0,
        "Expected object or object key", nodes.front.location);

    if (nodes.front.kind == JSONParserNode.Kind.objectStart)
        nodes.popFront();

    while (true) {
        auto k = nodes.front.kind;
        if (k == JSONParserNode.Kind.objectEnd) {
            nodes.popFront();
            return false;
        }

        assert(k == JSONParserNode.Kind.key);
        if (nodes.front.key == key) {
            nodes.popFront();
            return true;
        }

        nodes.popFront();

        nodes.skipValue();
    }
}

///
unittest
{
    auto j = parseJSONStream(q{
            {
                "foo": 2,
                "bar": 3,
                "baz": false,
                "qux": "str"
            }
        });

    j.skipToKey("bar");
    double v1 = j.readDouble;
    assert(v1 == 3);

    j.skipToKey("qux");
    string v2 = j.readString;
    assert(v2 == "str");

    assert(j.front.kind == JSONParserNode.Kind.objectEnd);
    j.popFront();

    assert(j.empty);
}


/**
 * Reads an array and issues a callback for each entry.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *   del = The callback to invoke for each array entry
 */
void readArray(R)(ref R nodes, scope void delegate() @safe del) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNode.Kind.arrayStart,
        "Expected array", nodes.front.literal.location);
    nodes.popFront();

    while (true) {
        auto k = nodes.front.kind;
        if (k == JSONParserNode.Kind.arrayEnd) {
          nodes.popFront();
          return;
        }
        del();
    }
}

///
unittest
{
    auto j = parseJSONStream(q{
            [
                "foo",
                "bar"
            ]
        });

    size_t i = 0;
    j.readArray({
        auto value = j.readString();
        switch (i++) {
            default: assert(false);
            case 0: assert(value == "foo"); break;
            case 1: assert(value == "bar"); break;
        }
    });

    assert(j.empty);
}


/**
 * Reads an object and issues a callback for each field.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *   del = The callback to invoke for each object field
 */
void readObject(R)(ref R nodes, scope void delegate(string key) @safe del) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNode.Kind.objectStart,
        "Expected object", nodes.front.literal.location);
    nodes.popFront();

    while (true) {
        auto k = nodes.front.kind;
        if (k == JSONParserNode.Kind.objectEnd) {
          nodes.popFront();
          return;
        }
        auto key = nodes.front.key;
        nodes.popFront();
        del(key);
    }
}

///
unittest
{
    auto j = parseJSONStream(q{
            {
                "foo": 1,
                "bar": 2
            }
        });

    j.readObject((key) {
        auto value = j.readDouble;
        switch (key) {
            default: assert(false);
            case "foo": assert(value == 1); break;
            case "bar": assert(value == 2); break;
        }
    });

    assert(j.empty);
}


/**
 * Reads a single double value.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *
 * Throws: Throws a `JSONException` is the node range is empty or `nodes.front` is not a number.
 */
double readDouble(R)(ref R nodes) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNode.Kind.literal
        && nodes.front.literal.kind == JSONToken.Kind.number,
        "Expected numeric value", nodes.front.literal.location);
    double ret = nodes.front.literal.number;
    nodes.popFront();
    return ret;
}

///
unittest
{
    auto j = parseJSONStream(`1.0`);
    double value = j.readDouble;
    assert(value == 1.0);
    assert(j.empty);
}


/**
 * Reads a single double value.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *
 * Throws: Throws a `JSONException` is the node range is empty or `nodes.front` is not a string.
 */
string readString(R)(ref R nodes) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNode.Kind.literal
        && nodes.front.literal.kind == JSONToken.Kind.string,
        "Expected string value", nodes.front.literal.location);
    string ret = nodes.front.literal.string;
    nodes.popFront();
    return ret;
}

///
unittest
{
    auto j = parseJSONStream(`"foo"`);
    string value = j.readString;
    assert(value == "foo");
    assert(j.empty);
}


/**
 * Reads a single double value.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *
 * Throws: Throws a `JSONException` is the node range is empty or `nodes.front` is not a boolean.
 */
bool readBool(R)(ref R nodes) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNode.Kind.literal
        && nodes.front.literal.kind == JSONToken.Kind.boolean,
        "Expected boolean value", nodes.front.literal.location);
    bool ret = nodes.front.literal.boolean;
    nodes.popFront();
    return ret;
}

///
unittest
{
    auto j = parseJSONStream(`true`);
    bool value = j.readBool;
    assert(value == true);
    assert(j.empty);
}
