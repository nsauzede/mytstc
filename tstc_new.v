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

struct NumberLiteral {
	ctx   &ASTNode = voidptr(0)
	value string
}

struct CallExpression {
mut:
	ctx    &ASTNode = voidptr(0)
	name   string
	params []ASTNode
}

struct ExpressionStatement {
	ctx        &ASTNode = voidptr(0)
	expression &ASTNode
}

struct Call {
	ctx &ASTNode = voidptr(0)
mut:
	@type     string
	name      string
	arguments []ASTNode
}

type ASTNode = Call | CallExpression | ExpressionStatement | NumberLiteral | Program

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
		CallExpression {
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
		Call {
			print('${typeof(node).name}')
			print(' callee type=${node.@type}')
			print(' name=$node.name')
			println(' arguments=\\')
			for e in node.arguments {
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

fn walk(mut current_ &int, tokens []Token) &ASTNode {
	current0 := *current_
	token0 := tokens[current0]
	match token0 {
		Number {
			n := &NumberLiteral{
				value: token0.value
			}
			current_ = current0 + 1
			return n
		}
		Paren {
			if token0.value == '(' {
				mut current := current0
				current++
				name := tokens[current] as Name
				mut node := &CallExpression{
					name: name.value
				}
				current++
				for {
					token := tokens[current]
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
				current_ = current + 1
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

fn parser(tokens []Token) &ASTNode {
	mut ast := &Program{}
	mut current := 0
	for current < tokens.len {
		mut node := &ASTNode{}
		node = walk(mut &current, tokens)
		ast.body << node
	}
	return ast
}

fn traverse_node(node &ASTNode, parent &ASTNode) {
	println('traverse_node.. node=${voidptr(node)}')
	if mut node is NumberLiteral {
		println(' Numlit')
		if parent != voidptr(0) {
			// if parent is Program {println('is progr')}
			// if parent is CallExpression {println('is callexpr=${voidptr(&parent)}')}
			mut ctx:=&ASTNode{}
			match parent {
				Program {ctx=parent.ctx}
				else{panic('Unkown parent type for ctx')}
			}
			if ctx != voidptr(0) {
				nl := &NumberLiteral{
					value: node.value
				}
				// println('parent ctx=${voidptr(ctx)} numlit=${voidptr(nl)} ${nl.value}')
				if mut ctx is Program {
					println('pushing numlit to progr ctx=${voidptr(&ctx)}')
					ctx.body << nl
				} else if mut ctx is CallExpression {
					println('pushing numlit to callexpr ctx=${voidptr(&ctx)}')
					// println('ADDING NL=${voidptr(nl)} TO PARAMS')
					ctx.params << nl
				} else if mut ctx is Call {
					println('pushing numlit to call ctx=${voidptr(&ctx)}')
					ctx.arguments << nl
				} else {
					println('parent ctx is unknown ?')
				}
			} else {
				println('parent ctx is null ?')
			}
		} else {
			println('parent is null ?')
		}
	}
	//	exit(0)
	if mut node is CallExpression {
		println(' Callexpr')
		mut expression := &Call{
			@type: 'Identifier'
			name: node.name
		}
		node.ctx = expression
		if mut parent is CallExpression {
			 println('pushing call to callexpr expr=${voidptr(expression)}')
			// println('ADDING EXPRESSION=${voidptr(expression)} TO PARAMS')
			parent.params << expression
		} else if mut parent is Program {
			 println('pushing call to progr')
			expression2 := &ExpressionStatement{
				expression: expression
			}
			parent.body << expression2
		}
	}
	if mut node is Program {
		//node.body<<NumberLiteral{value:"123"}
		println(' traverse Prog ctx=${voidptr(node.ctx)}')
		for i := 0; i < node.body.len; i++ {
			traverse_node(&node.body[i], node)
		}
	} else if mut node is CallExpression {
		println(' traverse Callex')
		for i := 0; i < node.params.len; i++ {
			// println('about to traverse from callexp e=${voidptr(e)}')
			 println('about to traverse from callexp')
			traverse_node(&node.params[i], node)
		}
		/*
		} else if node.u.@type=='NumberLiteral'||node.u.@type=='StringLiteral' {
		// nothing special
	} else {
		panic('Type error: `${node.u.@type}`')
		*/
	}
}

fn traverser(ast &ASTNode) {
	traverse_node(ast, voidptr(0))
}

fn transformer(ast ASTNode) &ASTNode {
	mut newast := &Program{}
	//mut ctx:=&&ASTNode{}
	if mut ast is Program{
		//ctx=
		ast.ctx=newast
		println('ast.ctx=${voidptr(ast.ctx)}')
	}
		// mut ast:=ast_ as Program
		//unsafe{*ctx = newast}
		// println('ast_=${voidptr(&ast_)}')
		//println('ast.ctx=${voidptr(ast.ctx)}')
		traverser(&ast)
	//}
	return newast
}

fn code_generator_v(node ASTNode) {
	match node {
		Program {
			println('Program')
		}
		else {
			panic('gen: unsupported node type')
		}
	}
}

source := '(write(+ (* (/ 9 5) 60) 32))'
tokens := tokenizer(source)
// println(tokens)
mut ast := parser(tokens)
// println(ast)
print_ast(ast)
newast := transformer(ast)
print_ast(newast)
// println(newast)
code_generator_v(newast)
