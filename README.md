# Jsonmap
[V](https://github.com/vlang/v) module for converting data from Json to map[string]string

## Installation
`v install Iaiao.jsonmap`

## Usage
### Code
```v
import iaiao.jsonmap
import os

fn main() {
	file := os.read_file("jsonmap/test.json")?
	mut parser := jsonmap.default_parser()
	m := parser.parse(file)
	println(m)
}
```
### Output:
```
{
  "key1" => "value1"
  "key2" => "value2"
  "key3" => "value3"
  "key4" => "value4"
  "object.a" => "b"
  "key5" => "value5"
  "object.c" => "d"
  "object.obj.a" => "b"
  "object.e" => "f"
  "object.g" => "h"
  "object.obj.c" => "d"
  "object.obj.e" => "f"
}
```

## Parsing Options
```v
jsonmap.new_parser(jsonmap.ParserOptions{
  recursive bool
  // Inner objects {obj:{prop:val},obj2:{obj3:{prop:val}}}
  recursion_symbol string
  // Map keys is generated like object${recursion_symbol}prop. Example - object.prop
  ignore_commas bool
  // Continue parsing if comma after value is not found
  key_require_quotes bool
  // If false, it will parse keys without quotes {key: "value"}, if true it will parse {"key": "value"}
  allow_duplicate_keys bool
  // If duplicate key found, overrides it. If false, throws error
  ignore_symbols []byte
  // Symbols that have to be ignored. Default = [`\t`, `\r`, `\n`, ` `]
})
```