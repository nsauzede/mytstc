module main
import os
import strings
struct Token {
	@type string
	value string
}
struct ASTNode {
	@type string
	value string
}
fn print_ast(ast []ASTNode) {
	for e in ast {
		println('e=$e')
	}
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
fn parser(tokens []Token) []ASTNode {
	mut ast:=[]ASTNode{}
	return ast
}
fn transformer(ast []ASTNode) []ASTNode {
	return ast
}
fn code_generator(ast []ASTNode) string {
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
	ast:=parser(tokens)
	if 0!=flags&print_ast {print_ast(ast)}
	newast:=transformer(ast)
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
	mut flags:=print_input|print_tokens|print_output
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
