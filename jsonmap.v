module jsonmap

import strings

pub const (
  DEFAULT_IGNORE_SYMBOLS = [ `\t`, `\r`, `\n`, ` ` ]
  DEFAULT_RECURSIVE = true
  DEFAULT_RECURSION_SYMBOL = "."
  DEFAULT_IGNORE_COMMAS = false
  DEFAULT_KEY_REQUIRE_QUOTES = true
)

pub struct ParserOptions {
  ignore_symbols []byte
  recursive bool
  recursion_symbol string
  ignore_commas bool
  key_require_quotes bool
}

struct Parser {
pub:
  options ParserOptions
mut:
  s string
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
    ignore_symbols     : DEFAULT_IGNORE_SYMBOLS
    recursive          : DEFAULT_RECURSIVE
    recursion_symbol   : DEFAULT_RECURSION_SYMBOL
    ignore_commas      : DEFAULT_IGNORE_COMMAS
    key_require_quotes : DEFAULT_KEY_REQUIRE_QUOTES
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
    }
    `,` {
      tk = .comma
    }
    else {
      return error("Unexpected symbol: `${p.s[p.i]}` at position $p.i")
    }
  }
  mut s := p.s[p.i].str()
  p.i++
  if tk == .str {
    mut sb := strings.Builder{}
    for p.s[p.i] != `"` {
      sb.write(p.s[p.i].str())
      p.i++
    }
    p.i++
    s = sb.str()
  }
  p.prev = p.now
  p.now = tk
  return Token { tk, s }
}

pub fn (p mut Parser) parse(s string) map[string]string {
  p.s = s
  mut m := map[string]string
  mut key := ""
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
          for key2, value in map2 {
            m[key + p.options.recursion_symbol + key2] = value
          }
          key = ""
          p.i = end + 2
        } else if p.prev != .no_prev {
          m["__error__"] = "Unexpected Object at position $p.i"
          return m
        }
      }
      .colon {
        if p.prev != .str || key == "" {
          m["__error__"] = "Unexpected colon at position $p.i"
          return m
        }
      }
      .comma {
        println(p.prev.str())
        if p.prev != .str || key != "" {
          m["__error__"] = "Unexpected comma at position $p.i"
          return m
        }
      }
      .close {
        if p.prev == .open {
          return m
        }
        if p.prev != .str || key != ""  {
          m["__error__"] = "Unexpected end of object at position $p.i"
        }
        return m
      }
      .str {
        if p.prev == .comma || p.prev == .open {
          key = token.str
        } else if p.prev == .colon && key != "" {
          m[key] = token.str
          key = ""
        } else {
          m["__error__"] = "Unexpected string at position $p.i"
          return m
        }
      }
      else {
        m["__error__"] = "Unexpected error. This should never happen."
        return m
      }
    }
  }
  return m
}