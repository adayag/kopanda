import { describe, expect, it } from "vitest";
import {
  dump,
  fromJson,
  get,
  listLength,
  LuaTable,
  parse,
  serialize,
  table,
  toJson,
  type LuaValue,
} from "../../src/core/lua.js";

/** The value a chunk returns; fails the test, naming the error, when it is unreadable. */
function read(text: string | Uint8Array): LuaValue {
  const result = parse(text);
  if (!result.ok) throw new Error(`unreadable: ${result.error}`);
  return result.value;
}

function asTable(value: LuaValue): LuaTable {
  if (!(value instanceof LuaTable)) throw new Error("not a table");
  return value;
}

describe("dump of strings, as LuaJIT's %q writes them", () => {
  // Read on the emulator's LuaJIT (string.format("%q", s)) on 2026-10-15 and 2026-10-16.
  const cases: [string, string, string][] = [
    ["a control byte before a digit, padded", "\r1", '"\\0131"'],
    ["a tab", "\t", '"\\9"'],
    ["a newline, as a backslash and a newline", "a\nb", '"a\\\nb"'],
    ["NUL", "\0", '"\\0"'],
    ["DEL", "\x7f", '"\\127"'],
    ["a quote and a backslash", 'x"y\\z', '"x\\"y\\\\z"'],
    ["UTF-8 passed through", "Café “quoted”", '"Café “quoted”"'],
    ["a control byte last, unpadded", "\x1f", '"\\31"'],
  ];

  for (const [name, value, written] of cases) {
    it(`writes ${name} and reads it back`, () => {
      expect(dump(value)).toBe(written);
      expect(read(serialize(value, "/p"))).toBe(value);
    });
  }
});

describe("dump of numbers, as LuaJIT's tostring (%.14g) writes them", () => {
  const cases: [number, string][] = [
    [0.1 + 0.2, "0.3"],
    [1e-5, "1e-05"],
    [1e15, "1e+15"],
    [1e14, "1e+14"],
    [1e13, "10000000000000"],
    [2 ** 53, "9.007199254741e+15"],
    [-0, "-0"],
    [41.85003, "41.85003"],
    [-122.33207, "-122.33207"],
    [0.0001, "0.0001"],
    [3, "3"],
    [1e100, "1e+100"],
    [5e-324, "4.9406564584125e-324"],
    // An exact tie at the 15th digit rounds to even, as LuaJIT does; toPrecision rounds it up.
    [41 + 1 / 8192, "41.000122070312"],
    [41 + 3 / 8192, "41.000366210938"],
    [12345678901234.5, "12345678901234"],
    [99999999999999.5, "1e+14"],
  ];

  for (const [value, written] of cases) {
    it(`writes ${written}`, () => {
      expect(dump(value)).toBe(written);
    });
  }

  it("reads -0 back as -0", () => {
    expect(Object.is(read(serialize(-0, "/p")), -0)).toBe(true);
  });

  it("reads 0.1 + 0.2 back as 0.3, the digits past 14 lost as on the device", () => {
    expect(read(serialize(0.1 + 0.2, "/p"))).toBe(0.3);
  });
});

describe("parse", () => {
  it("reads nested tables with number and string keys, Name = and positional fields, and comments", () => {
    const value = asTable(
      read(`-- /mnt/us/koreader/settings/kopanda/settings.lua
-- a second comment
return {
    ["look"] = "editorial", -- trailing comment
    [2] = true;
    name = 'single',
    "first", "second";
    nested = { { x = 1.5e2 }, [3] = -.5 },
}
`),
    );

    expect(get(value, "look")).toBe("editorial");
    expect(get(value, "name")).toBe("single");
    expect(get(value, 1)).toBe("first");
    expect(get(value, 2)).toBe("second");
    const nested = asTable(get(value, "nested")!);
    expect(get(asTable(get(nested, 1)!), "x")).toBe(150);
    expect(get(nested, 3)).toBe(-0.5);
    expect(get(nested, 2)).toBeUndefined();
  });

  it("keeps a list, a keyed table and a sparse table apart", () => {
    const list = asTable(read('return { "a", "b" }'));
    const keyed = asTable(read('return { a = "a", b = "b" }'));
    const sparse = asTable(read('return { [1] = "a", [3] = "b" }'));
    const empty = asTable(read("return {}"));

    expect(listLength(list)).toBe(2);
    expect(listLength(keyed)).toBeUndefined();
    expect(listLength(sparse)).toBeUndefined();
    expect(listLength(empty)).toBe(0);
  });

  it("keeps a number key and a string key of the same digits apart", () => {
    const value = asTable(read('return { [1] = "number", ["1"] = "string" }'));

    expect(get(value, 1)).toBe("number");
    expect(get(value, "1")).toBe("string");
  });

  it("keeps the last of a repeated key, as dofile does", () => {
    expect(get(asTable(read("return { x = 1, x = 2, [\"x\"] = 3 }")), "x")).toBe(3);
    expect(get(asTable(read('return { "b", [1] = "a" }')), 1)).toBe("a");
    expect(get(asTable(read('return { [1] = "a", "b" }')), 1)).toBe("b");
  });

  it("reads Lua's escapes, \\xXX, \\ddd and a backslash before a newline", () => {
    expect(read('return "\\a\\b\\f\\n\\r\\t\\v\\\\\\"\\\'"')).toBe("\x07\b\f\n\r\t\v\\\"'");
    expect(read('return "\\x41\\65\\0659"')).toBe("AAA9");
    expect(read('return "a\\\nb"')).toBe("a\nb");
    expect(read('return "a\\\r\nb"')).toBe("a\nb");
  });

  it("reads true, false and numbers in every decimal form", () => {
    expect(read("return true")).toBe(true);
    expect(read("return false")).toBe(false);
    expect(read("return 5.")).toBe(5);
    expect(read("return .5")).toBe(0.5);
    expect(read("return 1E+2")).toBe(100);
    expect(read("return -1e-05")).toBe(-0.00001);
    expect(read("return 1;")).toBe(1);
  });

  it("decodes strings as UTF-8, from text or from bytes", () => {
    const bytes = new TextEncoder().encode('return "Café “quoted”"');

    expect(read(bytes)).toBe("Café “quoted”");
  });

  const unreadable: [string, string, number, number][] = [
    ["an expression", "return 1 + 2", 1, 10],
    ["a call", "return {\n    x = os.exit(),\n}", 2, 9],
    ["nil", "return nil", 1, 8],
    ["inf", "return { x = inf }", 1, 14],
    ["a long string", "return [[x]]", 1, 8],
    ["a long comment", "--[[ x ]] return 1", 1, 1],
    ["two values", "return 1, 2", 1, 9],
    ["an unterminated string", 'return {\n  "abc\n}', 2, 3],
    ["a string running to the end", 'return "abc', 1, 8],
    ["\\z", 'return "a\\z b"', 1, 10],
    ["an unknown escape", 'return "\\q"', 1, 9],
    ["an escape above 255", 'return "\\256"', 1, 9],
    ["invalid UTF-8", 'return "\\255"', 1, 8],
    ["a hex number", "return 0x10", 1, 8],
    ["a malformed number", "return 1e", 1, 8],
    ["a unary plus", "return +5", 1, 8],
    ["a number too large for a double", "return 1e999", 1, 8],
    ["a boolean key", "return { [true] = 1 }", 1, 11],
    ["no return", "{}", 1, 1],
    ["an empty file", "", 1, 1],
    ["a missing closing brace", "return { 1", 1, 11],
    ["a reserved word as a field name", "return { end = 1 }", 1, 10],
  ];

  for (const [name, text, line, column] of unreadable) {
    it(`refuses ${name} with its line and column`, () => {
      const result = parse(text);

      expect(result.ok).toBe(false);
      if (result.ok) return;
      expect([result.line, result.column]).toEqual([line, column]);
      expect(result.error).toMatch(new RegExp(`^line ${line}, column ${column}: .+`));
    });
  }

  it("counts columns in characters, not bytes", () => {
    const result = parse('return { "é", x }');

    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.column).toBe(15);
  });
});

describe("serialize", () => {
  it("frames dump with the header naming the path, as util.writeToFile does", () => {
    expect(serialize(table([["a", table([[1, 1], [2, 2]])]]), "/p/settings.lua")).toBe(
      '-- /p/settings.lua\nreturn {\n    ["a"] = {\n        [1] = 1,\n        [2] = 2,\n    },\n}\n',
    );
  });

  it("orders keys as orderedPairs does: numbers numerically, then strings", () => {
    const value = table([
      [10, "ten"],
      [2, "two"],
      ["b", "b"],
      ["a", "a"],
      [1, "one"],
    ]);

    expect(dump(value)).toBe(
      '{\n    [1] = "one",\n    [2] = "two",\n    [10] = "ten",\n    ["a"] = "a",\n    ["b"] = "b",\n}',
    );
  });

  it("orders string keys byte by byte, as LuaJIT compares strings", () => {
    // U+FF21 is EF BC A1 in UTF-8 and U+1F600 F0 9F 98 80, so U+FF21 comes first by bytes, though
    // its UTF-16 code unit is above the emoji's first surrogate.
    const value = table([
      ["\u{1F600}", 1],
      ["Ａ", 2],
      ["b", 3],
    ]);

    expect(dump(value)).toBe('{\n    ["b"] = 3,\n    ["Ａ"] = 2,\n    ["\u{1F600}"] = 1,\n}');
  });

  it("writes an empty table as {}", () => {
    expect(dump(table())).toBe("{}");
    expect(dump(table([["x", table()]]))).toBe('{\n    ["x"] = {},\n}');
  });

  it("writes a value parse reads back the same", () => {
    const value = table([
      ["rows", table([[1, table([["widget", "date"], ["share", 2]])]])],
      [3, false],
    ]);

    expect(read(serialize(value, "/p"))).toEqual(value);
  });
});

describe("JSON", () => {
  it("maps arrays to lists and objects to keyed tables, and back", () => {
    const json = { name: "x", list: [1, "a", true, []], nested: { y: false } };
    const value = asTable(fromJson(json));

    expect(listLength(asTable(get(value, "list")!))).toBe(4);
    expect(get(asTable(get(value, "list")!), 1)).toBe(1);
    expect(get(asTable(get(value, "nested")!), "y")).toBe(false);
    expect(toJson(value)).toEqual(json);
  });

  it("refuses null, a non-finite number and a lone surrogate", () => {
    expect(() => fromJson(null)).toThrow(/null/);
    expect(() => fromJson({ a: [1, null] })).toThrow(/null/);
    expect(() => fromJson(Infinity)).toThrow(/finite/);
    expect(() => fromJson(NaN)).toThrow(/finite/);
    expect(() => fromJson("\ud800")).toThrow(/UTF-8/);
    expect(() => fromJson(undefined)).toThrow();
  });

  it("refuses to give JSON for a table with number keys that aren't a list", () => {
    expect(() => toJson(table([[1, "a"], [3, "b"]]))).toThrow();
  });
});
