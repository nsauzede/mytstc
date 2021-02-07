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
	ast:=[]ASTNode{}
	return ast
}
fn transformer(ast []ASTNode) []ASTNode {
	return ast
}
fn code_generator(ast []ASTNode) string {
	return ''
}
fn compiler(input string) string {
	println('input=$input')
	tokens:=tokenizer(input)
	ast:=parser(tokens)
	newast:=transformer(ast)
	output:=code_generator(newast)
	for i:=0;i<tokens.len;i++ {
		println('${tokens[i].@type}\t${tokens[i].value}')
	}
	print_ast(ast)
	return output
}
fn main() {
	source:="
    (add 2 2)
    (subtract 4 2)
    (add 2 (subtract 4 2))
    "
	output:=compiler(source)
	println('output=$output')
}
