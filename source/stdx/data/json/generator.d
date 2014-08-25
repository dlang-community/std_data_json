/**
 * Contains routines for converting JSON values to their string represencation.
 *
 * Synopsis:
 * ---
 * ...
 * ---
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/generator.d)
 */
module stdx.data.json.generator;
@safe:

import stdx.data.json.lexer;
import stdx.data.json.parser;
import stdx.data.json.value;
import std.bigint;
import std.range;


/**
 * Converts the given JSON document(s) to a formatted string representation.
 *
 * Pretty printed strings are indented multi-line strings suitable for human
 * consumption.
 *
 * See_also: $(D writePrettyJSON), $(D toJSON)
 */
string toPrettyJSON(JSONValue value)
{
    import std.array;
    auto dst = appender!string();
    value.writePrettyJSON(dst);
    return dst.data;
}
/// ditto
string toPrettyJSON(Input)(Input nodes)
    if (isJSONParserNodeInputRange!Input)
{
    import std.array;
    auto dst = appender!string();
    nodes.writePrettyJSON(dst);
    return dst.data;
}


/**
 * Converts the given JSON document(s) to a compact string representation.
 *
 * The input can be a $(D JSONValue), or an input range of either $(D JSONToken)
 * or $(D JSONParserNode) elements.
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
string toJSON(JSONValue value)
{
    import std.array;
    auto dst = appender!string();
    value.writeJSON(dst);
    return dst.data;
}
/// ditto
string toJSON(Input)(Input nodes)
    if (isJSONParserNodeInputRange!Input)
{
    import std.array;
    auto dst = appender!string();
    nodes.writeJSON(dst);
    return dst.data;
}
/// ditto
string toJSON(Input)(Input tokens)
    if (isJSONTokenInputRange!Input)
{
    import std.array;
    auto dst = appender!string();
    tokens.writeJSON(dst);
    return dst.data;
}
/// ditto
string toJSON(JSONToken token)
{
    import std.array;
    auto dst = appender!string();
    token.writeJSON(dst);
    return dst.data;
}

///
unittest
{
    JSONValue value = true;
    assert(value.toJSON() == "true");
}

///
unittest
{
    auto a = toJSONValue(`{"a": [], "b": [1, {}]}`);

    // write compact JSON
    assert(a.toJSON() == `{"a":[],"b":[1,{}]}`, a.toJSON());

    // pretty print:
    // {
    //     "a": [],
    //     "b": [
    //         1,
    //         {},
    //     ]
    // }
    assert(a.toPrettyJSON() == "{\n\t\"a\": [],\n\t\"b\": [\n\t\t1,\n\t\t{}\n\t]\n}");
}

unittest
{
    auto nodes = parseJSONStream(`{"a": [], "b": [1, {}]}`);
    assert(nodes.toJSON() == `{"a":[],"b":[1,{}]}`);
    assert(nodes.toPrettyJSON() == "{\n\t\"a\": [],\n\t\"b\": [\n\t\t1,\n\t\t{}\n\t]\n}");

    auto tokens = lexJSON(`{"a": [], "b": [1, {}, null, true, false]}`);
    assert(tokens.toJSON() == `{"a":[],"b":[1,{},null,true,false]}`);

    JSONToken tok;
    tok.string = "Hello World";
    assert(tok.toJSON() == `"Hello World"`);
}


/**
 * Formats the given JSON document(s) as an indented multi-line string.
 *
 * This function produces output suitable for human consumption by properly
 * indenting based on the nesting level.
 *
 * See_also: $(D toPrettyJSON), $(D writeJSON)
 */
void writePrettyJSON(Output)(JSONValue value, ref Output output)
    if (isOutputRange!(Output, char))
{
    writeAsStringImpl!true(value, output);
}
/// ditto
void writePrettyJSON(Output, Input)(Input nodes, ref Output output)
    if (isOutputRange!(Output, char) && isJSONParserNodeInputRange!Input)
{
    writeAsStringImpl!true(nodes, output);
}


/**
 * Formats the given JSON document(s)/tokens as a compact string.
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
void writeJSON(Output)(JSONValue value, ref Output output)
    if (isOutputRange!(Output, char))
{
    writeAsStringImpl(value, output);
}
/// ditto
void writeJSON(Output, Input)(Input nodes, ref Output output)
    if (isOutputRange!(Output, char) && isJSONParserNodeInputRange!Input)
{
    writeAsStringImpl(nodes, output);
}
/// ditto
void writeJSON(Output, Input)(Input tokens, ref Output output)
    if (isOutputRange!(Output, char) && isJSONTokenInputRange!Input)
{
    while (!tokens.empty)
    {
        tokens.front.writeJSON(output);
        tokens.popFront();
    }
}
/// ditto
void writeJSON(Output)(in ref JSONToken token, ref Output output)
    if (isOutputRange!(Output, char))
{
    final switch (token.kind) with (JSONToken.Kind)
    {
        case none: assert(false);
        case error: output.put("_error_"); break;
        case null_: output.put("null"); break;
        case boolean: output.put(token.boolean ? "true" : "false"); break;
        case number: output.writeNumber(token.number); break;
        case string: output.put('"'); output.escapeString(token.string); output.put('"'); break;
        case objectStart: output.put('{'); break;
        case objectEnd: output.put('}'); break;
        case arrayStart: output.put('['); break;
        case arrayEnd: output.put(']'); break;
        case colon: output.put(':'); break;
        case comma: output.put(','); break;
    }
}

private void writeAsStringImpl(bool pretty_print = false, Output)(JSONValue value, ref Output output, size_t nesting_level = 0)
    if (isOutputRange!(Output, char))
{
    void indent(size_t depth)
    {
        output.put('\n');
        foreach (tab; 0 .. depth) output.put('\t');
    }

    if (value.peek!(typeof(null))) output.put("null");
    else if (auto pv = value.peek!bool) output.put(*pv ? "true" : "false");
    else if (auto pv = value.peek!double) output.writeNumber(*pv);
    else if (auto pv = value.peek!long) output.writeNumber(*pv);
    else if (auto pv = value.peek!BigInt) output.writeNumber(*pv);
    else if (auto pv = value.peek!string) { output.put('"'); output.escapeString(*pv); output.put('"'); }
    else if (auto pv = value.peek!(JSONValue[string]))
    {
        output.put('{');
        bool first = true;
        foreach (string k, ref e; *pv)
        {
            if (!first) output.put(',');
            else first = false;
            static if (pretty_print) indent(nesting_level+1);
            output.put('\"');
            output.escapeString(k);
            output.put(pretty_print ? `": ` : `":`);
            e.writeAsStringImpl!pretty_print(output, nesting_level+1);
        }
        static if (pretty_print)
        {
            if (!first) indent(nesting_level);
        }
        output.put('}');
    }
    else if (auto pv = value.peek!(JSONValue[]))
    {
        output.put('[');
        foreach (i, ref e; *pv)
        {
            if (i > 0) output.put(',');
            static if (pretty_print) indent(nesting_level+1);
            e.writeAsStringImpl!pretty_print(output, nesting_level+1);
        }
        static if (pretty_print)
        {
            if (pv.length > 0) indent(nesting_level);
        }
        output.put(']');
    }
    else assert(false);
}

private void writeAsStringImpl(bool pretty_print = false, Output, Input)(Input nodes, ref Output output)
    if (isOutputRange!(Output, char) && isJSONParserNodeInputRange!Input)
{
    size_t nesting = 0;
    bool first = false;
    bool is_object_field = false;

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
                output.escapeString(nodes.front.key);
                output.put(pretty_print ? `": ` : `":`);
                break;
            case literal:
                preValue();
                nodes.front.literal.writeJSON(output);
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

private void writeNumber(bool non_standard_floats = false, R)(ref R dst, JSONNumber num) @trusted
{
    import std.format;
    import std.math;

    final switch (num.type)
    {
        case JSONNumber.Type.double_: dst.writeNumber!non_standard_floats(num.doubleValue); break;
        case JSONNumber.Type.long_: dst.writeNumber(num.longValue); break;
        case JSONNumber.Type.bigInt: dst.writeNumber(num.bigIntValue); break;
    }
}

private void writeNumber(bool non_standard_floats = false, R)(ref R dst, double num) @trusted
{
    import std.format;
    import std.math;

    static if (non_standard_floats)
    {
        if (isNaN(num)) dst.put("NaN");
        else if (num == +double.infinity) dst.put("Infinity");
        else if (num == -double.infinity) dst.put("-Infinity");
        else dst.formattedWrite("%.16g", num.doubleValue);
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
    num.toString(str => dst.put(str), null);
}

unittest
{
    import std.math;
    import std.string;

    auto num = toJSONValue("-67.199307");
    auto exp = -67.199307;
    assert(num.get!double.approxEqual(exp));

    auto snum = appender!string;
    snum.writeNumber(JSONNumber(num.get!double));
    auto pnum = toJSONValue(snum.data);
    assert(pnum.get!double.approxEqual(num.get!double));
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
                    if (ch >= 0x20 && ch < 0x80)
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
                    if (ch < 0x20) formattedWrite(dst, "\\u%04X", ch);
                    else dst.put(ch);
                }
                break;
        }
    }
}

unittest
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
