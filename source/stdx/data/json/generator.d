/**
 * Contains routines for converting JSON values to their string represencation.
 *
 * Synopsis:
 * ---
 * ...
 * ---
 *
 * Copyright: Copyright 2012 - 2015, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/generator.d)
 */
module stdx.data.json.generator;

import stdx.data.json.lexer;
import stdx.data.json.parser;
import stdx.data.json.value;
import std.bigint;
import std.range;


/**
 * Converts the given JSON document(s) to its string representation.
 *
 * The input can be a $(D JSONValue), or an input range of either $(D JSONToken)
 * or $(D JSONParserNode) elements. By default, the generator will use newlines
 * and tabs to pretty-print the result. Use the `options` template parameter
 * to customize this.
 *
 * Params:
 *   value = A single JSON document
 *   nodes = A set of JSON documents encoded as single parser nodes. The nodes
 *     must be in valid document order, or the parser result will be undefined.
 *   tokens = List of JSON tokens to be converted to strings. The tokens may
 *     occur in any order and are simply appended in order to the final string.
 *   token = A single token to convert to a string
 *
 * Returns:
 *   Returns a JSON formatted string.
 *
 * See_also: $(D writeJSON), $(D toPrettyJSON)
 */
string toJSON(GeneratorOptions options = GeneratorOptions.init)(JSONValue value)
{
    import std.array;
    auto dst = appender!string();
    value.writeJSON!options(dst);
    return dst.data;
}
/// ditto
string toJSON(GeneratorOptions options = GeneratorOptions.init, Input)(Input nodes)
    if (isJSONParserNodeInputRange!Input)
{
    import std.array;
    auto dst = appender!string();
    nodes.writeJSON!options(dst);
    return dst.data;
}
/// ditto
string toJSON(GeneratorOptions options = GeneratorOptions.init, Input)(Input tokens)
    if (isJSONTokenInputRange!Input)
{
    import std.array;
    auto dst = appender!string();
    tokens.writeJSON!options(dst);
    return dst.data;
}
/// ditto
string toJSON(GeneratorOptions options = GeneratorOptions.init, String)(JSONToken!String token)
{
    import std.array;
    auto dst = appender!string();
    token.writeJSON!options(dst);
    return dst.data;
}

///
@safe unittest
{
    JSONValue value = true;
    assert(value.toJSON() == "true");
}

///
@safe unittest
{
    auto a = toJSONValue(`{"a": [], "b": [1, {}]}`);

    // pretty print:
    // {
    //     "a": [],
    //     "b": [
    //         1,
    //         {},
    //     ]
    // }
    assert(
        a.toJSON() == "{\n\t\"a\": [],\n\t\"b\": [\n\t\t1,\n\t\t{}\n\t]\n}" ||
        a.toJSON() == "{\n\t\"b\": [\n\t\t1,\n\t\t{}\n\t],\n\t\"a\": []\n}"
    );

    // write compact JSON (order of object fields is undefined)
    assert(
        a.toJSON!(GeneratorOptions.compact)() == `{"a":[],"b":[1,{}]}` ||
        a.toJSON!(GeneratorOptions.compact)() == `{"b":[1,{}],"a":[]}`
    );
}

@safe unittest
{
    auto nodes = parseJSONStream(`{"a": [], "b": [1, {}]}`);
    assert(nodes.toJSON() == "{\n\t\"a\": [],\n\t\"b\": [\n\t\t1,\n\t\t{}\n\t]\n}");
    assert(nodes.toJSON!(GeneratorOptions.compact)() == `{"a":[],"b":[1,{}]}`);

    auto tokens = lexJSON(`{"a": [], "b": [1, {}, null, true, false]}`);
    assert(tokens.toJSON!(GeneratorOptions.compact)() == `{"a":[],"b":[1,{},null,true,false]}`);

    JSONToken!string tok;
    tok.string = "Hello World";
    assert(tok.toJSON() == `"Hello World"`);
}


/**
 * Writes the string representation of the given JSON document(s)/tokens to an
 * output range.
 *
 * See $(D toJSON) for more information.
 *
 * Params:
 *   output = The output range to take the result string in UTF-8 encoding.
 *   value = A single JSON document
 *   nodes = A set of JSON documents encoded as single parser nodes. The nodes
 *     must be in valid document order, or the parser result will be undefined.
 *   tokens = List of JSON tokens to be converted to strings. The tokens may
 *     occur in any order and are simply appended in order to the final string.
 *   token = A single token to convert to a string
 *
 * See_also: $(D toJSON), $(D writePrettyJSON)
 */
void writeJSON(GeneratorOptions options = GeneratorOptions.init, Output)(JSONValue value, ref Output output)
    if (isOutputRange!(Output, char))
{
    writeAsStringImpl!options(value, output);
}
/// ditto
void writeJSON(GeneratorOptions options = GeneratorOptions.init, Output, Input)(Input nodes, ref Output output)
    if (isOutputRange!(Output, char) && isJSONParserNodeInputRange!Input)
{
    //import std.algorithm.mutation : copy;
    auto joutput = JSONOutputRange!(Output, options)(output);
    foreach (n; nodes) joutput.put(n);
    //copy(nodes, joutput);
}
/// ditto
void writeJSON(GeneratorOptions options = GeneratorOptions.init, Output, Input)(Input tokens, ref Output output)
    if (isOutputRange!(Output, char) && isJSONTokenInputRange!Input)
{
    while (!tokens.empty)
    {
        tokens.front.writeJSON!options(output);
        tokens.popFront();
    }
}
/// ditto
void writeJSON(GeneratorOptions options = GeneratorOptions.init, String, Output)(const ref JSONToken!String token, ref Output output)
    if (isOutputRange!(Output, char))
{
    final switch (token.kind) with (JSONTokenKind)
    {
        case none: assert(false);
        case error: output.put("_error_"); break;
        case null_: output.put("null"); break;
        case boolean: output.put(token.boolean ? "true" : "false"); break;
        case number: output.writeNumber!options(token.number); break;
        case string: output.put('"'); output.escapeString!(options & GeneratorOptions.escapeUnicode)(token.string); output.put('"'); break;
        case objectStart: output.put('{'); break;
        case objectEnd: output.put('}'); break;
        case arrayStart: output.put('['); break;
        case arrayEnd: output.put(']'); break;
        case colon: output.put(':'); break;
        case comma: output.put(','); break;
    }
}

/** Convenience function for creating a `JSONOutputRange` instance using IFTI.
*/
JSONOutputRange!(R, options) jsonOutputRange(GeneratorOptions options = GeneratorOptions.init, R)(R output)
    if (isOutputRange!(R, char))
{
    return JSONOutputRange!(R, options)(output);
}

/** Output range that takes JSON primitives and outputs to a character output
    range.

    This range provides the underlying functinality for `writeJSON` and
    `toJSON` and is well suited as a target for serialization frameworks.

    Note that pretty-printing (`GeneratorOptions.compact` not set) is currently
    only supported for primitives of type `JSONParserNode`.
*/
struct JSONOutputRange(R, GeneratorOptions options = GeneratorOptions.init)
    if (isOutputRange!(R, char))
{
    private {
        R m_output;
        size_t m_nesting = 0;
        bool m_first = false;
        bool m_isObjectField = false;
    }

    /** Constructs the range for a given character output range.
    */
    this(R output)
    {
        m_output = output;
    }

    /** Writes a single JSON primitive to the destination character range.
    */
    void put(String)(JSONParserNode!String node)
    {
        enum pretty_print = (options & GeneratorOptions.compact) == 0;

        final switch (node.kind) with (JSONParserNodeKind) {
            case none: assert(false);
            case key:
                if (m_nesting > 0 && !m_first) m_output.put(',');
                else m_first = false;
                m_isObjectField = true;
                static if (pretty_print) indent();
                m_output.put('"');
                m_output.escapeString!(options & GeneratorOptions.escapeUnicode)(node.key);
                m_output.put(pretty_print ? `": ` : `":`);
                break;
            case literal:
                preValue();
                node.literal.writeJSON!options(m_output);
                break;
            case objectStart:
                preValue();
                m_output.put('{');
                m_nesting++;
                m_first = true;
                break;
            case objectEnd:
                m_nesting--;
                static if (pretty_print)
                {
                    if (!m_first) indent();
                }
                m_first = false;
                m_output.put('}');
                break;
            case arrayStart:
                preValue();
                m_output.put('[');
                m_nesting++;
                m_first = true;
                m_isObjectField = false;
                break;
            case arrayEnd:
                m_nesting--;
                static if (pretty_print)
                {
                    if (!m_first) indent();
                }
                m_first = false;
                m_output.put(']');
                break;
        }
    }
    /// ditto
    void put(String)(JSONToken!String token)
    {
        final switch (token.kind) with (JSONToken.Kind) {
            case none: assert(false);
            case error: m_output.put("_error_"); break;
            case null_: put(null); break;
            case boolean: put(token.boolean); break;
            case number: put(token.number); break;
            case string: put(token.string); break;
            case objectStart: m_output.put('{'); break;
            case objectEnd: m_output.put('}'); break;
            case arrayStart: m_output.put('['); break;
            case arrayEnd: m_output.put(']'); break;
            case colon: m_output.put(':'); break;
            case comma: m_output.put(','); break;
        }
    }
    /// ditto
    void put(typeof(null)) { m_output.put("null"); }
    /// ditto
    void put(bool value) { m_output.put(value ? "true" : "false"); }
    /// ditto
    void put(long value) { m_output.writeNumber(value); }
    /// ditto
    void put(BigInt value) { m_output.writeNumber(value); }
    /// ditto
    void put(double value) { m_output.writeNumber!options(value); }
    /// ditto
    void put(String)(JSONString!String value)
    {
        auto s = value.anyValue;
        if (s[0]) put(s[1]); // decoded string
        else m_output.put(s[1]); // raw string literal
    }
    /// ditto
    void put(string value)
    {
        m_output.put('"');
        m_output.escapeString!(options & GeneratorOptions.escapeUnicode)(value);
        m_output.put('"');
    }

    private void indent()
    {
        m_output.put('\n');
        foreach (tab; 0 .. m_nesting) m_output.put('\t');
    }

    private void preValue()
    {
        if (!m_isObjectField)
        {
            if (m_nesting > 0 && !m_first) m_output.put(',');
            else m_first = false;
            static if (!(options & GeneratorOptions.compact))
            {
                if (m_nesting > 0) indent();
            }
        }
        else m_isObjectField = false;
    }
}

@safe unittest {
    auto app = appender!(char[]);
    auto dst = jsonOutputRange(app);
    dst.put(true);
    dst.put(1234);
    dst.put("hello");
    assert(app.data == "true1234\"hello\"");
}

@safe unittest {
    auto app = appender!(char[]);
    auto dst = jsonOutputRange(app);
    foreach (n; parseJSONStream(`{"foo":42, "bar":true, "baz": [null, false]}`))
        dst.put(n);
    assert(app.data == "{\n\t\"foo\": 42,\n\t\"bar\": true,\n\t\"baz\": [\n\t\tnull,\n\t\tfalse\n\t]\n}");
}


/**
 * Flags for configuring the JSON generator.
 *
 * These flags can be combined using a bitwise or operation.
 */
enum GeneratorOptions {
	/// Default value - enable none of the supported options
    init = 0,

    /// Avoid outputting whitespace to get a compact string representation
    compact = 1<<0,

	/// Output special float values as 'NaN' or 'Infinity' instead of 'null'
    specialFloatLiterals = 1<<1,

	/// Output all non-ASCII characters as unicode escape sequences
    escapeUnicode = 1<<2,
}


@safe private void writeAsStringImpl(GeneratorOptions options, Output)(JSONValue value, ref Output output, size_t nesting_level = 0)
    if (isOutputRange!(Output, char))
{
    import stdx.data.json.taggedalgebraic : get;

    enum pretty_print = (options & GeneratorOptions.compact) == 0;

    void indent(size_t depth)
    {
        output.put('\n');
        foreach (tab; 0 .. depth) output.put('\t');
    }

    final switch (value.kind) {
        case JSONValue.Kind.null_: output.put("null"); break;
        case JSONValue.Kind.boolean: output.put(value == true ? "true" : "false"); break;
        case JSONValue.Kind.double_: output.writeNumber!options(cast(double)value); break;
        case JSONValue.Kind.integer: output.writeNumber(cast(long)value); break;
        case JSONValue.Kind.bigInt: () @trusted {
            auto val = cast(BigInt*)value;
            if (val is null) throw new Exception("Null BigInt value");
            output.writeNumber(*val);
            }(); break;
        case JSONValue.Kind.string: output.put('"'); output.escapeString!(options & GeneratorOptions.escapeUnicode)(get!string(value)); output.put('"'); break;
        case JSONValue.Kind.object:
            output.put('{');
            bool first = true;
            foreach (string k, ref e; get!(JSONValue[string])(value))
            {
                if (!first) output.put(',');
                else first = false;
                static if (pretty_print) indent(nesting_level+1);
                output.put('\"');
                output.escapeString!(options & GeneratorOptions.escapeUnicode)(k);
                output.put(pretty_print ? `": ` : `":`);
                e.writeAsStringImpl!options(output, nesting_level+1);
            }
            static if (pretty_print)
            {
                if (!first) indent(nesting_level);
            }
            output.put('}');
            break;
        case JSONValue.Kind.array:
            output.put('[');
            foreach (i, ref e; get!(JSONValue[])(value))
            {
                if (i > 0) output.put(',');
                static if (pretty_print) indent(nesting_level+1);
                e.writeAsStringImpl!options(output, nesting_level+1);
            }
            static if (pretty_print)
            {
                if (get!(JSONValue[])(value).length > 0) indent(nesting_level);
            }
            output.put(']');
            break;
    }
}

private void writeNumber(GeneratorOptions options, R)(ref R dst, JSONNumber num) @trusted
{
    import std.format;
    import std.math;

    final switch (num.type)
    {
        case JSONNumber.Type.double_: dst.writeNumber!options(num.doubleValue); break;
        case JSONNumber.Type.long_: dst.writeNumber(num.longValue); break;
        case JSONNumber.Type.bigInt: dst.writeNumber(num.bigIntValue); break;
    }
}

private void writeNumber(GeneratorOptions options, R)(ref R dst, double num) @trusted
{
    import std.format;
    import std.math;

    static if (options & GeneratorOptions.specialFloatLiterals)
    {
        if (isNaN(num)) dst.put("NaN");
        else if (num == +double.infinity) dst.put("Infinity");
        else if (num == -double.infinity) dst.put("-Infinity");
        else dst.formattedWrite("%.16g", num);
    }
    else
    {
        if (isNaN(num) || num == -double.infinity || num == double.infinity)
            dst.put("null");
        else dst.formattedWrite("%.16g", num);
    }
}

private void writeNumber(R)(ref R dst, long num) @trusted
{
    import std.format;
    dst.formattedWrite("%d", num);
}

private void writeNumber(R)(ref R dst, BigInt num) @trusted
{
    () @trusted { num.toString(str => dst.put(str), null); } ();
}

@safe unittest
{
    import std.math;
    import std.string;

    auto num = toJSONValue("-67.199307");
    auto exp = -67.199307;
    assert(num.get!double.approxEqual(exp));

    auto snum = appender!string;
    snum.writeNumber!(GeneratorOptions.init)(JSONNumber(num.get!double));
    auto pnum = toJSONValue(snum.data);
    assert(pnum.get!double.approxEqual(num.get!double));
}

@safe unittest // special float values
{
    static void test(GeneratorOptions options = GeneratorOptions.init)(double val, string expected)
    {
        auto dst = appender!string;
        dst.writeNumber!options(val);
        assert(dst.data == expected);
    }

    test(double.nan, "null");
    test(double.infinity, "null");
    test(-double.infinity, "null");
    test!(GeneratorOptions.specialFloatLiterals)(double.nan, "NaN");
    test!(GeneratorOptions.specialFloatLiterals)(double.infinity, "Infinity");
    test!(GeneratorOptions.specialFloatLiterals)(-double.infinity, "-Infinity");
}

private void escapeString(bool use_surrogates = false, R)(ref R dst, string s)
{
    import std.format;
    import std.utf : decode;

    for (size_t pos = 0; pos < s.length; pos++)
    {
        immutable ch = s[pos];

        switch (ch)
        {
            case '\\': dst.put(`\\`); break;
            case '\b': dst.put(`\b`); break;
            case '\f': dst.put(`\f`); break;
            case '\r': dst.put(`\r`); break;
            case '\n': dst.put(`\n`); break;
            case '\t': dst.put(`\t`); break;
            case '\"': dst.put(`\"`); break;
            default:
                static if (use_surrogates)
                {
                    // output non-control char ASCII characters directly
                    // note that 0x7F is the DEL control charactor
                    if (ch >= 0x20 && ch < 0x7F)
                    {
                        dst.put(ch);
                        break;
                    }

                    dchar cp = decode(s, pos);
                    pos--; // account for the next loop increment

                    // encode as one or two UTF-16 code points
                    if (cp < 0x10000)
                    { // in BMP -> 1 CP
                        formattedWrite(dst, "\\u%04X", cp);
                    }
                    else
                    { // not in BMP -> surrogate pair
                        int first, last;
                        cp -= 0x10000;
                        first = 0xD800 | ((cp & 0xffc00) >> 10);
                        last = 0xDC00 | (cp & 0x003ff);
                        formattedWrite(dst, "\\u%04X\\u%04X", first, last);
                    }
                }
                else
                {
                    if (ch < 0x20 && ch != 0x7F) formattedWrite(dst, "\\u%04X", ch);
                    else dst.put(ch);
                }
                break;
        }
    }
}

@safe unittest
{
    static void test(bool surrog)(string str, string expected)
    {
        auto res = appender!string;
        res.escapeString!surrog(str);
        assert(res.data == expected, res.data);
    }

    test!false("hello", "hello");
    test!false("hällo", "hällo");
    test!false("a\U00010000b", "a\U00010000b");
    test!false("a\u1234b", "a\u1234b");
    test!false("\r\n\b\f\t\\\"", `\r\n\b\f\t\\\"`);
    test!true("hello", "hello");
    test!true("hällo", `h\u00E4llo`);
    test!true("a\U00010000b", `a\uD800\uDC00b`);
    test!true("a\u1234b", `a\u1234b`);
    test!true("\r\n\b\f\t\\\"", `\r\n\b\f\t\\\"`);
}
