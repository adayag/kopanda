// The plugin's settings file format, read and written without Lua. A settings file is
// `-- <path>\nreturn <value>\n` as KOReader's LuaSettings:flush writes it (frontend/luasettings.lua:
// 270-275, frontend/util.lua:1126-1129, frontend/dump.lua:10-73, at e1fe1ac). parse reads the
// literal subset dump writes plus the forms a hand edit adds; anything else is refused with its line
// and column, never guessed at.

export type LuaKey = string | number;
export type LuaValue = string | number | boolean | LuaTable;

/** A Lua table: its keys keep their types, so [1] and ["1"] are two keys. */
export class LuaTable {
  readonly fields = new Map<LuaKey, LuaValue>();
}

/** A table holding the given fields, a later one replacing an earlier one of the same key. */
export function table(fields: Iterable<readonly [LuaKey, LuaValue]> = []): LuaTable {
  const t = new LuaTable();
  for (const [key, value] of fields) t.fields.set(key, value);
  return t;
}

/** The value at key, undefined where Lua would give nil. */
export function get(t: LuaTable, key: LuaKey): LuaValue | undefined {
  return t.fields.get(key);
}

/**
 * The number of entries when t's keys are exactly 1 to that number, undefined otherwise: the
 * plugin's list_length (kopanda.koplugin/settings.lua:16-32).
 */
export function listLength(t: LuaValue | undefined): number | undefined {
  if (!(t instanceof LuaTable)) return undefined;
  const count = t.fields.size;
  for (let i = 1; i <= count; i++) {
    if (!t.fields.has(i)) return undefined;
  }
  return count;
}

// JSON

/**
 * The Lua value for a JSON value: an array is a list, an object a keyed table. null, a non-finite
 * number and a string that isn't valid UTF-16 (so has no UTF-8) are refused with an Error.
 */
export function fromJson(json: unknown): LuaValue {
  if (json === null) throw new Error("null has no Lua value");
  if (typeof json === "boolean") return json;
  if (typeof json === "number") {
    if (!Number.isFinite(json)) throw new Error(`${json} is not a finite number`);
    return json;
  }
  if (typeof json === "string") {
    if (/\p{Cs}/u.test(json)) throw new Error("a string holds a lone surrogate, which has no UTF-8");
    return json;
  }
  if (Array.isArray(json)) {
    return table(json.map((item, i) => [i + 1, fromJson(item)] as const));
  }
  if (typeof json === "object") {
    return table(Object.entries(json).map(([key, item]) => [key, fromJson(item)] as const));
  }
  throw new Error(`a ${typeof json} has no Lua value`);
}

/**
 * The JSON value for a Lua value: a list (an empty table included) is an array, a table of string
 * keys an object. A table with number keys that aren't a list has no JSON form and throws.
 */
export function toJson(value: LuaValue): unknown {
  if (!(value instanceof LuaTable)) return value;
  const length = listLength(value);
  if (length !== undefined) {
    return Array.from({ length }, (_, i) => toJson(value.fields.get(i + 1)!));
  }
  const object: Record<string, unknown> = {};
  for (const key of orderedKeys(value)) {
    if (typeof key !== "string") throw new Error(`a table with the number key ${formatNumber(key)} has no JSON form`);
    object[key] = toJson(value.fields.get(key)!);
  }
  return object;
}

// Writing

const encoder = new TextEncoder();

/** -1, 0 or 1 as a is below, equal to or above b compared byte by byte in UTF-8, as LuaJIT does. */
function compareBytes(a: string, b: string): number {
  const x = encoder.encode(a);
  const y = encoder.encode(b);
  const n = Math.min(x.length, y.length);
  for (let i = 0; i < n; i++) {
    if (x[i] !== y[i]) return x[i]! < y[i]! ? -1 : 1;
  }
  return x.length === y.length ? 0 : x.length < y.length ? -1 : 1;
}

/** Lua's tostring of a key, which orderedPairs compares keys of two types by. */
function keyString(key: LuaKey): string {
  return typeof key === "number" ? formatNumber(key) : key;
}

/**
 * t's keys in orderedPairs' order (base/ffi/util.lua:720-766): keys of one type by <, numbers
 * numerically and strings byte by byte; keys of two types by their tostring.
 */
export function orderedKeys(t: LuaTable): LuaKey[] {
  return [...t.fields.keys()].sort((a, b) => {
    if (typeof a === "number" && typeof b === "number") return a < b ? -1 : a > b ? 1 : 0;
    if (typeof a === "string" && typeof b === "string") return compareBytes(a, b);
    return compareBytes(keyString(a), keyString(b));
  });
}

/**
 * The exact decimal digits of a positive finite double and the power of ten of the first one:
 * x = 0.d1 d2 d3… × 10^(exponent + 1).
 */
function exactDigits(x: number): { digits: string; exponent: number } {
  const view = new DataView(new ArrayBuffer(8));
  view.setFloat64(0, x);
  const bits = view.getBigUint64(0);
  const biased = Number((bits >> 52n) & 0x7ffn);
  let mantissa = bits & ((1n << 52n) - 1n);
  let power: number;
  if (biased === 0) {
    power = -1074;
  } else {
    mantissa |= 1n << 52n;
    power = biased - 1075;
  }
  // x = mantissa × 2^power = mantissa × 5^-power / 10^-power when power is negative.
  const digits = power >= 0 ? (mantissa << BigInt(power)).toString() : (mantissa * 5n ** BigInt(-power)).toString();
  const scale = power >= 0 ? 0 : -power;
  return { digits, exponent: digits.length - 1 - scale };
}

const PRECISION = 14;

/**
 * Lua's tostring of a number: C's %.14g, rounding an exact tie to even as LuaJIT does (41 + 1/8192
 * gives 41.000122070312), and -0 as -0.
 */
export function formatNumber(n: number): string {
  if (!Number.isFinite(n)) throw new Error(`${n} is not a finite number`);
  if (n === 0) return Object.is(n, -0) ? "-0" : "0";
  const sign = n < 0 ? "-" : "";
  const exact = exactDigits(Math.abs(n));
  let exponent = exact.exponent;
  let rounded = BigInt(exact.digits.slice(0, PRECISION).padEnd(PRECISION, "0"));
  const rest = exact.digits.slice(PRECISION);
  if (rest !== "") {
    const first = rest[0]!;
    const above = first > "5" || (first === "5" && (/[1-9]/.test(rest.slice(1)) || rounded % 2n === 1n));
    if (above) rounded += 1n;
  }
  let digits = rounded.toString();
  if (digits.length > PRECISION) {
    digits = digits.slice(0, PRECISION);
    exponent += 1;
  }
  if (exponent < -4 || exponent >= PRECISION) {
    const fraction = digits.slice(1).replace(/0+$/, "");
    const magnitude = String(Math.abs(exponent)).padStart(2, "0");
    return `${sign}${digits[0]}${fraction ? `.${fraction}` : ""}e${exponent < 0 ? "-" : "+"}${magnitude}`;
  }
  const whole = exponent >= 0 ? digits.slice(0, exponent + 1) : "0";
  const fraction = (exponent >= 0 ? digits.slice(exponent + 1) : "0".repeat(-exponent - 1) + digits).replace(/0+$/, "");
  return `${sign}${whole}${fraction ? `.${fraction}` : ""}`;
}

function isDigit(c: string | undefined): boolean {
  return c !== undefined && c >= "0" && c <= "9";
}

/**
 * A string as LuaJIT's %q writes it: ", \ and newline after a backslash (the newline kept), other
 * control bytes as decimal \ddd, padded to three digits only before a digit, bytes of 128 and over
 * as they are.
 */
function quote(s: string): string {
  let out = '"';
  for (let i = 0; i < s.length; i++) {
    const c = s[i]!;
    const code = c.charCodeAt(0);
    if (c === '"' || c === "\\" || c === "\n") {
      out += `\\${c}`;
    } else if (code < 32 || code === 127) {
      out += `\\${isDigit(s[i + 1]) ? String(code).padStart(3, "0") : code}`;
    } else {
      out += c;
    }
  }
  return `${out}"`;
}

const INDENT = "    ";

function dumpAt(value: LuaValue, level: number): string {
  if (typeof value === "string") return quote(value);
  if (typeof value === "number") return formatNumber(value);
  if (typeof value === "boolean") return String(value);
  const keys = orderedKeys(value);
  if (keys.length === 0) return "{}";
  let out = "{";
  for (const key of keys) {
    out += `\n${INDENT.repeat(level + 1)}[${dumpAt(key, level + 1)}] = ${dumpAt(value.fields.get(key)!, level + 1)},`;
  }
  return `${out}\n${INDENT.repeat(level)}}`;
}

/** value as KOReader's dump(value, nil, true) writes it. */
export function dump(value: LuaValue): string {
  return dumpAt(value, 0);
}

/** The settings file LuaSettings:flush writes for value at headerPath. */
export function serialize(value: LuaValue, headerPath: string): string {
  return `-- ${headerPath}\nreturn ${dump(value)}\n`;
}

// Reading

export type ParseResult =
  | { ok: true; value: LuaValue }
  | { ok: false; error: string; line: number; column: number };

class ParseError extends Error {
  constructor(
    message: string,
    readonly line: number,
    readonly column: number,
  ) {
    super(message);
  }
}

// LuaJIT's reserved words (lj_lex.h).
const RESERVED = new Set([
  "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in",
  "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
]);

const SIMPLE_ESCAPES: Record<string, number> = {
  a: 7, b: 8, f: 12, n: 10, r: 13, t: 9, v: 11, "\\": 92, '"': 34, "'": 39,
};

const CR = 13;
const LF = 10;

function isSpace(b: number): boolean {
  return b === 32 || (b >= 9 && b <= 13);
}

function isDigitByte(b: number | undefined): boolean {
  return b !== undefined && b >= 48 && b <= 57;
}

function isNameStart(b: number | undefined): boolean {
  return b !== undefined && ((b >= 65 && b <= 90) || (b >= 97 && b <= 122) || b === 95);
}

function isNameByte(b: number | undefined): boolean {
  return isNameStart(b) || isDigitByte(b);
}

function isHex(b: number | undefined): boolean {
  return b !== undefined && (isDigitByte(b) || (b >= 65 && b <= 70) || (b >= 97 && b <= 102));
}

type Token =
  | { kind: "punct"; text: string; line: number; column: number }
  | { kind: "name"; text: string; line: number; column: number }
  | { kind: "string"; value: string; line: number; column: number }
  | { kind: "number"; value: number; line: number; column: number }
  | { kind: "eof"; line: number; column: number };

const decoder = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });

/** Reads bytes into tokens on demand, tracking the line and the column in characters. */
class Lexer {
  private pos = 0;
  private line = 1;
  private column = 1;

  constructor(private readonly bytes: Uint8Array) {}

  private peek(offset = 0): number | undefined {
    return this.bytes[this.pos + offset];
  }

  private fail(message: string, line = this.line, column = this.column): never {
    throw new ParseError(message, line, column);
  }

  /** Steps over one byte; a UTF-8 continuation byte doesn't start a new column. */
  private advance(): number {
    const b = this.bytes[this.pos++]!;
    if ((b & 0xc0) !== 0x80) this.column++;
    return b;
  }

  /** Steps over a newline, \r\n and \n\r counting as one, as Lua's lexer does. */
  private newline(): void {
    const first = this.advance();
    const next = this.peek();
    if ((next === CR || next === LF) && next !== first) this.pos++;
    this.line++;
    this.column = 1;
  }

  private skipSpaceAndComments(): void {
    for (;;) {
      const b = this.peek();
      if (b === CR || b === LF) {
        this.newline();
      } else if (b !== undefined && isSpace(b)) {
        this.advance();
      } else if (b === 45 && this.peek(1) === 45) {
        if (this.peek(2) === 91) {
          let i = 3;
          while (this.peek(i) === 61) i++;
          if (this.peek(i) === 91) this.fail("a long comment isn't read; use -- line comments");
        }
        while (this.peek() !== undefined && this.peek() !== CR && this.peek() !== LF) this.advance();
      } else {
        return;
      }
    }
  }

  next(): Token {
    this.skipSpaceAndComments();
    const line = this.line;
    const column = this.column;
    const b = this.peek();
    if (b === undefined) return { kind: "eof", line, column };
    if (b === 34 || b === 39) return { kind: "string", value: this.string(), line, column };
    if (isDigitByte(b) || (b === 46 && isDigitByte(this.peek(1)))) {
      return { kind: "number", value: this.number(line, column), line, column };
    }
    if (b === 45 && (isDigitByte(this.peek(1)) || (this.peek(1) === 46 && isDigitByte(this.peek(2))))) {
      this.advance();
      return { kind: "number", value: -this.number(line, column), line, column };
    }
    if (isNameStart(b)) {
      let text = "";
      while (isNameByte(this.peek())) text += String.fromCharCode(this.advance());
      return { kind: "name", text, line, column };
    }
    if (b === 91 && (this.peek(1) === 91 || this.peek(1) === 61)) {
      this.fail("a long string isn't read; use a quoted string");
    }
    if ("{}[]=,;".includes(String.fromCharCode(b))) {
      this.advance();
      return { kind: "punct", text: String.fromCharCode(b), line, column };
    }
    return this.fail(`unexpected symbol "${String.fromCharCode(b)}"`);
  }

  private number(line: number, column: number): number {
    const start = this.pos;
    if (this.peek() === 48 && (this.peek(1) === 120 || this.peek(1) === 88)) {
      this.fail("a hex number isn't read; write it in decimal", line, column);
    }
    while (isDigitByte(this.peek())) this.advance();
    if (this.peek() === 46) {
      this.advance();
      while (isDigitByte(this.peek())) this.advance();
    }
    if (this.peek() === 101 || this.peek() === 69) {
      this.advance();
      if (this.peek() === 43 || this.peek() === 45) this.advance();
      if (!isDigitByte(this.peek())) this.fail("malformed number", line, column);
      while (isDigitByte(this.peek())) this.advance();
    }
    if (isNameByte(this.peek()) || this.peek() === 46) this.fail("malformed number", line, column);
    const value = Number(String.fromCharCode(...this.bytes.subarray(start, this.pos)));
    if (!Number.isFinite(value)) this.fail("a number too large to read", line, column);
    return value;
  }

  private string(): string {
    const line = this.line;
    const column = this.column;
    const delimiter = this.advance();
    const out: number[] = [];
    for (;;) {
      const b = this.peek();
      if (b === undefined || b === CR || b === LF) this.fail("unfinished string", line, column);
      if (b === delimiter) {
        this.advance();
        break;
      }
      if (b !== 92) {
        out.push(this.advance());
        continue;
      }
      const escapeLine = this.line;
      const escapeColumn = this.column;
      this.advance();
      const c = this.peek();
      if (c === undefined) this.fail("unfinished string", line, column);
      if (c === CR || c === LF) {
        this.newline();
        out.push(LF);
      } else if (SIMPLE_ESCAPES[String.fromCharCode(c)] !== undefined) {
        this.advance();
        out.push(SIMPLE_ESCAPES[String.fromCharCode(c)]!);
      } else if (c === 120 && isHex(this.peek(1)) && isHex(this.peek(2))) {
        this.advance();
        out.push(parseInt(String.fromCharCode(this.advance(), this.advance()), 16));
      } else if (isDigitByte(c)) {
        let value = 0;
        for (let i = 0; i < 3 && isDigitByte(this.peek()); i++) value = value * 10 + this.advance() - 48;
        if (value > 255) this.fail("invalid escape sequence", escapeLine, escapeColumn);
        out.push(value);
      } else {
        this.fail("invalid escape sequence", escapeLine, escapeColumn);
      }
    }
    try {
      return decoder.decode(new Uint8Array(out));
    } catch {
      return this.fail("a string that isn't valid UTF-8", line, column);
    }
  }
}

/** Reads `return <value>` and nothing after it. */
class Parser {
  private token: Token;

  constructor(private readonly lexer: Lexer) {
    this.token = lexer.next();
  }

  private fail(message: string, token: Token = this.token): never {
    throw new ParseError(message, token.line, token.column);
  }

  private describe(token: Token): string {
    switch (token.kind) {
      case "eof":
        return "the end of the file";
      case "name":
        return `name "${token.text}"`;
      case "punct":
        return `"${token.text}"`;
      default:
        return `a ${token.kind}`;
    }
  }

  /** The token ahead, read afresh: TypeScript keeps this.token narrowed across take(). */
  private current(): Token {
    return this.token;
  }

  private take(): Token {
    const token = this.token;
    this.token = this.lexer.next();
    return token;
  }

  private isPunct(text: string): boolean {
    return this.token.kind === "punct" && this.token.text === text;
  }

  private expectPunct(text: string): void {
    if (!this.isPunct(text)) this.fail(`expected "${text}", found ${this.describe(this.token)}`);
    this.take();
  }

  chunk(): LuaValue {
    if (this.token.kind !== "name" || this.token.text !== "return") {
      this.fail(`expected return, found ${this.describe(this.token)}`);
    }
    this.take();
    const value = this.value();
    if (this.isPunct(";")) this.take();
    const end = this.current();
    if (end.kind !== "eof") this.fail(`expected the end of the file, found ${this.describe(end)}`);
    return value;
  }

  private value(): LuaValue {
    const token = this.token;
    if (token.kind === "string" || token.kind === "number") {
      this.take();
      return token.value;
    }
    if (token.kind === "name" && (token.text === "true" || token.text === "false")) {
      this.take();
      return token.text === "true";
    }
    if (this.isPunct("{")) return this.table();
    if (token.kind === "name") {
      return this.fail(`${token.text} isn't read: only strings, numbers, true, false and tables are`);
    }
    return this.fail(`expected a value, found ${this.describe(token)}`);
  }

  private table(): LuaTable {
    this.take();
    const t = new LuaTable();
    let position = 0;
    while (!this.isPunct("}")) {
      if (this.isPunct("[")) {
        this.take();
        const keyToken = this.token;
        const key = this.value();
        if (key instanceof LuaTable || typeof key === "boolean") {
          this.fail("a key must be a string or a number", keyToken);
        }
        this.expectPunct("]");
        this.expectPunct("=");
        t.fields.set(key, this.value());
      } else if (this.token.kind === "name" && !RESERVED.has(this.token.text)) {
        const name = this.token;
        this.take();
        if (!this.isPunct("=")) this.fail(`${name.text} isn't read: a name is a field only before =`, name);
        this.take();
        t.fields.set(name.text, this.value());
      } else {
        position += 1;
        t.fields.set(position, this.value());
      }
      if (this.isPunct(",") || this.isPunct(";")) {
        this.take();
      } else if (!this.isPunct("}")) {
        this.fail(`expected "," or "}", found ${this.describe(this.token)}`);
      }
    }
    this.take();
    return t;
  }
}

/**
 * The value a settings file returns, read from its text or its bytes (UTF-8), or why it is
 * unreadable with the line and column. A repeated key keeps its last value, as Lua does.
 */
export function parse(text: string | Uint8Array): ParseResult {
  const bytes = typeof text === "string" ? encoder.encode(text) : text;
  try {
    return { ok: true, value: new Parser(new Lexer(bytes)).chunk() };
  } catch (err) {
    if (!(err instanceof ParseError)) throw err;
    return {
      ok: false,
      error: `line ${err.line}, column ${err.column}: ${err.message}`,
      line: err.line,
      column: err.column,
    };
  }
}
