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
string toJSON(GeneratorOptions options = GeneratorOptions.init)(JSONToken token)
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

    JSONToken tok;
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
    writeAsStringImpl!options(nodes, output);
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
void writeJSON(GeneratorOptions options = GeneratorOptions.init, Output)(in ref JSONToken token, ref Output output)
    if (isOutputRange!(Output, char))
{
    final switch (token.kind) with (JSONToken.Kind)
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
    import taggedalgebraic : get;

    enum pretty_print = (options & GeneratorOptions.compact) == 0;

    void indent(size_t depth)
    {
        output.put('\n');
        foreach (tab; 0 .. depth) output.put('\t');
    }

    final switch (value.typeID) {
        case JSONValue.Type.null_: output.put("null"); break;
        case JSONValue.Type.boolean: output.put(value == true ? "true" : "false"); break;
        case JSONValue.Type.double_: output.writeNumber!options(cast(double)value); break;
        case JSONValue.Type.integer: output.writeNumber(cast(long)value); break;
        case JSONValue.Type.bigInt: () @trusted {
            auto val = cast(BigInt*)value;
            if (val is null) throw new Exception("Null BigInt value");
            output.writeNumber(*val);
            }(); break;
        case JSONValue.Type.string: output.put('"'); output.escapeString!(options & GeneratorOptions.escapeUnicode)(get!string(value)); output.put('"'); break;
        case JSONValue.Type.object:
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
        case JSONValue.Type.array:
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

private void writeAsStringImpl(GeneratorOptions options, Output, Input)(Input nodes, ref Output output)
    if (isOutputRange!(Output, char) && isJSONParserNodeInputRange!Input)
{
    size_t nesting = 0;
    bool first = false;
    bool is_object_field = false;
    enum pretty_print = (options & GeneratorOptions.compact) == 0;

    void indent(size_t depth)
    {
        output.put('\n');
        foreach (tab; 0 .. depth) output.put('\t');
    }

    void preValue()
    {
        if (!is_object_field)
        {
            if (nesting > 0 && !first) output.put(',');
            else first = false;
            static if (pretty_print)
            {
                if (nesting > 0) indent(nesting);
            }
        }
        else is_object_field = false;
    }

    while (!nodes.empty)
    {
        final switch (nodes.front.kind) with (JSONParserNode.Kind)
        {
            case none: assert(false);
            case key:
                if (nesting > 0 && !first) output.put(',');
                else first = false;
                is_object_field = true;
                static if (pretty_print) indent(nesting);
                output.put('"');
                output.escapeString!(options & GeneratorOptions.escapeUnicode)(nodes.front.key);
                output.put(pretty_print ? `": ` : `":`);
                break;
            case literal:
                preValue();
                nodes.front.literal.writeJSON!options(output);
                break;
            case objectStart:
                preValue();
                output.put('{');
                nesting++;
                first = true;
                break;
            case objectEnd:
                nesting--;
                static if (pretty_print)
                {
                    if (!first) indent(nesting);
                }
                first = false;
                output.put('}');
                break;
            case arrayStart:
                preValue();
                output.put('[');
                nesting++;
                first = true;
                is_object_field = false;
                break;
            case arrayEnd:
                nesting--;
                static if (pretty_print)
                {
                    if (!first) indent(nesting);
                }
                first = false;
                output.put(']');
                break;
        }
        nodes.popFront();
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
