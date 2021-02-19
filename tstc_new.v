import strings

struct Paren {
	value string
}

struct Name {
	value string
}

struct Number {
	value string
}

type Token = Name | Number | Paren

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
	Program

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
		NumberLiteral /* ,StringLiteral */ {
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

fn tokenizer(input string) []Token {
	mut current := 0
	mut tokens := []Token{}
	for current < input.len {
		mut c := input[current]
		if c == `(` {
			tokens << Paren{'('}
			current++
		} else if c == `)` {
			tokens << Paren{')'}
			current++
		} else if is_space(c) {
			current++
		} else if is_number(c) {
			mut value := strings.new_builder(256)
			for is_number(c) {
				value.write_b(c)
				current++
				c = input[current]
			}
			tokens << Number{value.str()}
		} else if is_letter(c) {
			mut value := strings.new_builder(256)
			for is_letter(c) {
				value.write_b(c)
				current++
				c = input[current]
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

fn walk(mut current_ MyInt, tokens []Token) &ASTNode {
	token0 := tokens[current_.value]
	match token0 {
		Number {
			n := &NumberLiteral{
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
					child = walk(mut &current, tokens)
					// println('ADDING CHILD=${voidptr(child)} TO PARAMS')
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

fn parser(tokens []Token) ASTNode {
	mut ast := Program{}
	mut current := MyInt{}
	for current.value < tokens.len {
		mut node := &ASTNode{}
		node = walk(mut &current, tokens)
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
			Program {
				ctx = parent.ctx
			}
			Call {
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
		NumberLiteral {}
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

source := '(write(+ (* (/ 9 5) 60) 32))'
tokens := tokenizer(source)
// println(tokens)
mut ast := parser(tokens)
mut newast := ASTNode{}
ast, newast = transformer(mut &ast)
print_ast(ast)
// println('ast=$ast')
print_ast(newast)
// println('newast=$newast')
