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
	use_add      bool
	use_subtract bool
	use_multiply bool
	use_divide   bool
	use_print    bool
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

struct Callee {
	@type string
	name  string
}

struct ASTNodeGeneric {
mut:
	@type string
	ctx   &ASTNode = voidptr(0)
	arr   []&ASTNode
}

struct Program {
mut:
	@type string   = 'Program'
	ctx   &ASTNode = voidptr(0)
	body  []&ASTNode
}

struct NumberLiteral {
	@type string   = 'NumberLiteral'
	ctx   &ASTNode = voidptr(0)
	arr   []&ASTNode
	value string
}

struct StringLiteral {
	@type string   = 'StringLiteral'
	ctx   &ASTNode = voidptr(0)
	arr   []&ASTNode
	value string
}

struct CallExpression {
mut:
	@type  string   = 'CallExpression'
	ctx    &ASTNode = voidptr(0)
	params []&ASTNode
	name   string
}

struct ExpressionStatement {
mut:
	@type      string   = 'ExpressionStatement'
	ctx        &ASTNode = voidptr(0)
	arr        []&ASTNode
	expression &ASTNode = voidptr(0)
}

struct Call {
mut:
	@type     string   = 'Call'
	ctx       &ASTNode = voidptr(0)
	arguments []&ASTNode
	callee    Callee
}

union ASTNode {
mut:
	u                   ASTNodeGeneric
	program             Program
	numberliteral       NumberLiteral
	stringliteral       StringLiteral
	callexpression      CallExpression
	expressionstatement ExpressionStatement
	call                Call
}

fn print_tokens(tokens []Token) {
	for t in tokens {
		print('$t.type_name()\t')
		match t {
			Paren, Name, Number, String { println('$t.value') }
		}
	}
}

fn print_ast_r(node ASTNode, nest int) {
	unsafe {
		for i := 0; i < nest; i++ {
			print('\t')
		}
		print('${node.u.@type}')
		if node.u.@type == 'Program' {
			println(' body=\\')
			for e in node.program.body {
				print_ast_r(e, nest + 1)
			}
		}
		if node.u.@type == 'NumberLiteral' || node.u.@type == 'StringLiteral' {
			println(' value=$node.numberliteral.value')
		}
		if node.u.@type == 'CallExpression' {
			println(' name=$node.callexpression.name params=\\')
			for e in node.callexpression.params {
				print_ast_r(e, nest + 1)
			}
		}
		if node.u.@type == 'ExpressionStatement' {
			print_ast_r(node.expressionstatement.expression, nest + 1)
		}
		if node.u.@type == 'Call' {
			print(' callee type=${node.call.callee.@type}')
			print(' name=$node.call.callee.name')
			println(' arguments=\\')
			for e in node.call.arguments {
				print_ast_r(e, nest + 1)
			}
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

fn tokenizer(input string) []Token {
	mut current := 0
	mut tokens := []Token{}
	for current < input.len {
		mut c := input[current]
		if c == `(` {
			tokens << Paren{'('}
			current++
			continue
		}
		if c == `)` {
			tokens << Paren{')'}
			current++
			continue
		}
		if is_space(c) {
			current++
			continue
		}
		if is_number(c) {
			mut value := strings.new_builder(256)
			for is_number(c) {
				value.write_b(c)
				current++
				c = input[current]
			}
			tokens << Number{value.str()}
			continue
		}
		if is_letter(c) {
			mut value := strings.new_builder(256)
			for is_letter(c) {
				value.write_b(c)
				current++
				c = input[current]
			}
			tokens << Name{value.str()}
			continue
		}
		panic("I don't know what this character is: `${c:c}`")
	}
	return tokens
}

fn (mut ctx Context) walk(current0 int, tokens []Token) (int, &ASTNode) {
	mut current := current0
	token := &tokens[current]
	if token is Number {
		return current + 1, &ASTNode{
			numberliteral: {
				value: token.value
			}
		}
	}
	if token is String {
		return current + 1, &ASTNode{
			stringliteral: {
				value: token.value
			}
		}
	}
	if token is Paren {
		if token.value == '(' {
			current++
			token2 := &tokens[current]
			if token2 is Name {
				mut node := &ASTNode{
					callexpression: {
						name: token2.value
					}
				}
				match token2.value {
					'+' { ctx.use_add = true }
					'-' { ctx.use_subtract = true }
					'*' { ctx.use_multiply = true }
					'/' { ctx.use_divide = true }
					'write', 'print' { ctx.use_print = true }
					else {}
				}
				current++
				for {
					token3 := &tokens[current]
					if token3 is Paren {
						if token3.value == ')' {
							break
						}
					}
					mut child := &ASTNode{}
					current, child = ctx.walk(current, tokens)
					unsafe { node.callexpression.params << child }
				}
				return current + 1, node
			}
		}
	}
	panic('walk: Type error: `$token.type_name()`')
}

fn (mut ctx Context) parser(tokens []Token) ASTNode {
	mut ast := ASTNode{
		program: {}
	}
	mut current := 0
	for current < tokens.len {
		mut node := &ASTNode{}
		current, node = ctx.walk(current, tokens)
		unsafe { ast.program.body << node }
	}
	return ast
}

fn traverse_node(mut node ASTNode, parent &ASTNode) {
	unsafe {
		println('traverse_node.. node=${voidptr(node)}')
		if node.u.@type == 'NumberLiteral' {
			if parent != voidptr(0) {
				if parent.u.ctx != voidptr(0) {
					parent.u.ctx.u.arr << &ASTNode{
						numberliteral: {
							value: node.numberliteral.value
						}
					}
				}
			}
		}
		if node.u.@type == 'CallExpression' {
			mut expression := &ASTNode{
				call: {
					callee: {
						@type: 'Identifier'
						name: node.callexpression.name
					}
				}
			}
			node.u.ctx = expression
			if parent.u.@type != 'CallExpression' {
				expression2 := &ASTNode{
					expressionstatement: {
						expression: expression
					}
				}
				parent.u.ctx.u.arr << expression2
			} else {
				parent.u.ctx.u.arr << expression
			}
		}
		if node.u.@type == 'Program' {
			println(' traverse Prog ctx=${voidptr(node.u.ctx)} $node.program.body.len')
			for e in node.program.body {
				if e.u.@type == 'Program' {
					println('prog ctx=${voidptr(e.u.ctx)}')
				}
				if e.u.@type == 'CallExpression' {
					println('callex ctx=${voidptr(e.u.ctx)}')
				}
				traverse_node(mut e, node)
				if e.u.@type == 'Program' {
					println('prog ctx=${voidptr(e.u.ctx)}')
				}
				if e.u.@type == 'CallExpression' {
					println('callex ctx=${voidptr(e.u.ctx)}')
				}
			}
		} else if node.u.@type == 'CallExpression' {
			println(' traverse Callex')
			for e in node.callexpression.params {
				traverse_node(mut e, node)
			}
		} else if node.u.@type == 'NumberLiteral' || node.u.@type == 'StringLiteral' {
			// nothing special
		} else {
			panic('Type error: `${node.u.@type}`')
		}
	}
}

fn traverser(mut ast ASTNode) {
	traverse_node(mut ast, voidptr(0))
}

fn transformer(mut ast ASTNode) ASTNode {
	mut newast := ASTNode{
		program: {}
	}
	unsafe {
		ast.u.ctx = &newast
	}
	traverser(mut ast)
	return newast
}

fn (ctx Context) code_generator_c(node ASTNode) string {
	unsafe {
		mut sb := strings.new_builder(1024)
		if node.u.@type == 'Program' {
			if ctx.use_print {
				sb.writeln('#include <stdio.h>')
			}
			if ctx.use_add {
				sb.writeln('float add(float a, float b) {return a + b;}')
			}
			if ctx.use_subtract {
				sb.writeln('float subtract(float a, float b) {return a - b;}')
			}
			if ctx.use_multiply {
				sb.writeln('float multiply(float a, float b) {return a * b;}')
			}
			if ctx.use_divide {
				sb.writeln('float divide(float a, float b) {return a / b;}')
			}
			if ctx.use_print {
				sb.writeln('void println(float a) {printf("%f\\n", (double)a);}')
			}
			sb.writeln('int main() {')
			for e in node.program.body {
				sb.write(ctx.code_generator_c(e))
			}
			sb.writeln('\treturn 0;')
			sb.writeln('}')
		} else if node.u.@type == 'NumberLiteral' {
			sb.write(node.numberliteral.value)
		} else if node.u.@type == 'ExpressionStatement' {
			sb.write('\t')
			sb.write(ctx.code_generator_c(node.expressionstatement.expression))
			sb.writeln(';')
		} else if node.u.@type == 'Call' {
			name := match node.call.callee.name {
				'print' { 'println' }
				'write' { 'println' }
				'+' { 'add' }
				'-' { 'subtract' }
				'*' { 'multiply' }
				'/' { 'divide' }
				else { node.call.callee.name }
			}
			sb.write(name)
			sb.write('(')
			for i, e in node.call.arguments {
				if i > 0 {
					sb.write(', ')
				}
				sb.write(ctx.code_generator_c(e))
			}
			sb.write(')')
		} else {
			panic('Code gen Type error: `${node.u.@type}`')
		}
		output := sb.str()
		sb.free()
		return output
	}
}

fn (ctx Context) code_generator_nelua(node ASTNode) string {
	unsafe {
		mut sb := strings.new_builder(1024)
		if node.u.@type == 'Program' {
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
			for e in node.program.body {
				sb.write(ctx.code_generator_nelua(e))
			}
		} else if node.u.@type == 'NumberLiteral' {
			sb.write(node.numberliteral.value)
		} else if node.u.@type == 'ExpressionStatement' {
			sb.write(ctx.code_generator_nelua(node.expressionstatement.expression))
			sb.writeln('')
		} else if node.u.@type == 'Call' {
			name := match node.call.callee.name {
				'+' { 'add' }
				'-' { 'subtract' }
				'*' { 'multiply' }
				'/' { 'divide' }
				'write' { 'print' }
				else { node.call.callee.name }
			}
			sb.write(name)
			sb.write('(')
			for i, e in node.call.arguments {
				if i > 0 {
					sb.write(', ')
				}
				sb.write(ctx.code_generator_nelua(e))
			}
			sb.write(')')
		} else {
			panic('Code gen Type error: `${node.u.@type}`')
		}
		output := sb.str()
		sb.free()
		return output
	}
}

fn (ctx Context) code_generator_v(node ASTNode) string {
	unsafe {
		mut sb := strings.new_builder(1024)
		if node.u.@type == 'Program' {
			if ctx.use_add {
				sb.writeln('fn add(a f32, b f32) f32 {return a + b}')
			}
			if ctx.use_subtract {
				sb.writeln('fn subtract(a f32, b f32) f32 {return a - b}')
			}
			if ctx.use_multiply {
				sb.writeln('fn multiply(a f32, b f32) f32 {return a * b}')
			}
			if ctx.use_divide {
				sb.writeln('fn divide(a f32, b f32) f32 {return a / b}')
			}
			for e in node.program.body {
				sb.write(ctx.code_generator_v(e))
			}
		} else if node.u.@type == 'NumberLiteral' {
			sb.write(node.numberliteral.value)
		} else if node.u.@type == 'ExpressionStatement' {
			sb.write(ctx.code_generator_v(node.expressionstatement.expression))
			sb.writeln('')
		} else if node.u.@type == 'Call' {
			name := match node.call.callee.name {
				'print' { 'println' }
				'write' { 'println' }
				'+' { 'add' }
				'-' { 'subtract' }
				'*' { 'multiply' }
				'/' { 'divide' }
				else { node.call.callee.name }
			}
			sb.write(name)
			sb.write('(')
			for i, e in node.call.arguments {
				if i > 0 {
					sb.write(', ')
				}
				sb.write(ctx.code_generator_v(e))
			}
			sb.write(')')
		} else {
			panic('Code gen Type error: `${node.u.@type}`')
		}
		output := sb.str()
		sb.free()
		return output
	}
}

fn (mut ctx Context) compiler() string {
	flags := ctx.flags
	if 0 != ctx.flags & print_input {
		println('input=\\\n$ctx.source')
	}
	tokens := tokenizer(ctx.source)
	if 0 != flags & print_tokens {
		print_tokens(tokens)
	}
	mut ast := ctx.parser(tokens)
	if 0 != flags & print_ast {
		print_ast(ast)
	}
	newast := transformer(mut ast)
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
		println('output=\\\n$output')
	}
	return output
}

fn usage() {
	prog := os.args[0]
	println('Usage: $prog [options]')
	println('')
	println('Options:')
	println('   --help\t\tDisplay this information.')
	println('   -x "CODE"\t\tUse provided CODE as source input.')
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
	for a in os.args {
		if set_input {
			set_input = false
			ctx.source = a
			continue
		}
		if a == '--help' {
			usage()
			exit(0)
		}
		if a == '-x' {
			set_input = true
			continue
		}
		if a == '--print-input' {
			ctx.flags |= print_input
		}
		if a == '--print-tokens' {
			ctx.flags |= print_tokens
		}
		if a == '--print-ast' {
			ctx.flags |= print_ast
		}
		if a == '--print-newast' {
			ctx.flags |= print_newast
		}
		if a == '--print-output' {
			ctx.flags |= print_output
		}
		if a == '--output-c' {
			ctx.flags = (ctx.flags & ~output_mask) | output_c
		}
		if a == '--output-nelua' {
			ctx.flags = (ctx.flags & ~output_mask) | output_nelua
		}
		if a == '--output-v' {
			ctx.flags = (ctx.flags & ~output_mask) | output_v
		}
	}
}

fn main() {
	mut ctx := Context{
		flags: 0 | 0 * print_input | 0 * print_tokens | 0 * print_ast | 0 * print_newast | 0 * print_output | 1 * output_c
		source: '(write(+ (* (/ 9 5) 60) 32))'
	}
	ctx.set_args()
	output := ctx.compiler()
	println(output)
}
