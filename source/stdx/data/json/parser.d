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

import stdx.data.json.lexer;
import stdx.data.json.value;
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
JSONValue toJSONValue(bool track_location = true, Input)(Input input, string filename = "")
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    auto tokens = lexJSON!track_location(input, filename);
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
unittest {
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

unittest {
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
JSONValue parseJSONValue(bool track_location = true, Input)(ref Input input, string filename = "")
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    import stdx.data.json.foundation;

    auto tokens = lexJSON!track_location(input, filename);
    auto ret = parseJSONValue(tokens);
    input = tokens.input;
    return ret;
}

/// Parse an object
unittest {
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
unittest {
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

    final switch (tokens.front.kind) with (JSONToken.Kind) {
        case invalid: assert(false);
        case null_: ret = JSONValue(null); break;
        case boolean: ret = JSONValue(tokens.front.boolean); break;
        case number: ret = JSONValue(tokens.front.number); break;
        case string: ret = JSONValue(tokens.front.string); break;
        case objectStart:
            auto loc = tokens.front.location;
            bool first = true;
            JSONValue[.string] obj;
            tokens.popFront();
            while (true) {
                enforceJson(!tokens.empty, "Missing closing '}'", loc);
                if (tokens.front.kind == objectEnd) break;

                if (!first) {
                    enforceJson(tokens.front.kind == comma, "Expected ',' or '}'", tokens.front.location);
                    tokens.popFront();
                    enforceJson(!tokens.empty, "Expected field name", tokens.location);
                } else first = false;

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
            while (true) {
                enforceJson(!tokens.empty, "Missing closing ']'", loc);
                if (tokens.front.kind == arrayEnd) break;

                if (!first) {
                    enforceJson(tokens.front.kind == comma, "Expected ',' or ']'", tokens.front.location);
                    tokens.popFront();
                } else first = false;

                array ~= parseJSONValue(tokens);
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
unittest {
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

unittest {
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
JSONParserRange!(JSONLexerRange!(Input, track_location)) parseJSONStream(bool track_location = true, Input)(Input input, string filename = null)
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    return parseJSONStream(lexJSON(input, filename));
}
/// ditto
JSONParserRange!Input parseJSONStream(Input)(Input tokens)
    if (isJSONTokenInputRange!Input)
{
    return JSONParserRange!Input(tokens);
}

///
unittest {
    import std.algorithm;

    auto rng1 = parseJSONStream(`{ "a": 1, "b": [null] }`);
    with (JSONParserNode.Kind) {
        assert(rng1.map!(n => n.kind).equal(
            [objectStart, key, literal, key, arrayStart, literal, arrayEnd,
            objectEnd]));
    }

    auto rng2 = parseJSONStream(`1 {"a": 2} null`);
    with (JSONParserNode.Kind) {
        assert(rng2.map!(n => n.kind).equal(
            [literal, objectStart, key, literal, objectEnd, literal]));
    }
}

unittest {
    auto rng = parseJSONStream(`{"a": 1, "b": [null, true], "c": {"d": {}}}`);
    with (JSONParserNode.Kind) {
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

    rng = parseJSONStream(`[]`);
    with (JSONParserNode.Kind) {
        import std.algorithm;
        assert(rng.map!(n => n.kind).equal([arrayStart, arrayEnd]));
    }
}

unittest {
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
        if (_node.kind == JSONParserNode.Kind.invalid) {
            readNext();
            assert(_node.kind != JSONParserNode.Kind.invalid);
        }

        return _node;
    }

    /**
     * Skips to the next node in the stream.
     */
    void popFront()
    {
        if (_node.kind == JSONParserNode.Kind.invalid) {
            readNext();
            assert(_node.kind != JSONParserNode.Kind.invalid);
        }

        _prevKind = _node.kind;
        _node.kind = JSONParserNode.Kind.invalid;
    }

    private void readNext()
    {
        if (_containerStackFill) {
            if (_containerStack[_containerStackFill-1] == JSONToken.Kind.objectStart)
                readNextInObject();
            else readNextInArray();
        } else readNextValue();
    }

    private void readNextInObject()
    {
        enforceJson(!_input.empty, "Missing closing '}'", _input.location);
        switch (_prevKind) {
            default: assert(false);
            case JSONParserNode.Kind.objectStart:
                if (_input.front.kind == JSONToken.Kind.objectEnd) {
                    _node.kind = JSONParserNode.Kind.objectEnd;
                    _containerStackFill--;
                } else {
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
                if (_input.front.kind == JSONToken.Kind.objectEnd) {
                    _node.kind = JSONParserNode.Kind.objectEnd;
                    _containerStackFill--;
                } else {
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
        switch (_prevKind) {
            default: assert(false);
            case JSONParserNode.Kind.arrayStart:
                if (_input.front.kind == JSONToken.Kind.arrayEnd) {
                    _node.kind = JSONParserNode.Kind.arrayEnd;
                    _containerStackFill--;
                    _input.popFront();
                } else {
                    readNextValue();
                }
                break;
            case JSONParserNode.Kind.literal, JSONParserNode.Kind.objectEnd, JSONParserNode.Kind.arrayEnd:
                if (_input.front.kind == JSONToken.Kind.arrayEnd) {
                    _node.kind = JSONParserNode.Kind.arrayEnd;
                    _containerStackFill--;
                    _input.popFront();
                } else {
                    enforceJson(_input.front.kind == JSONToken.Kind.comma,
                        "Expected ',' or ']'", _input.front.location);
                    _input.popFront();
                    enforceJson(!_input.empty, "Missing closing ']'", _input.location);
                    readNextValue();
                }
                break;
        }
    }

    void readNextValue()
    {
        void pushContainer(JSONToken.Kind kind) {
            if (_containerStackFill >= _containerStack.length)
                _containerStack.length++;
            _containerStack[_containerStackFill++] = kind;
        }

        switch (_input.front.kind) {
            default:
                throw new JSONException("Expected JSON value", _input.location);
            case JSONToken.Kind.invalid: assert(false);
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
}


/**
 * Represents a single node of a JSON parse tree.
 *
 * See $(D parseJSONStream) and $(D JSONParserRange) more information.
 */
struct JSONParserNode {
    import std.algorithm : among;

    /**
     * Determines the kind of a parser node.
     */
    enum Kind {
        invalid,     /// Used internally
        key,         /// An object key
        literal,     /// A literal value ($(D null), $(D boolean), $(D number) or $(D string))
        objectStart, /// The start of an object value
        objectEnd,   /// The end of an object value
        arrayStart,  /// The start of an array value
        arrayEnd,    /// The end of an array value
    }

    private {
        Kind _kind = Kind.invalid;
        union {
            string _key;
            JSONToken _literal;
        }
    }

    /**
     * The kind of this node.
     */
    @property Kind kind() const { return _kind; }
    /// ditto
    @property Kind kind(Kind value)
        in { assert(!value.among(Kind.key, Kind.literal)); }
        body { return _kind = value; }

    /**
     * The key identifier for $(D Kind.key) nodes.
     *
     * Setting the key will automatically switch the node kind.
     */
    @property string key()
    const {
        assert(_kind == Kind.key);
        return _key;
    }
    /// ditto
    @property string key(string value)
    {
        _kind = Kind.key;
        return _key = value;
    }

    /**
     * The literal token for $(D Kind.literal) nodes.
     *
     * Setting the literal will automatically switch the node kind.
     */
    @property ref inout(JSONToken) literal()
    inout {
        assert(_kind == Kind.literal);
        return _literal;
    }
    /// ditto
    @property ref JSONToken literal(JSONToken literal)
    {
        _kind = Kind.literal;
        return _literal = literal;
    }

    /**
     * Enables equality comparisons.
     *
     * Note that the location is considered part of the token and thus is
     * included in the comparison.
     */
    bool opEquals(in ref JSONParserNode other)
    const {
        if (this.kind != other.kind) return false;

        switch (this.kind) {
            default: return true;
            case Kind.literal: return this.literal == other.literal;
            case Kind.key: return this.key == other.key;
        }
    }
    /// ditto
    bool opEquals(JSONParserNode other) const { return opEquals(other); }

    unittest {
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
     * Converts the node to a string representation.
     *
     * Note that this representation is NOT the JSON representation, but rather
     * a representation suitable for printing out a node.
     */
    string toString()
    const {
        import std.string;
        switch (this.kind) {
            default: return format("%s", this.kind);
            case Kind.key: return format("[key \"%s\"]", this.key);
            case Kind.literal: return literal.toString();
        }
    }
}


/// Tests if a given type is an input range of $(D JSONToken).
enum isJSONTokenInputRange(R) = isInputRange!R && is(typeof(R.init.front) : JSONToken);

static assert(isJSONTokenInputRange!(JSONLexerRange!(string, true)));

/// Tests if a given type is an input range of $(D JSONParserNode).
enum isJSONParserNodeInputRange(R) = isInputRange!R && is(typeof(R.init.front) : JSONParserNode);

static assert(isJSONParserNodeInputRange!(JSONParserRange!(JSONLexerRange!(string, true))));
