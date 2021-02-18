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
				mut node := &CallExpression{
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

fn parser(tokens []Token) &ASTNode {
	mut ast := &Program{}
	mut current := MyInt{}
	for current.value < tokens.len {
		mut node := &ASTNode{}
		node = walk(mut &current, tokens)
		ast.body << node
	}
	return ast
}

fn traverse_node(node ASTNode, mut parent ASTNode) ASTNode {
	// println('traverse_node.. node=${voidptr(node)}')
	println('traverse_node..')
	if mut node is NumberLiteral {
		println(' Numlit')
		// if parent != voidptr(0) {
		// if parent is Program {println('is progr')}
		// if parent is CallExpression {println('is callexpr=${voidptr(&parent)}')}
		nl := &NumberLiteral{
			value: node.value
		}
		// println('parent ctx=${voidptr(ctx)} numlit=${voidptr(nl)} ${nl.value}')
		if mut parent is Program {
			// println('pushing numlit to progr ctx=${voidptr(&ctx)}')
			println('pushing numlit to progr')
			parent.body << nl
		} else if mut parent is CallExpression {
			// println('pushing numlit to callexpr ctx=${voidptr(&ctx)}')
			println('pushing numlit to callexpr')
			// println('ADDING NL=${voidptr(nl)} TO PARAMS')
			parent.params << nl
		} else if mut parent is Call {
			// println('pushing numlit to call ctx=${voidptr(&ctx)}')
			println('pushing numlit to call')
			parent.arguments << nl
		} else {
			panic('parent ctx is unknown ?')
		}
		//} else {
		// println('parent ctx is null ?')
		//}
		//} else {
		// println('parent is null ?')
		//}
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
		// node.body<<NumberLiteral{value:"123"}
		println(' traverse Prog ctx=${voidptr(node.ctx)} $node.body.len')
		for i := 0; i < node.body.len; i++ {
			// ret_ctx := 
			node.body[i] = traverse_node(node.body[i], mut &node)
			match node.body[i] {
				Program { // node.body[i].ctx = rect_ctx 
					// println('ctx=${voidptr(node.body[i].ctx)}')
				}
				else {}
			}
		}
		/*
		for e in node.body {
			if mut e is Program {
				the_ctx := e.ctx
				println('prog ctx=${voidptr(the_ctx)}')
			}
			if mut e is CallExpression {
				the_ctx := e.ctx
				println('callex ctx=${voidptr(the_ctx)}')
			}
			// ret_ctx := 
			e = traverse_node(e, node)
			if mut e is Program {
				the_ctx := e.ctx
				println('prog ctx=${voidptr(the_ctx)}')
			}
			if mut e is CallExpression {
				the_ctx := e.ctx
				println('callex ctx=${voidptr(the_ctx)}')
			}
		}
		*/
		/*
		if mut node.ctx is Program {
			node.ctx.body << NumberLiteral{
				value: '5678'
			}
		}
		*/
	} else if mut node is CallExpression {
		println(' traverse Callex')
		for i := 0; i < node.params.len; i++ {
			// println('about to traverse from callexp e=${voidptr(e)}')
			println('about to traverse from callexp')
			node.params[i] = traverse_node(node.params[i], mut &node)
		}
		/*
		} else if node.u.@type=='NumberLiteral'||node.u.@type=='StringLiteral' {
		// nothing special
	} else {
		panic('Type error: `${node.u.@type}`')
		*/
	}
	// return node.ctx
	return node
}

fn traverser(mut ast ASTNode) {
	// ast.ctx = 
	mut ptr := voidptr(0)
	ast = traverse_node(ast, mut ptr)
	/*
	if mut ast is Program {
		if mut ast.ctx is Program {
			ast.ctx.body << NumberLiteral{
				value: '1234'
			}
			// if mut node.ctx is Program {
			ast.ctx.body << ExpressionStatement{
				expression: &Call{
					@type: 'Identifier'
					name: 'toto'
				}
			}
			//}
		}
	}
	*/
}

fn transformer(mut ast ASTNode) &ASTNode {
	mut newast := &Program{}
	if mut ast is Program {
		ast.ctx = newast
		println('ast.ctx=${voidptr(ast.ctx)}')
	}
	traverser(mut ast)
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
newast := transformer(mut ast)
print_ast(newast)
// println(newast)
code_generator_v(newast)
