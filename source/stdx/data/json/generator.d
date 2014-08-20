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
string toJSONString(bool pretty_print = false, Input)(Input input)
    if (isJSONTokenInputRange!Input)
{
    import std.array;
    auto dst = appender!string();
    input.writeAsString!pretty_print(dst);
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



/**
 *
 */
void writeAsString(bool pretty_print = false, Output)(JSONValue value, ref Output output, size_t nesting_level = 0)
    if (isOutputRange!(Output, char))
{
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

            static if (pretty_print) {
                output.put('\n');
                foreach (tab; 0 .. nesting_level+1) output.put('\t');
            }
            output.put('\"');
            output.escapeString(k);
            output.put(pretty_print ? `": ` : `":`);
            e.writeAsString!pretty_print(output, nesting_level+1);
        }
        static if (pretty_print) {
            if (!first) {
                output.put('\n');
                foreach (tab; 0 .. nesting_level) output.put('\t');
            }
        }
        output.put('}');
    } else if (auto pv = value.peek!(JSONValue[])) {
        output.put('[');
        foreach (i, ref e; *pv) {
            if (i > 0) output.put(",");
            static if (pretty_print) {
                output.put('\n');
                foreach (tab; 0 .. nesting_level+1) output.put('\t');
            }
            e.writeAsString!pretty_print(output, nesting_level+1);
        }
        static if (pretty_print) {
            if (pv.length > 0) {
                output.put('\n');
                foreach (tab; 0 .. nesting_level) output.put('\t');
            }
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

    while (!input.empty) {
        final switch (input.front.kind) with (JSONParserNode.Kind) {
            case invalid: assert(false);
            case key:
                if (nesting > 0 && !first) dst.put(',');
                else first = false;
                dst.put('"');
                dst.escapeString(input.front.key);
                dst.put('"');
                dst.put(':');
                break;
            case value:
                if (nesting > 0 && !first) dst.put(',');
                else first = false;
                dst.writeAsString(input.value);
                break;
            case objectStart:
                dst.put('{');
                nesting++;
                first = true;
                break;
            case objectEnd:
                nesting--;
                dst.put('}');
                break;
            case arrayStart:
                dst.put('[');
                nesting++;
                first = true;
                break;
            case arrayEnd:
                nesting--;
                dst.put(']');
                break;
        }
    }
    assert(false);
}
/// ditto
void writeAsString(Output, Input)(Input input, ref Output output)
    if (isOutputRange!(Output, char) && isJSONTokenInputRange!Inout)
{
    while (!input.empty) {
        dst.writeAsString(input.front);
        input.popFront();
    }
}
/// ditto
void writeAsString(Output)(in ref JSONToken token, ref Output output)
    if (isOutputRange!(Output, char))
{
    final switch (token.kind) with (JSONToken.Kind) {
        case invalid: assert(false);
        case null_: dst.put("null"); break;
        case boolean: dst.put(token.boolean ? "true" : "false"); break;
        case number: dst.writeNumber(token.number); break;
        case string: dst.put('"'); dst.escapeString(token.string); dst.put('"'); break;
        case objectStart: dst.put('{'); break;
        case objectEnd: dst.put('}'); break;
        case arrayStart: dst.put('['); break;
        case arrayEnd: dst.put(']'); break;
        case colon: dst.put(':'); break;
        case comma: dst.put(','); break;
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
