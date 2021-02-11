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
	ctxt &[]&ASTNode = voidptr(0)
}
struct Program {
mut:
	@type string = 'Program'
	ctxt &[]&ASTNode = voidptr(0)

	body []&ASTNode
}
struct NumberLiteral {
	@type string = 'NumberLiteral'
	ctxt &[]&ASTNode = voidptr(0)

	value string
}
struct StringLiteral {
	@type string = 'StringLiteral'
	ctxt &[]&ASTNode = voidptr(0)

	value string
}
struct CallExpression {
mut:
	@type string = 'CallExpression'
	ctxt &[]&ASTNode = voidptr(0)

	name string
	params []&ASTNode
}
struct ExpressionStatement {
mut:
	@type string = 'ExpressionStatement'
	ctxt &[]&ASTNode = voidptr(0)

	expression &ASTNode = voidptr(0)
}
struct Call {
mut:
	@type string = 'Call'
	ctxt &[]&ASTNode = voidptr(0)

	callee Callee
	arguments []&ASTNode
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
		//print(' node=${voidptr(&node)} type=${node.call.callee.@type}')
		print(' callee type=${node.call.callee.@type}')
		print(' name=${node.call.callee.name}')
		//print(' args=${voidptr(&node.call.arguments)}:${node.call.arguments.len}=\\\n')
		//print(' arguments:${node.call.arguments.len}=\\\n')
		print(' arguments=\\\n')
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
	return c>=`a` && c<=`z`
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
	//println('hello traverse_node=${voidptr(node)} ${node.u.@type}')
	if node.u.@type=='NumberLiteral' {
		if parent!=voidptr(0) {
			//print(' parent=${voidptr(parent)}')
			if parent.u.ctxt!=voidptr(0) {
				//print(' ctx=${voidptr(parent.u.ctxt)}')
				//print(' pushing nlit=${node.numberliteral.value}')
				parent.u.ctxt<<&ASTNode{numberliteral:{value:node.numberliteral.value}}
			}
			//println('')
		}
	}
	if node.u.@type=='CallExpression' {
		mut expression:=&ASTNode{call:{callee:{@type:'Identifier',name:node.callexpression.name}}}
		node.u.ctxt=&expression.call.arguments
		if parent.u.@type!='CallExpression' {
			expression2:=&ASTNode{expressionstatement:{expression:expression}}
			parent.u.ctxt<<expression2
		} else {
			parent.u.ctxt<<expression
		}
	}
	if node.u.@type=='Program' {
		//println('traversing body.. ${node.program.body.len}')
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
	ast.u.ctxt=&newast.program.body
	traverser(mut ast)
	//println('newast body=${newast.program.body.len}')
	return newast
}}
fn code_generator(ast ASTNode) string {
	return ''
}
fn print_tokens(tokens []Token) {
	for i:=0;i<tokens.len;i++ {
		println('${tokens[i].@type}\t${tokens[i].value}')
	}
}
const (
	print_input		=0x01
	print_tokens	=0x02
	print_ast		=0x04
	print_newast	=0x08
	print_output	=0x10
)
fn compiler(input string, flags int) string {
	tokens:=tokenizer(input)
	if 0!=flags&print_tokens {print_tokens(tokens)}
	mut ast:=parser(tokens)
	if 0!=flags&print_ast {print_ast(ast)}
	newast:=transformer(mut ast)
	if 0!=flags&print_newast {print_ast(newast)}
	output:=code_generator(newast)
	return output
}
fn usage() {
	prog:=os.args[0]
	println('Usage: $prog [options]')
	println('')
	println('Options:')
	println('   --help\t\tDisplay this information.')
	println('   --print-input\tDisplay the source input.')
	println('   --print-tokens\tDisplay the tokens.')
	println('   --print-ast\t\tDisplay the ast.')
	println('   --print-newast\tDisplay the newast.')
	println('   --print-output\tDisplay the generated output.')
	println('')
	println('For more information, please see:')
	println('https://github.com/nsauzede/mytstc')
}
fn main() {
	mut flags:=print_input|0*print_tokens|0*print_ast|print_newast//|print_output
	source:="    (add 2 2)
    (subtract 4 2)
    (add 2 (subtract 4 2))"
	for a in os.args {
		if a=='--help'{usage()exit(0)}
		if a=='--print-input'{flags|=print_input}
		if a=='--print-tokens'{flags|=print_tokens}
		if a=='--print-ast'{flags|=print_ast}
		if a=='--print-newast'{flags|=print_newast}
		if a=='--print-output'{flags|=print_output}
	}
	if 0!=flags&print_input{println('input=\\\n$source')}
	output:=compiler(source,flags)
	if 0!=flags&print_output{println('output=\\\n$output')}
}
