module main
import os
import strings

struct Token {
	@type string
	value string
}

struct Callee {
	@type string
	name string
}

struct ASTNodeGeneric {
mut:
	@type string
	ctxt &ASTNode = voidptr(0)
	arr []&ASTNode
}
struct Program {
mut:
	@type string = 'Program'
	ctxt &ASTNode = voidptr(0)
	body []&ASTNode
}
struct NumberLiteral {
	@type string = 'NumberLiteral'
	ctxt &ASTNode = voidptr(0)
	arr []&ASTNode

	value string
}
struct StringLiteral {
	@type string = 'StringLiteral'
	ctxt &ASTNode = voidptr(0)
	arr []&ASTNode

	value string
}
struct CallExpression {
mut:
	@type string = 'CallExpression'
	ctxt &ASTNode = voidptr(0)
	params []&ASTNode

	name string
}
struct ExpressionStatement {
mut:
	@type string = 'ExpressionStatement'
	ctxt &ASTNode = voidptr(0)
	arr []&ASTNode

	expression &ASTNode = voidptr(0)
}
struct Call {
mut:
	@type string = 'Call'
	ctxt &ASTNode = voidptr(0)
	arguments []&ASTNode

	callee Callee
}

union ASTNode {
mut:
	u ASTNodeGeneric
	program Program
	numberliteral NumberLiteral
	stringliteral StringLiteral
	callexpression CallExpression
	expressionstatement ExpressionStatement
	call Call
}

fn print_tokens(tokens []Token) {
	for i:=0;i<tokens.len;i++ {
		println('${tokens[i].@type}\t${tokens[i].value}')
	}
}

fn print_ast_r(node ASTNode, nest int) {unsafe {
	for i:=0;i<nest;i++ {
		print('\t')
	}
	print('${node.u.@type}')
	if node.u.@type=='Program' {
		println(' body=\\')
		for e in node.program.body {
			print_ast_r(e, nest + 1)
		}
	}
	if node.u.@type=='NumberLiteral'||node.u.@type=='StringLiteral'{
		println(' value=$node.numberliteral.value')
	}
	if node.u.@type=='CallExpression' {
		println(' name=$node.callexpression.name params=\\')
		for e in node.callexpression.params {
			print_ast_r(e, nest + 1)
		}
	}
	if node.u.@type=='ExpressionStatement' {
		print_ast_r(node.expressionstatement.expression, nest + 1)
	}
	if node.u.@type=='Call' {
		print(' callee type=${node.call.callee.@type}')
		print(' name=${node.call.callee.name}')
		println(' arguments=\\')
		for e in node.call.arguments {
			print_ast_r(e, nest + 1)
		}
	}
}}

fn print_ast(ast ASTNode) {
	print_ast_r(ast, 0)
}

fn is_space(c byte) bool {
	return c==` ` || c==`\n`
}

fn is_number(c byte) bool {
	return c>=`0` && c<=`9`
}

fn is_letter(c byte) bool {
	return
	(c>=`a` && c<=`z`)
	|| c==`+`
	|| c==`-`
	|| c==`*`
	|| c==`/`
}

fn tokenizer(input string) []Token {
	mut current:=0
	mut tokens:=[]Token{}
	for current<input.len {
		mut c:=input[current]
		if c==`(` {
			tokens<<Token{'paren','('}
			current++
			continue
		}
		if c==`)` {
			tokens<<Token{'paren',')'}
			current++
			continue
		}
		if is_space(c) {
			current++
			continue
		}
		if is_number(c) {
			mut value:=strings.new_builder(256)
			for is_number(c) {
				value.write_b(c)
				current++
				c=input[current]
			}
			tokens<<Token{'number',value.str()}
			continue
		}
		if is_letter(c) {
			mut value:=strings.new_builder(256)
			for is_letter(c) {
				value.write_b(c)
				current++
				c=input[current]
			}
			tokens<<Token{'name',value.str()}
			continue
		}
		panic("I don't know what this character is: `${c:c}`")
	}
	return tokens
}

__global (
	use_add=bool(false)
	use_subtract=bool(false)
	use_multiply=bool(false)
	use_divide=bool(false)
	use_print=bool(false)
)
fn walk(current int, tokens []Token) (int,&ASTNode) {unsafe{
	mut token:=tokens[current]
	if token.@type=='number' {
		return current+1,&ASTNode{
			numberliteral:{value:token.value}
		}
	}
	if token.@type=='string' {
		return current+1,&ASTNode{
			stringliteral:{value:token.value}
		}
	}
	if token.@type=='paren' && token.value=='(' {
		current++
		token=tokens[current]
		mut node := &ASTNode{callexpression:{name:token.value}}
		match token.value {
			'+' {use_add=true}
			'-' {use_subtract=true}
			'*' {use_multiply=true}
			'/' {use_divide=true}
			'write','print' {use_print=true}
			else{}
		}
		current++
		token=tokens[current]
		for token.@type!='paren' || (token.@type=='paren' && token.value!=')') {
			mut child:=&ASTNode{}
			current,child=walk(current,tokens)
			node.callexpression.params<<child
			token=tokens[current]
		}
		return current+1,node
	}
	panic('walk: Type error: `${token.@type}` ${token.value}')
}}

fn parser(tokens []Token) ASTNode {unsafe{
	mut ast:=ASTNode{program:{}}
	mut current:=0
	for current<tokens.len {
		mut node:=&ASTNode{}
		current,node=walk(current,tokens)
		ast.program.body<<node
	}
	return ast
}}

fn traverse_node(mut node ASTNode, parent &ASTNode) {unsafe{
	if node.u.@type=='NumberLiteral' {
		if parent!=voidptr(0) {
			if parent.u.ctxt!=voidptr(0) {
				parent.u.ctxt.u.arr<<&ASTNode{numberliteral:{value:node.numberliteral.value}}
			}
		}
	}
	if node.u.@type=='CallExpression' {
		mut expression:=&ASTNode{call:{callee:{@type:'Identifier',name:node.callexpression.name}}}
		node.u.ctxt=expression
		if parent.u.@type!='CallExpression' {
			expression2:=&ASTNode{expressionstatement:{expression:expression}}
			parent.u.ctxt.u.arr<<expression2
		} else {
			parent.u.ctxt.u.arr<<expression
		}
	}
	if node.u.@type=='Program' {
		for e in node.program.body {
			traverse_node(mut e, node)
		}
	} else if node.u.@type=='CallExpression' {
		for e in node.callexpression.params {
			traverse_node(mut e, node)
		}
	} else if node.u.@type=='NumberLiteral'||node.u.@type=='StringLiteral' {
		// nothing special
	} else {
		panic('Type error: `${node.u.@type}`')
	}
}}

fn traverser(mut ast ASTNode) {
	traverse_node(mut ast, voidptr(0))
}

fn transformer(mut ast ASTNode) ASTNode {unsafe{
	mut newast:=ASTNode{program:{}}
	ast.u.ctxt=&newast
	traverser(mut ast)
	return newast
}}

fn code_generator_c(node ASTNode) string {unsafe{
	mut sb:=strings.new_builder(1024)
	if node.u.@type=='Program' {
		if use_print {
			sb.writeln('#include <stdio.h>')
		}
		if use_add {
			sb.writeln('float add(float a, float b) {return a + b;}')
		}
		if use_subtract {
			sb.writeln('float subtract(float a, float b) {return a - b;}')
		}
		if use_multiply {
			sb.writeln('float multiply(float a, float b) {return a * b;}')
		}
		if use_divide {
			sb.writeln('float divide(float a, float b) {return a / b;}')
		}
		if use_print {
			sb.writeln('void println(float a) {printf("%f\\n", (double)a);}')
		}
		sb.writeln('int main() {')
		for e in node.program.body {
			sb.write(code_generator_c(e))
		}
		sb.writeln('\treturn 0;')
		sb.writeln('}')
	} else if node.u.@type=='NumberLiteral' {
		sb.write(node.numberliteral.value)
	} else if node.u.@type=='ExpressionStatement' {
		sb.write('\t')
		sb.write(code_generator_c(node.expressionstatement.expression))
		sb.writeln(';')
	} else if node.u.@type=='Call' {
		name:= match node.call.callee.name {
			'print' {'println'}
			'write' {'println'}
			'+' {'add'}
			'-' {'subtract'}
			'*' {'multiply'}
			'/' {'divide'}
			else{node.call.callee.name}
		}
		sb.write(name)
		sb.write('(')
		for i,e in node.call.arguments {
			if i>0 {
				sb.write(', ')
			}
			sb.write(code_generator_c(e))
		}
		sb.write(')')
	} else {
		panic('Code gen Type error: `${node.u.@type}`')
	}
	output:=sb.str()
	sb.free()
	return output
}}

fn code_generator_nelua(node ASTNode) string {unsafe{
	mut sb:=strings.new_builder(1024)
	if node.u.@type=='Program' {
		if use_add {
			sb.writeln('local function add(a: float32, b: float32): float32 return a + b end')
		}
		if use_subtract {
			sb.writeln('local function subtract(a: float32, b: float32): float32 return a - b end')
		}
		if use_multiply {
			sb.writeln('local function multiply(a: float32, b: float32): float32 return a * b end')
		}
		if use_divide {
			sb.writeln('local function divide(a: float32, b: float32): float32 return a / b end')
		}
		for e in node.program.body {
			sb.write(code_generator_nelua(e))
		}
	} else if node.u.@type=='NumberLiteral' {
		sb.write(node.numberliteral.value)
	} else if node.u.@type=='ExpressionStatement' {
		sb.write(code_generator_nelua(node.expressionstatement.expression))
		sb.writeln('')
	} else if node.u.@type=='Call' {
		name:= match node.call.callee.name {
			'write' {'print'}
			'+' {'add'}
			'-' {'subtract'}
			'*' {'multiply'}
			'/' {'divide'}
			else{node.call.callee.name}
		}
		sb.write(name)
		sb.write('(')
		for i,e in node.call.arguments {
			if i>0 {
				sb.write(', ')
			}
			sb.write(code_generator_nelua(e))
		}
		sb.write(')')
	} else {
		panic('Code gen Type error: `${node.u.@type}`')
	}
	output:=sb.str()
	sb.free()
	return output
}}

fn code_generator_v(node ASTNode) string {unsafe{
	mut sb:=strings.new_builder(1024)
	if node.u.@type=='Program' {
		if use_add {
			sb.writeln('fn add(a f32, b f32) f32 {return a + b}')
		}
		if use_subtract {
			sb.writeln('fn subtract(a f32, b f32) f32 {return a - b}')
		}
		if use_multiply {
			sb.writeln('fn multiply(a f32, b f32) f32 {return a * b}')
		}
		if use_divide {
			sb.writeln('fn divide(a f32, b f32) f32 {return a / b}')
		}
		for e in node.program.body {
			sb.write(code_generator_v(e))
		}
	} else if node.u.@type=='NumberLiteral' {
		sb.write(node.numberliteral.value)
	} else if node.u.@type=='ExpressionStatement' {
		sb.write(code_generator_v(node.expressionstatement.expression))
		sb.writeln('')
	} else if node.u.@type=='Call' {
		name:= match node.call.callee.name {
			'print' {'println'}
			'write' {'println'}
			'+' {'add'}
			'-' {'subtract'}
			'*' {'multiply'}
			'/' {'divide'}
			else{node.call.callee.name}
		}
		sb.write(name)
		sb.write('(')
		for i,e in node.call.arguments {
			if i>0 {
				sb.write(', ')
			}
			sb.write(code_generator_v(e))
		}
		sb.write(')')
	} else {
		panic('Code gen Type error: `${node.u.@type}`')
	}
	output:=sb.str()
	sb.free()
	return output
}}

const (
	print_input		= 0x01
	print_tokens	= 0x02
	print_ast		= 0x04
	print_newast	= 0x08
	print_output	= 0x10
	output_c		= 0x20
	output_nelua	= 0x40
	output_v		= 0x80
	output_mask		= output_c|output_nelua|output_v
)

fn compiler(input string, flags int) string {
	tokens:=tokenizer(input)
	if 0!=flags&print_tokens {print_tokens(tokens)}
	mut ast:=parser(tokens)
	if 0!=flags&print_ast {print_ast(ast)}
	newast:=transformer(mut ast)
	if 0!=flags&print_newast {print_ast(newast)}
	mut output:=''
	if 0!=flags&output_c {
		output=code_generator_c(newast)
	}
	if 0!=flags&output_nelua {
		output=code_generator_nelua(newast)
	}
	if 0!=flags&output_v {
		output=code_generator_v(newast)
	}
	return output
}

fn usage() {
	prog:=os.args[0]
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

fn main() {
	mut flags:=0|0*print_input|0*print_tokens|0*print_ast|0*print_newast|0*print_output|1*output_c
	mut source:="(write(+ (* (/ 9 5) 60) 32))"
	mut set_input:=false
	for a in os.args {
		if set_input {set_input = false source = a continue}
		if a=='--help'{usage()exit(0)}
		if a=='-x'{set_input=true continue}
		if a=='--print-input'{flags|=print_input}
		if a=='--print-tokens'{flags|=print_tokens}
		if a=='--print-ast'{flags|=print_ast}
		if a=='--print-newast'{flags|=print_newast}
		if a=='--print-output'{flags|=print_output}
		if a=='--output-c'{flags=(flags&~output_mask)|output_c}
		if a=='--output-nelua'{flags=(flags&~output_mask)|output_nelua}
		if a=='--output-v'{flags=(flags&~output_mask)|output_v}
	}
	if 0!=flags&print_input{println('input=\\\n$source')}
	output:=compiler(source,flags)
	if 0!=flags&print_output{println('output=\\\n$output')}
	println(output)
}
