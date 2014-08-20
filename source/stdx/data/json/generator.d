/**
 * Contains routines for converting JSON values to their string represencation.
 */
module stdx.data.json.generator;

import stdx.data.json.lexer;
import stdx.data.json.parser;
import stdx.data.json.value;
import std.range;


/**
 * Converts the given JSON document(s) to a string representation.
 *
 * The input can be a $(D JSONValue), or an input range of either $(D JSONToken)
 * or $(D JSONParserNode) elements. When converting a $(D JSONValue) or a range
 * of $(D JSONParserNode) elements, the resulting JSON string can optionally be
 * pretty printed. Pretty printed strings are indented multi-line strings
 * suitable for human consumption.
 */
string toJSONString(bool pretty_print = false)(JSONValue value)
{
    import std.array;
    auto dst = appender!string();
    value.writeAsString!pretty_print(dst);
    return dst.data;
}
/// ditto
string toJSONString(bool pretty_print = false, Input)(Input input)
    if (isJSONParserNodeInputRange!Input)
{
    import std.array;
    auto dst = appender!string();
    input.writeAsString!pretty_print(dst);
    return dst.data;
}
/// ditto
string toJSONString(Input)(Input input)
    if (isJSONTokenInputRange!Input)
{
    import std.array;
    auto dst = appender!string();
    input.writeAsString(dst);
    return dst.data;
}

///
unittest {
    JSONValue value = true;
    assert(value.toJSONString() == "true");
}

///
unittest {
    auto a = parseJSON(`{"a": [], "b": [1, {}]}`);

    // write compact JSON
    assert(a.toJSONString!false() == `{"a":[],"b":[1,{}]}`);

    // pretty print:
    // {
    //     "a": [],
    //     "b": [
    //         1,
    //         {},
    //     ]
    // }
    assert(a.toJSONString!true() == "{\n\t\"a\": [],\n\t\"b\": [\n\t\t1,\n\t\t{}\n\t]\n}");
}

unittest {
    auto tokens = lexJSON(`{"a": [], "b": [1, {}]}`);
    assert(tokens.toJSONString() == `{"a":[],"b":[1,{}]}`);

    auto nodes = parseJSONStream(`{"a": [], "b": [1, {}]}`);
    assert(nodes.toJSONString() == `{"a":[],"b":[1,{}]}`);
    assert(nodes.toJSONString!true() == "{\n\t\"a\": [],\n\t\"b\": [\n\t\t1,\n\t\t{}\n\t]\n}");
}



/**
 *
 */
void writeAsString(bool pretty_print = false, Output)(JSONValue value, ref Output output, size_t nesting_level = 0)
    if (isOutputRange!(Output, char))
{
    void indent(size_t depth) {
        output.put('\n');
        foreach (tab; 0 .. depth) output.put('\t');
    }

    if (value.peek!(typeof(null))) output.put("null");
    else if (auto pv = value.peek!bool) output.put(*pv ? "true" : "false");
    else if (auto pv = value.peek!double) output.writeNumber(*pv);
    else if (auto pv = value.peek!string) { output.put('"'); output.escapeString(*pv); output.put('"'); }
    else if (auto pv = value.peek!(JSONValue[string])) {
        output.put('{');
        bool first = true;
        foreach (string k, ref e; *pv) {
            if (!first) output.put(',');
            else first = false;
            static if (pretty_print) indent(nesting_level+1);
            output.put('\"');
            output.escapeString(k);
            output.put(pretty_print ? `": ` : `":`);
            e.writeAsString!pretty_print(output, nesting_level+1);
        }
        static if (pretty_print) {
            if (!first) indent(nesting_level);
        }
        output.put('}');
    } else if (auto pv = value.peek!(JSONValue[])) {
        output.put('[');
        foreach (i, ref e; *pv) {
            if (i > 0) output.put(",");
            static if (pretty_print) indent(nesting_level+1);
            e.writeAsString!pretty_print(output, nesting_level+1);
        }
        static if (pretty_print) {
            if (pv.length > 0) indent(nesting_level);
        }
        output.put(']');
    } else assert(false);
}
/// ditto
void writeAsString(bool pretty_print = false, Output, Input)(Input input, ref Output output)
    if (isOutputRange!(Output, char) && isJSONParserNodeInputRange!Input)
{
    size_t nesting = 0;
    bool first = false;
    bool is_object_field = false;

    void indent(size_t depth) {
        output.put('\n');
        foreach (tab; 0 .. depth) output.put('\t');
    }

    void preValue()
    {
        if (!is_object_field) {
            if (nesting > 0 && !first) output.put(',');
            else first = false;
            static if (pretty_print) {
                if (nesting > 0) indent(nesting);
            }
        } else is_object_field = false;
    }

    while (!input.empty) {
        final switch (input.front.kind) with (JSONParserNode.Kind) {
            case invalid: assert(false);
            case key:
                if (nesting > 0 && !first) output.put(',');
                else first = false;
                is_object_field = true;
                static if (pretty_print) indent(nesting);
                output.put('"');
                output.escapeString(input.front.key);
                output.put(pretty_print ? `": ` : `":`);
                break;
            case value:
                preValue();
                input.front.value.writeAsString(output);
                break;
            case objectStart:
                preValue();
                output.put('{');
                nesting++;
                first = true;
                break;
            case objectEnd:
                nesting--;
                static if (pretty_print) {
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
                static if (pretty_print) {
                    if (!first) indent(nesting);
                }
                first = false;
                output.put(']');
                break;
        }
        input.popFront();
    }
}
/// ditto
void writeAsString(Output, Input)(Input input, ref Output output)
    if (isOutputRange!(Output, char) && isJSONTokenInputRange!Input)
{
    while (!input.empty) {
        input.front.writeAsString(output);
        input.popFront();
    }
}
/// ditto
void writeAsString(Output)(in ref JSONToken token, ref Output output)
    if (isOutputRange!(Output, char))
{
    final switch (token.kind) with (JSONToken.Kind) {
        case invalid: assert(false);
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


private void writeNumber(R)(ref R dst, double num)
{
    import std.format;
    dst.formattedWrite("%.16g", num);
}

private void escapeString(R)(ref R dst, string s)
{
    import std.format;
    import std.utf : decode;

    for (size_t pos = 0; pos < s.length; pos++) {
        immutable ch = s[pos];

        switch (ch) {
            case '\\': dst.put(`\\`); break;
            case '\b': dst.put(`\b`); break;
            case '\f': dst.put(`\f`); break;
            case '\r': dst.put(`\r`); break;
            case '\n': dst.put(`\n`); break;
            case '\t': dst.put(`\t`); break;
            case '\"': dst.put(`\"`); break;
            default:
                if (ch >= 0x20 && ch < 0x80) {
                    dst.put(ch);
                    break;
                }

                dchar cp = decode(s, pos);
                pos--; // account for the next loop increment

                // encode as one or two UTF-16 code points
                if (cp < 0x10000) { // in BMP -> 1 CP
                    formattedWrite(dst, "\\u%04X", cp);
                } else { // not in BMP -> surrogate pair
                    int first, last;
                    cp -= 0x10000;
                    first = 0xD800 | ((cp & 0xffc00) >> 10);
                    last = 0xDC00 | (cp & 0x003ff);
                    formattedWrite(dst, "\\u%04X\\u%04X", first, last);
                }
                break;
        }
    }
}

unittest {
    // ...
}
