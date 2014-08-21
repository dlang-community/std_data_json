/**
 * Package import for the whole std.data.json package.
 *
 * Synopsis:
 * ---
 * // Parse a JSON string
 * JSONValue value = parseJSON(`{"name": "D", "kind": "language"}`);
 * auto fields = value.get!(JSONValue[string]);
 * assert(fields["name"] == "D");
 * assert(fields["kind"] == "language");
 *
 * // Convert a value back to a JSON string
 * assert(value.toJSONString() == `{"name":"D","kind":"language"}`);
 *
 * // Convert a value to a formatted JSON string
 * assert(value.toJSONString!true() ==
 * `{
 *     "name": "D",
 *     "kind": "language"
 * }`);
 *
 * // Lex a JSON string into a lazy range of tokens
 * auto tokens = lexJSON(`{"name": "D", "kind": "language"}`);
 * with (JSONToken.Kind) {
 *     assert(tokens.map!(t => t.kind).equal(
 *         [objectStart, string, colon, string, comma,
 *         string, colon, string, objectEnd]));
 * }
 *
 * // Parse the tokens to a value
 * JSONValue value2 = parseJSON(tokens);
 * assert(value2 == value);
 *
 * // Parse the tokens to a JSON node stream
 * auto nodes = parseJSONStream(tokens);
 * with (JSONParserNode.Kind) {
 *     assert(nodes.map!(n => n.kind).equal(
 *         [objectStart, key, value, key, value, objectEnd]));
 * }
 * ---
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/package.d)
 */
module stdx.data.json;

public import stdx.data.json.exception;
public import stdx.data.json.generator;
public import stdx.data.json.lexer;
public import stdx.data.json.parser;
public import stdx.data.json.value;
