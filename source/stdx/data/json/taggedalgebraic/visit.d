module stdx.data.json.taggedalgebraic.visit;

import stdx.data.json.taggedalgebraic.taggedalgebraic;
import stdx.data.json.taggedalgebraic.taggedunion;

import std.meta : anySatisfy;
import std.traits : EnumMembers, isInstanceOf;


/** Dispatches the value contained on a `TaggedUnion` or `TaggedAlgebraic` to a
	set of visitors.

	A visitor can have one of three forms:

	$(UL
		$(LI function or delegate taking a single typed parameter)
		$(LI function or delegate taking no parameters)
		$(LI function or delegate template taking any single parameter)
	)

	....
*/
template visit(VISITORS...)
	if (VISITORS.length > 0)
{
	auto visit(TU)(auto ref TU tu)
		if (isInstanceOf!(TaggedUnion, TU))
	{
		alias val = validateHandlers!(TU, VISITORS);

		final switch (tu.kind) {
			static foreach (k; EnumMembers!(TU.Kind)) {
				case k: {
					static if (isUnitType!(TU.FieldTypes[k]))
						alias T = void;
					else alias T = TU.FieldTypes[k];
					alias h = selectHandler!(T, VISITORS);
					static if (is(typeof(h) == typeof(null))) static assert(false, "No visitor defined for type type "~T.stringof);
					else static if (is(typeof(h) == string)) static assert(false, h);
					else static if (is(T == void)) return h();
					else return h(tu.value!k);
				}
			}
		}
	}

	auto visit(U)(auto ref TaggedAlgebraic!U ta)
	{
		return visit(ta.get!(TaggedUnion!U));
	}
}

///
unittest {
	static if (__VERSION__ >= 2081) {
		import std.conv : to;

		union U {
			int number;
			string text;
		}
		alias TU = TaggedUnion!U;

		auto tu = TU.number(42);
		tu.visit!(
			(int n) { assert(n == 42); },
			(string s) { assert(false); }
		);

		assert(tu.visit!((v) => to!int(v)) == 42);

		tu.setText("43");

		assert(tu.visit!((v) => to!int(v)) == 43);
	}
}

unittest {
	// repeat test from TaggedUnion
	union U {
		Void none;
		int count;
		float length;
	}
	TaggedAlgebraic!U u;

	//
	static assert(is(typeof(u.visit!((int) {}, (float) {}, () {}))));
	static assert(is(typeof(u.visit!((_) {}, () {}))));
	static assert(is(typeof(u.visit!((_) {}, (float) {}, () {}))));
	static assert(is(typeof(u.visit!((float) {}, (_) {}, () {}))));

	static assert(!is(typeof(u.visit!((_) {})))); // missing void handler
	static assert(!is(typeof(u.visit!(() {})))); // missing value handler

	static assert(!is(typeof(u.visit!((_) {}, () {}, (string) {})))); // invalid typed handler
	static assert(!is(typeof(u.visit!((int) {}, (float) {}, () {}, () {})))); // duplicate void handler
	static assert(!is(typeof(u.visit!((_) {}, () {}, (_) {})))); // duplicate generic handler
	static assert(!is(typeof(u.visit!((int) {}, (float) {}, (float) {}, () {})))); // duplicate typed handler

	// TODO: error out for superfluous generic handlers
	//static assert(!is(typeof(u.visit!((int) {}, (float) {}, () {}, (_) {})))); // superfluous generic handler
}

unittest {
	union U {
		Void none;
		int count;
		float length;
	}
	TaggedUnion!U u;

	//
	static assert(is(typeof(u.visit!((int) {}, (float) {}, () {}))));
	static assert(is(typeof(u.visit!((_) {}, () {}))));
	static assert(is(typeof(u.visit!((_) {}, (float) {}, () {}))));
	static assert(is(typeof(u.visit!((float) {}, (_) {}, () {}))));

	static assert(!is(typeof(u.visit!((_) {})))); // missing void handler
	static assert(!is(typeof(u.visit!(() {})))); // missing value handler

	static assert(!is(typeof(u.visit!((_) {}, () {}, (string) {})))); // invalid typed handler
	static assert(!is(typeof(u.visit!((int) {}, (float) {}, () {}, () {})))); // duplicate void handler
	static assert(!is(typeof(u.visit!((_) {}, () {}, (_) {})))); // duplicate generic handler
	static assert(!is(typeof(u.visit!((int) {}, (float) {}, (float) {}, () {})))); // duplicate typed handler

	// TODO: error out for superfluous generic handlers
	//static assert(!is(typeof(u.visit!((int) {}, (float) {}, () {}, (_) {})))); // superfluous generic handler
}

/** The same as `visit`, except that failure to handle types is checked at runtime.

	Instead of failing to compile, `tryVisit` will throw an `Exception` if none
	of the handlers is able to handle the value contained in `tu`.
*/
template tryVisit(VISITORS...)
	if (VISITORS.length > 0)
{
	auto tryVisit(TU)(auto ref TU tu)
		if (isInstanceOf!(TaggedUnion, TU))
	{
		final switch (tu.kind) {
			static foreach (k; EnumMembers!(TU.Kind)) {
				case k: {
					static if (isUnitType!(TU.FieldTypes[k]))
						alias T = void;
					else alias T = TU.FieldTypes[k];
					alias h = selectHandler!(T, VISITORS);
					static if (is(typeof(h) == typeof(null))) throw new Exception("Type "~T.stringof~" not handled by any visitor.");
					else static if (is(typeof(h) == string)) static assert(false, h);
					else static if (is(T == void)) return h();
					else return h(tu.value!k);
				}
			}
		}
	}

	auto tryVisit(U)(auto ref TaggedAlgebraic!U ta)
	{
		return tryVisit(ta.get!(TaggedUnion!U));
	}
}

///
unittest {
	import std.exception : assertThrown;

	union U {
		int number;
		string text;
	}
	alias TU = TaggedUnion!U;

	auto tu = TU.number(42);
	tu.tryVisit!((int n) { assert(n == 42); });
	assertThrown(tu.tryVisit!((string s) { assert(false); }));
}

// repeat from TaggedUnion
unittest {
	import std.exception : assertThrown;

	union U {
		int number;
		string text;
	}
	alias TA = TaggedAlgebraic!U;

	auto ta = TA(42);
	ta.tryVisit!((int n) { assert(n == 42); });
	assertThrown(ta.tryVisit!((string s) { assert(false); }));
}


private template validateHandlers(TU, VISITORS...)
{
	import std.traits : isSomeFunction;

	alias Types = TU.FieldTypes;

	static foreach (int i; 0 .. VISITORS.length) {
		static assert(!is(VISITORS[i]) || isSomeFunction!(VISITORS[i]),
			"Visitor at index "~i.stringof~" must be a function/delegate literal: "~VISITORS[i].stringof);
		static assert(anySatisfy!(matchesType!(VISITORS[i]), Types),
			"Visitor at index "~i.stringof~" does not match any type of "~TU.FieldTypes.stringof);
	}
}

private template matchesType(alias fun) {
	import std.traits : ParameterTypeTuple, isSomeFunction;

	template matchesType(T) {
		static if (isSomeFunction!fun) {
			alias Params = ParameterTypeTuple!fun;
			static if (Params.length == 0 && isUnitType!T) enum matchesType = true;
			else static if (Params.length == 1 && is(T == Params[0])) enum matchesType = true;
			else enum matchesType = false;
		} else static if (!isUnitType!T) {
			static if (__traits(compiles, fun!T) && isSomeFunction!(fun!T)) {
				alias Params = ParameterTypeTuple!(fun!T);
				static if (Params.length == 1 && is(T == Params[0])) enum matchesType = true;
				else enum matchesType = false;
			} else enum matchesType = false;
		} else enum matchesType = false;
	}
}

unittest {
	class C {}
	alias mt1 = matchesType!((C c) => true);
	alias mt2 = matchesType!((c) { static assert(!is(typeof(c) == C)); });
	static assert(mt1!C);
	static assert(!mt1!int);
	static assert(mt2!int);
	static assert(!mt2!C);
}

private template selectHandler(T, VISITORS...)
{
	import std.traits : ParameterTypeTuple, isSomeFunction;

	template typedIndex(int i, int matched_index = -1) {
		static if (i < VISITORS.length) {
			alias fun = VISITORS[i];
			static if (isSomeFunction!fun) {
				alias Params = ParameterTypeTuple!fun;
				static if (Params.length > 1) enum typedIndex = "Visitor at index "~i.stringof~" must not take more than one parameter.";
				else static if (Params.length == 0 && is(T == void) || Params.length == 1 && is(T == Params[0])) {
					static if (matched_index >= 0) enum typedIndex = "Vistor at index "~i.stringof~" conflicts with visitor at index "~matched_index~".";
					else enum typedIndex = typedIndex!(i+1, i);
				} else enum typedIndex = typedIndex!(i+1, matched_index);
			} else enum typedIndex = typedIndex!(i+1, matched_index);
		} else enum typedIndex = matched_index;
	}

	template genericIndex(int i, int matched_index = -1) {
		static if (i < VISITORS.length) {
			alias fun = VISITORS[i];
			static if (!isSomeFunction!fun) {
				static if (__traits(compiles, fun!T) && isSomeFunction!(fun!T)) {
					static if (ParameterTypeTuple!(fun!T).length == 1) {
						static if (matched_index >= 0) enum genericIndex = "Only one generic visitor allowed";
						else enum genericIndex = genericIndex!(i+1, i);
					} else enum genericIndex = "Generic visitor at index "~i.stringof~" must have a single parameter.";
				} else enum genericIndex = "Visitor at index "~i.stringof~" (or its template instantiation with type "~T.stringof~") must be a valid function or delegate.";
			} else enum genericIndex = genericIndex!(i+1, matched_index);
		} else enum genericIndex = matched_index;
	}

	enum typed_index = typedIndex!0;
	static if (is(T == void)) enum generic_index = -1;
	else enum generic_index = genericIndex!0;

	static if (is(typeof(typed_index) == string)) enum selectHandler = typed_index;
	else static if (is(typeof(generic_index == string))) enum selectHandler = generic_index;
	else static if (typed_index >= 0) alias selectHandler = VISITORS[typed_index];
	else static if (generic_index >= 0) alias selectHandler = VISITORS[generic_index];
	else enum selectHandler = null;
}
