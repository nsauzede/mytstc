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
	if 0!=flags&print_input {
		println('input=$input')
	}
	tokens:=tokenizer(input)
	//print_tokens(tokens)
	ast:=parser(tokens)
	print_ast(ast)
	newast:=transformer(ast)
	output:=code_generator(newast)
	println('output=$output')
	return output
}
fn main() {
	mut flags:=0
	println('before flags=$flags')
	for a in os.args {
		if a=='--print-tokens' {
			flags|=print_input
		}
		println('a=$a')
	}
	println('before flags=$flags')
	if 0!=flags&print_input {
		println('Will print inputs')
	}
	//println('args=$args')
	source:="
    (add 2 2)
    (subtract 4 2)
    (add 2 (subtract 4 2))
    "
	output:=compiler(source,flags)
}
