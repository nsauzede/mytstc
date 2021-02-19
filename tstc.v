module main

import strings
import os

const (
	print_input  = 0x01
	print_tokens = 0x02
	print_ast    = 0x04
	print_newast = 0x08
	print_output = 0x10
	output_c     = 0x20
	output_nelua = 0x40
	output_v     = 0x80
	output_mask  = output_c | output_nelua | output_v
)

struct Context {
mut:
	flags        int
	source       string
	input_file   string
	output_file  string
	use_obj      bool = true
	use_add      bool
	use_subtract bool
	use_multiply bool
	use_divide   bool
	use_print    bool
	use_list     bool
}

struct Paren {
	value string
}

struct Name {
	value string
}

struct Number {
	value string
}

struct String {
	value string
}

type Token = Name | Number | Paren | String

struct Program {
mut:
	ctx  &ASTNode = voidptr(0)
	body []ASTNode
}

struct Call {
mut:
	ctx    &ASTNode = voidptr(0)
	name   string
	params []ASTNode
}

struct NumberLiteral {
	value string
}

struct StringLiteral {
	value string
}

struct ExpressionStatement {
	expression ASTNode
}

struct CallExpression {
mut:
	callee    ASTNode
	arguments []ASTNode
}

struct Identifier {
	name string
}

type ASTNode = Call | CallExpression | ExpressionStatement | Identifier | NumberLiteral |
	Program | StringLiteral

fn print_tokens(tokens []Token) {
	for t in tokens {
		print('$t.type_name()\t')
		match t {
			Paren, Name, Number, String { println('$t.value') }
		}
	}
}

fn print_ast_r(node ASTNode, nest int) {
	for i := 0; i < nest; i++ {
		print('\t')
	}
	match node {
		Program {
			print('${typeof(node).name}')
			println(' body:$node.body.len=\\')
			for e in node.body {
				print_ast_r(e, nest + 1)
			}
		}
		NumberLiteral {
			print('${typeof(node).name}')
			println(' value=$node.value')
		}
		StringLiteral {
			print('${typeof(node).name}')
			println(' value=$node.value')
		}
		Call {
			print('${typeof(node).name}')
			println(' name=$node.name params=\\')
			for e in node.params {
				print_ast_r(e, nest + 1)
			}
		}
		ExpressionStatement {
			print('${typeof(node).name}')
			print_ast_r(node.expression, nest + 1)
		}
		CallExpression {
			print('${typeof(node).name}')
			print(' callee=')
			print_ast_r(node.callee, 0)
			println(' arguments:$node.arguments.len=\\')
			for e in node.arguments {
				print_ast_r(e, nest + 1)
			}
		}
		Identifier {
			print('${typeof(node).name}')
			print(' name=$node.name')
		}
	}
}

fn print_ast(ast ASTNode) {
	print_ast_r(ast, 0)
}

fn is_space(c byte) bool {
	return c == ` ` || c == `\n`
}

fn is_number(c byte) bool {
	return c >= `0` && c <= `9`
}

fn is_letter(c byte) bool {
	return (c >= `a` && c <= `z`) || c == `+` || c == `-` || c == `*` || c == `/`
}

fn is_alnum(c byte) bool {
	return is_letter(c) || is_number(c)
}

fn tokenizer(input string) []Token {
	mut current := 0
	mut tokens := []Token{}
	// println('input:$input.len')
	for current < input.len {
		// println('current=$current')
		mut c := input[current]
		// println('got c=$c (${c:c})')
		if c == `(` {
			// println('paren(')
			current++
			tokens << Paren{'('}
		} else if c == `)` {
			// println('paren)')
			tokens << Paren{')'}
			current++
		} else if is_space(c) {
			current++
		} else if is_number(c) {
			// println('number')
			mut value := strings.new_builder(256)
			for is_number(c) {
				value.write_b(c)
				current++
				if current >= input.len {
					break
				}
				c = input[current]
			}
			tokens << Number{value.str()}
		} else if c == `\'` {
			// println('quote')
			mut value := strings.new_builder(256)
			mut started := false
			for {
				current++
				if current >= input.len {
					break
				}
				c = input[current]
				if is_space(c) {
					if started {
						break
					} else {
						continue
					}
				}
				started = true
				value.write_b(c)
			}
			tokens << String{value.str()}
		} else if c == `"` {
			// println('doublequote')
			mut value := strings.new_builder(256)
			for {
				current++
				if current >= input.len {
					break
				}
				c = input[current]
				if c == `"` {
					current++
					break
				}
				value.write_b(c)
			}
			tokens << String{value.str()}
		} else if is_alnum(c) {
			// println('alnum')
			mut value := strings.new_builder(256)
			for is_alnum(c) {
				value.write_b(c)
				current++
				if current >= input.len {
					break
				}
				// println('current=$current')
				c = input[current]
				// println('got c=$c (${c:c})')
			}
			tokens << Name{value.str()}
		} else {
			panic("I don't know what this character is: `${c:c}`")
		}
	}
	return tokens
}

struct MyInt {
mut:
	value int
}

fn (mut ctx Context) walk(mut current_ MyInt, tokens []Token) &ASTNode {
	token0 := tokens[current_.value]
	match token0 {
		Number {
			n := &NumberLiteral{
				value: token0.value
			}
			current_.value++
			return n
		}
		String {
			n := &StringLiteral{
				value: token0.value
			}
			current_.value++
			return n
		}
		Paren {
			if token0.value == '(' {
				mut current := current_
				current.value++
				name := tokens[current.value] as Name
				mut node := &Call{
					name: name.value
				}
				match name.value {
					'+' { ctx.use_add = true }
					'-' { ctx.use_subtract = true }
					'*' { ctx.use_multiply = true }
					'/' { ctx.use_divide = true }
					'write', 'print' { ctx.use_print = true }
					'list' { ctx.use_list = true }
					else {}
				}
				current.value++
				for {
					token := tokens[current.value]
					match token {
						Paren {
							if token.value == ')' {
								break
							}
						}
						else {}
					}
					mut child := &ASTNode{}
					child = ctx.walk(mut &current, tokens)
					node.params << child
				}
				current_.value = current.value + 1
				return node
			} else {
				panic('Paren not (')
			}
		}
		else {
			panic('walk: Token type error: $token0')
		}
	}
	panic('walk: Type error !')
}

fn (mut ctx Context) parser(tokens []Token) ASTNode {
	mut ast := Program{}
	mut current := MyInt{}
	for current.value < tokens.len {
		mut node := &ASTNode{}
		node = ctx.walk(mut &current, tokens)
		ast.body << node
	}
	return ast
}

fn traverse_node(node ASTNode, parent &ASTNode) ASTNode {
	if parent != voidptr(0) {
		mut child := ASTNode{}
		match mut node {
			NumberLiteral {
				child = NumberLiteral{
					value: node.value
				}
			}
			StringLiteral {
				child = StringLiteral{
					value: node.value
				}
			}
			Call {
				mut expression := &CallExpression{
					callee: Identifier{
						name: node.name
					}
				}
				node.ctx = expression
				if parent is Call {
					child = expression
				} else {
					child = ExpressionStatement{
						expression: expression
					}
				}
			}
			else {
				panic('child node is unknown ? $node.type_name()')
			}
		}
		mut ctx := &ASTNode{}
		match mut parent {
			Program, Call {
				ctx = parent.ctx
			}
			else {
				panic('parent is unknown ? ${typeof(parent).name}')
			}
		}
		match mut ctx {
			Program {
				ctx.body << child
			}
			CallExpression {
				ctx.arguments << child
			}
			else {
				panic('unknown program parent ctx $ctx.type_name()')
			}
		}
	} else {
		match node {
			Program {}
			else {
				panic('null parent for node ${typeof(node).name}')
			}
		}
	}
	match mut node {
		Program {
			for mut e in node.body {
				e = traverse_node(e, &node)
			}
		}
		Call {
			for mut e in node.params {
				e = traverse_node(e, &node)
			}
		}
		NumberLiteral, StringLiteral {}
		else {
			panic('node is unknown ? ${typeof(node).name}')
		}
	}
	return node
}

fn transformer(mut ast ASTNode) (ASTNode, ASTNode) {
	mut newast := &ASTNode(Program{})
	if mut ast is Program {
		ast.ctx = voidptr(newast)
	}
	ast = traverse_node(ast, voidptr(0))
	return *ast, *newast
}

fn (ctx Context) code_generator_c(node ASTNode) string {
	mut sb := strings.new_builder(1024)
	use_obj := true // this is because C doesn't handle sum types natively
	match node {
		Program {
			if ctx.use_print {
				sb.writeln('#include <stdio.h>')
			}
			if use_obj {
				sb.writeln('typedef enum{obj_f,obj_i,obj_s} obj_t;')
				sb.writeln('typedef struct{obj_t t;union{float f;int i;char *s;};} obj;')
				sb.writeln('#define F(v)(obj){obj_f,.f=v}')
				sb.writeln('#define S(v)(obj){obj_s,.s=v}')
			}
			if ctx.use_add {
				sb.writeln('obj add(obj a,obj b){obj r=F(0);r.f=a.f+b.f;return r;}')
			}
			if ctx.use_subtract {
				sb.writeln('
				obj subtract(obj a, obj b) {obj r=F(0);r.f=a.f-b.f;return r;}')
			}
			if ctx.use_multiply {
				sb.writeln('obj multiply(obj a, obj b) {obj r=F(0);r.f=a.f*b.f;return r;}')
			}
			if ctx.use_divide {
				sb.writeln('obj divide(obj a, obj b) {obj r=F(0);r.f=a.f/b.f;return r;}')
			}
			if ctx.use_print {
				sb.writeln('void println(obj a){
	if (a.t == obj_f){
		printf("%f\\n", (double)a.f);
	}
	else if (a.t == obj_s){
		printf("%s\\n", a.s);
	}
	else{
		printf("unknown obj type %d\\n", a.t);
	}
}')
			}
			sb.writeln('int main() {')
			for e in node.body {
				sb.write(ctx.code_generator_c(e))
			}
			sb.writeln('\treturn 0;')
			sb.writeln('}')
		}
		NumberLiteral {
			sb.write('F($node.value)')
		}
		StringLiteral {
			sb.write('S("$node.value")')
		}
		ExpressionStatement {
			sb.write('\t')
			sb.write(ctx.code_generator_c(node.expression))
			sb.writeln(';')
		}
		Identifier {
			name := match node.name {
				'+' { 'add' }
				'-' { 'subtract' }
				'*' { 'multiply' }
				'/' { 'divide' }
				'print', 'write' { 'println' }
				else { node.name }
			}
			sb.write(name)
		}
		CallExpression {
			sb.write(ctx.code_generator_c(node.callee))
			sb.write('(')
			for i, e in node.arguments {
				if i > 0 {
					sb.write(', ')
				}
				sb.write(ctx.code_generator_c(e))
			}
			sb.write(')')
		}
		else {
			panic('Code gen Type error: `$node.type_name()`')
		}
	}
	output := sb.str()
	unsafe { sb.free() }
	return output
}

fn (ctx Context) code_generator_nelua(node ASTNode) string {
	mut sb := strings.new_builder(1024)
	match node {
		Program {
			if ctx.use_add {
				sb.writeln('local function add(a: float32, b: float32): float32 return a + b end')
			}
			if ctx.use_subtract {
				sb.writeln('local function subtract(a: float32, b: float32): float32 return a - b end')
			}
			if ctx.use_multiply {
				sb.writeln('local function multiply(a: float32, b: float32): float32 return a * b end')
			}
			if ctx.use_divide {
				sb.writeln('local function divide(a: float32, b: float32): float32 return a / b end')
			}
			for e in node.body {
				sb.write(ctx.code_generator_nelua(e))
			}
		}
		NumberLiteral {
			sb.write(node.value)
		}
		StringLiteral {
			sb.write('"$node.value"')
		}
		ExpressionStatement {
			sb.write(ctx.code_generator_nelua(node.expression))
			sb.writeln('')
		}
		Identifier {
			name := match node.name {
				'+' { 'add' }
				'-' { 'subtract' }
				'*' { 'multiply' }
				'/' { 'divide' }
				'write' { 'print' }
				else { node.name }
			}
			sb.write(name)
		}
		CallExpression {
			sb.write(ctx.code_generator_nelua(node.callee))
			sb.write('(')
			for i, e in node.arguments {
				if i > 0 {
					sb.write(', ')
				}
				sb.write(ctx.code_generator_nelua(e))
			}
			sb.write(')')
		}
		else {
			panic('Code gen Type error: `$node.type_name()`')
		}
	}
	output := sb.str()
	unsafe { sb.free() }
	return output
}

fn (ctx Context) code_generator_v(node ASTNode) string {
	mut sb := strings.new_builder(1024)
	match node {
		Program {
			if ctx.use_obj {
				sb.writeln('type Obj=u64|f32|int|string')
			}
			if ctx.use_add {
				sb.writeln("
fn add(a...Obj)Obj{mut r:= Obj{}
	for i, e in a {
		if i == 0 {
			r = e
			continue
		}match mut r{
			f32{match mut e{
				f32{r=r+e}
				else{panic('loop f32 \$e.type_name()')}}}
			int{match mut e{
				int{r=r+e}
				else{panic('loop int \$e.type_name()')}}}
			else{panic('loop unknown type \$r.type_name()')}}}
	return r}
")
			}
			if ctx.use_subtract {
				sb.writeln("
fn subtract(a...Obj)Obj{mut r:=Obj{}
	for i, e in a {
		if i == 0 {
			r = e
			continue
		}match mut r{
			f32{match mut e{
				f32{r=r-e}
				else{panic('loop f32 \$e.type_name()')}}}
			int{match mut e{
				int{r=r-e}
				else{panic('loop int \$e.type_name()')}}}
			else{panic('loop unknown type \$r.type_name()')}}}
	return r}
")
			}
			if ctx.use_multiply {
				sb.writeln("
fn multiply(a...Obj)Obj{mut r:=Obj{}
	for i, e in a {
		if i == 0 {
			r = e
			continue
		}match mut r{
			f32{match mut e{
				f32{r=r*e}
				else{panic('loop f32 \$e.type_name()')}}}
			int{match mut e{
				int{r=r*e}
				else{panic('loop int \$e.type_name()')}}}
			else{panic('loop unknown type \$r.type_name()')}}}
	return r}
")
			}
			if ctx.use_divide {
				sb.writeln("
fn divide(a...Obj)Obj{mut r:=Obj{}
	for i, e in a {
		if i == 0 {
			r = e
			continue
		}match mut r{
			f32{match mut e{
				f32{r=r/e}
				else{panic('loop f32 \$e.type_name()')}}}
			int{match mut e{
				int{r=r/e}
				else{panic('loop int \$e.type_name()')}}}
			else{panic('loop unknown type \$r.type_name()')}}}
	return r}
")
			}
			if ctx.use_list {
				sb.writeln('fn list(a...Obj)[]Obj{mut r:=[]Obj{}for e in a{r<<e}return r}')
			}
			for e in node.body {
				sb.write(ctx.code_generator_v(e))
			}
		}
		NumberLiteral {
			sb.write('f32($node.value)')
		}
		StringLiteral {
			sb.write("'$node.value'")
		}
		ExpressionStatement {
			sb.write(ctx.code_generator_v(node.expression))
			sb.writeln('')
		}
		Identifier {
			name := match node.name {
				'+' { 'add' }
				'-' { 'subtract' }
				'*' { 'multiply' }
				'/' { 'divide' }
				'print', 'write' { 'println' }
				else { node.name }
			}
			sb.write(name)
		}
		CallExpression {
			sb.write(ctx.code_generator_v(node.callee))
			sb.write('(')
			for i, e in node.arguments {
				if i > 0 {
					sb.write(', ')
				}
				sb.write(ctx.code_generator_v(e))
			}
			sb.write(')')
		}
		else {
			panic('Code gen Type error: `$node.type_name()`')
		}
	}
	output := sb.str()
	unsafe { sb.free() }
	return output
}

fn (mut ctx Context) compiler() {
	flags := ctx.flags
	if '' != ctx.input_file {
		ctx.source = os.read_file(ctx.input_file) or { panic("can't read $ctx.input_file") }
	}
	if 0 != ctx.flags & print_input {
		println('input=\\\n$ctx.source')
	}
	tokens := tokenizer(ctx.source)
	if 0 != flags & print_tokens {
		println('tokens=\\\n')
		print_tokens(tokens)
	}
	mut ast := ctx.parser(tokens)
	if 0 != flags & print_ast {
		print_ast(ast)
	}
	mut newast := ASTNode{}
	ast, newast = transformer(mut &ast)
	if 0 != flags & print_newast {
		print_ast(newast)
	}
	mut output := ''
	if 0 != flags & output_c {
		output = ctx.code_generator_c(newast)
	}
	if 0 != flags & output_nelua {
		output = ctx.code_generator_nelua(newast)
	}
	if 0 != flags & output_v {
		output = ctx.code_generator_v(newast)
	}
	if 0 != ctx.flags & print_output {
		// println('output=\\\n$output')
		println('$output')
	}
	if '' != ctx.output_file {
		mut fout := os.create(ctx.output_file) or { os.File{
			cfile: 0
		} }
		fout.write_string(output) or { }
		fout.close()
	}
}

fn usage() {
	prog := os.args[0]
	println('Usage: $prog [options]')
	println('')
	println('Options:')
	println('   --help\t\tDisplay this information.')
	println('   -x "CODE"\t\tUse provided CODE as source input.')
	println('   -o <file>"\t\tPlace the output into <file>.')
	println('   --print-input\tDisplay the source input.')
	println('   --print-tokens\tDisplay the tokens.')
	println('   --print-ast\t\tDisplay the ast.')
	println('   --print-newast\tDisplay the newast.')
	println('   --print-output\tDisplay the generated output.')
	println('   --output-c\t\tGenerates C.')
	println('   --output-nelua\tGenerates Nelua.')
	println('   --output-v\t\tGenerates V.')
	println('')
	println('For more information, please see:')
	println('https://github.com/nsauzede/mytstc')
}

fn (mut ctx Context) set_args() {
	mut set_input := false
	mut set_output_file := false
	for a in os.args[1..] {
		if set_input {
			set_input = false
			ctx.source = a
			println('Just read input="$ctx.source"')
		} else if set_output_file {
			set_output_file = false
			ctx.output_file = a
		} else if a == '--help' {
			usage()
			exit(0)
		} else if a == '-x' {
			set_input = true
		} else if a == '-o' {
			set_output_file = true
		} else if a == '--print-input' {
			ctx.flags |= print_input
		} else if a == '--print-tokens' {
			ctx.flags |= print_tokens
		} else if a == '--print-ast' {
			ctx.flags |= print_ast
		} else if a == '--print-newast' {
			ctx.flags |= print_newast
		} else if a == '--print-output' {
			ctx.flags |= print_output
		} else if a == '--output-c' {
			ctx.flags = (ctx.flags & ~output_mask) | output_c
		} else if a == '--output-nelua' {
			ctx.flags = (ctx.flags & ~output_mask) | output_nelua
		} else if a == '--output-v' {
			ctx.flags = (ctx.flags & ~output_mask) | output_v
		} else {
			// println('a="$a" input_file="$ctx.input_file"')
			if '' != ctx.input_file {
				panic('Input file set more than one time')
			}
			ctx.input_file = a
		}
	}
	if '' == ctx.output_file {
		ctx.flags |= print_output
	}
}

fn main() {
	mut ctx := Context{
		flags: 0 | 0 * print_input | 0 * print_tokens | 0 * print_ast | 0 * print_newast | 0 * print_output | 1 * output_c
		source: '(write(+ (* (/ 9 5) 60) 32))'
	}
	ctx.set_args()
	ctx.compiler()
}
