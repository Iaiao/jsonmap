module jsonmap

import strings

pub const (
  DEFAULT_IGNORE_SYMBOLS = [ `\t`, `\r`, `\n`, ` ` ]
  DEFAULT_RECURSIVE = true
  DEFAULT_RECURSION_SYMBOL = "."
  DEFAULT_IGNORE_COMMAS = false
  DEFAULT_KEY_REQUIRE_QUOTES = true
  DEFAULT_ALLOW_DUPLICATE_KEYS = false
)

const (
  NUMBERS = [ `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `0` ]
)

pub struct ParserOptions {
pub:
  recursive bool
  recursion_symbol string
  ignore_commas bool
  key_require_quotes bool
  allow_duplicate_keys bool
mut:
  ignore_symbols []byte
}

struct Parser {
pub:
  options ParserOptions
mut:
  s string
  current_key string
  prev TokenKind
  now TokenKind
  i int
}

pub struct Token {
  kind TokenKind
  str string
}

pub enum TokenKind {
  no_prev open str colon comma close
}

pub fn default_parser() Parser {
  return new_parser(ParserOptions{
    ignore_symbols       : DEFAULT_IGNORE_SYMBOLS
    recursive            : DEFAULT_RECURSIVE
    recursion_symbol     : DEFAULT_RECURSION_SYMBOL
    ignore_commas        : DEFAULT_IGNORE_COMMAS
    key_require_quotes   : DEFAULT_KEY_REQUIRE_QUOTES
    allow_duplicate_keys : DEFAULT_ALLOW_DUPLICATE_KEYS
  })
}

pub fn new_parser(options ParserOptions) Parser {
  mut _options := options
  if _options.ignore_commas {
    _options.ignore_symbols << `,`
  }
  return Parser {
    s       : "{}"
    options : _options
    prev    : .no_prev
    now     : .no_prev
    i       : 0
  }
}

fn (p mut Parser) next() ?Token {
  if p.s[p.i] in p.options.ignore_symbols {
    p.i++
    return p.next()
  }
  p.prev = p.now
  p.now = TokenKind(0)
  mut s := ""

  start := p.i

  if s == "" && p.s[p.i] == `-` {
    s = "-"
    p.i++
  }
  if (s == "" || s == "-") && p.s[p.i] in NUMBERS {
    for {
      before := p.s[start .. p.i]
      if before.len == 0 && p.s[p.i] == `0` {
        // do not allow numbers with leading zeros
        p.i++
        break
      }
      if before.len > 0 && (p.s[p.i] == `e` || p.s[p.i] == `E`) {
        if before.contains("e") || before.contains("E") {
          // do not allow multiple `E`s
          break
        }
        p.i++
        if p.s[p.i] == `+` || p.s[p.i] == `-` {
          // allow E+n, E-n, En ==
          p.i++
        }
        if p.s[p.i] in NUMBERS {
          p.i++
          continue
        }
        return error("Unexpected `${p.s[p.i-1].str()}` at position ${p.i-1}")
      }
      if p.i > 0 && p.s[p.i] == `.` {
        // do not allow leading `.`
        if before.contains("e") || before.contains("E") || before.contains(".") {
          // do not allow `.` after `E` and multiple `.`s
          break
        }
        if p.s[p.i + 1] in NUMBERS {
          // do not allow trailing `.`
          p.i++
          continue
        }
      }
      if !(p.s[p.i] in NUMBERS) {
        break
      }
      p.i++
    }
    p.i--
    p.now = .str
    s += p.s[start .. p.i]
  }
  if s == "-" {
    return error("Unexpected `-` at position $p.i")
  }
  if s == "" {
    match p.s[p.i] {
      `{` {
        p.now = .open
      }
      `}` {
        p.now = .close
      }
      `:` {
        p.now = .colon
      }
      `"` {
        p.now = .str
        mut sb := strings.new_builder(0)
        p.i++
        for p.s[p.i] != `"` {
          sb.write_b(p.s[p.i])
          p.i++
        }
        s = sb.str()
      }
      `,` {
        p.now = .comma
      }
      `t` {
        if p.s[p.i .. p.i + 4] == "true" {
          p.now = .str
          s = "true"
          p.i += 3
        } else {
          return error("Unexpected symbol: `${p.s[p.i].str()}` at position $p.i")
        }
      }
      `f` {
        if p.s[p.i .. p.i + 5] == "false" {
          p.now = .str
          s = "false"
          p.i += 4
        } else {
          return error("Unexpected symbol: `${p.s[p.i].str()}` at position $p.i")
        }
      }
      `n` {
        if p.s[p.i .. p.i + 4] == "null" {
          p.now = .str
          s = "null"
          p.i += 3
        } else {
          return error("Unexpected symbol: `${p.s[p.i].str()}` at position $p.i")
        }
      }
      else {
        if s == "" && (p.prev == .comma || ((p.prev == .str || p.prev == .open) && p.options.ignore_commas)) && p.s[p.i] != `"` && !p.options.key_require_quotes {
          for p.s[p.i] != `:` {
            p.i++
          }
          p.i--
          s = p.s[start .. p.i + 1]
          p.now = .str
        } else {
          return error("Unexpected symbol: `${p.s[p.i].str()}` at position $p.i")
        }
      }
    }
  }
  if s == "" {
    s = p.s[p.i].str()
  }
  p.i++
  return Token { p.now, s }
}

pub fn (p mut Parser) parse(s string) map[string]string {
  p.s = s
  mut m := map[string]string
  p.current_key = ""
  for p.i < s.len {
    token := p.next() or {
      m["__error__"] = err
      return m
    }
    match token.kind {
      .open {
        if p.prev == .colon && p.options.recursive {
          start := p.i
          mut end := 0
          mut brackets := 1
          for i := start; i < p.s.len; i++ {
            if p.s[i] == `{` {
              brackets++
            }
            if p.s[i] == `}` {
              brackets--
            }
            if brackets == 0 {
              end = i
              break
            }
          }
          str := p.s[start - 1 .. end + 1]
          mut parser := new_parser(p.options)
          map2 := parser.parse(str)
          if "__error__" in map2 {
            m["__error__"] = map2["__error__"] + " (in Object that starts at $start)"
            return m
          }
          for key, value in map2 {
            m[p.current_key + p.options.recursion_symbol + key] = value
          }
          p.current_key = ""
          p.i = end + 2
        } else if p.prev != .no_prev {
          m["__error__"] = "Unexpected Object at position $p.i"
          return m
        }
      }
      .colon {
        if p.prev != .str || p.current_key == "" {
          m["__error__"] = "Unexpected colon at position $p.i"
          return m
        }
      }
      .comma {
        if (p.prev != .str && (p.prev != .comma && p.options.ignore_commas)) || p.current_key != "" {
          m["__error__"] = "Unexpected comma at position $p.i"
          return m
        }
      }
      .close {
        if p.prev == .open {
          return m
        }
        if p.prev != .str || p.current_key != ""  {
          m["__error__"] = "Unexpected end of object at position $p.i"
        }
        return m
      }
      .str {
        if p.prev == .comma || p.prev == .open || (p.prev == .str && p.options.ignore_commas) {
          p.current_key = token.str
          if m[p.current_key] != "" && !p.options.allow_duplicate_keys {
            m["__error__"] = "Duplicate key $p.current_key at $p.i"
            return m
          }
        } else if p.prev == .colon && p.current_key != "" {
          m[p.current_key] = token.str
          p.current_key = ""
        } else {
          m["__error__"] = "Unexpected string at position $p.i"
          return m
        }
      }
      .no_prev {}
      else {
        m["__error__"] = "Unexpected error. This should never happen."
        return m
      }
    }
  }
  return m
}