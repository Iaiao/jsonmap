# Jsonmap
[V](https://github.com/vlang/v) module for converting data from Json to map[string]string

## Installation
`v install Iaiao.jsonmap`

## Usage
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