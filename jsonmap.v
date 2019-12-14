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
  ignore_symbols []byte
  recursive bool
  recursion_symbol string
  ignore_commas bool
  key_require_quotes bool
  allow_duplicate_keys bool
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
  return Parser {
    s       : "{}"
    options : options
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
  mut tk := TokenKind(0)
  mut s := ""
  mut builder := []byte
  if p.s[p.i] == `-` {
    s = "-"
    p.i++
  }
  if p.s[p.i] in NUMBERS {
    for {
      if builder.len == 0 && p.s[p.i] == `0` {
        builder << `0`
        p.i++
        break
      }
      str := string(builder, builder.len)
      if builder.len > 0 && (p.s[p.i] == `e` || p.s[p.i] == `E`) {
        if str.contains("e") || str.contains("E") {
          break
        }
        e_start := p.i
        p.i++
        if p.s[p.i] == `+` || p.s[p.i] == `-` {
          p.i++
        }
        if p.s[p.i] in NUMBERS {
          p.i++
          builder.push_many(p.s[e_start .. p.i].str, p.i - e_start)
          continue
        }
        return error("Unexpected `${p.s[p.i-1].str()}` at position ${p.i-1}")
      }
      if p.i > 0 && p.s[p.i] == `.` {
        if str.contains("e") || str.contains("E") || str.contains(".") {
          break
        }
        if p.s[p.i + 1] in NUMBERS {
          builder << `.`
          p.i++
          continue
        }
      }
      if !(p.s[p.i] in NUMBERS) {
        break
      }
      builder << p.s[p.i]
      p.i++
    }
    p.i--
    tk = .str
    s += string(builder, builder.len)
  }
  if s == "-" {
    return error("Unexpected `-` at position $p.i")
  }
  if s == "" {
    match p.s[p.i] {
      `{` {
        tk = .open
      }
      `}` {
        tk = .close
      }
      `:` {
        tk = .colon
      }
      `"` {
        tk = .str
        mut sb := strings.new_builder(0)
        p.i++
        for p.s[p.i] != `"` {
          sb.write_b(p.s[p.i])
          p.i++
        }
        s = sb.str()
      }
      `,` {
        tk = .comma
      }
      `t` {
        if p.s[p.i .. p.i + 4] == "true" {
          tk = .str
          s = "true"
          p.i += 3
        } else {
          return error("Unexpected symbol: `${p.s[p.i].str()}` at position $p.i")
        }
      }
      `f` {
        if p.s[p.i .. p.i + 5] == "false" {
          tk = .str
          s = "false"
          p.i += 4
        } else {
          return error("Unexpected symbol: `${p.s[p.i].str()}` at position $p.i")
        }
      }
      `n` {
        if p.s[p.i .. p.i + 4] == "null" {
          tk = .str
          s = "null"
          p.i += 3
        } else {
          return error("Unexpected symbol: `${p.s[p.i].str()}` at position $p.i")
        }
      }
      else {
        return error("Unexpected symbol: `${p.s[p.i].str()}` at position $p.i")
      }
    }
  }
  if s == "" {
    s = p.s[p.i].str()
  }
  p.i++
  p.prev = p.now
  p.now = tk
  return Token { tk, s }
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
          end := p.s.index_after("}", start)
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
        if p.prev != .str || p.current_key != "" {
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
        if p.prev == .comma || p.prev == .open {
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