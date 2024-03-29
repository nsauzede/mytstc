module main

import strings
import os

[flag]
enum Flags {
	dtokens
	print_input
	print_tokens
	print_ast
	print_newast
	print_output
	output_c
	output_nelua
	output_v
}

const (
	output_mask = Flags.output_c | Flags.output_nelua | Flags.output_v
)

struct Context {
mut:
	flags        Flags
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

struct Defun {
mut:
	name      string
	arguments []ASTNode
	body      []ASTNode
}

struct Identifier {
	name string
}

struct ASTNode0 {}

type ASTNode = ASTNode0 | Call | CallExpression | Defun | ExpressionStatement | Identifier |
	NumberLiteral | Program | StringLiteral

fn eprint_tokens(tokens []Token) {
	eprintln('')
	eprintln('tokens=\\')
	for t in tokens {
		eprint('$t.type_name()\t')
		match t {
			Paren, Name, Number, String { eprintln('$t.value') }
		}
	}
}

fn eprint_ast_r(node ASTNode, nest int) {
	for i := 0; i < nest; i++ {
		eprint('\t')
	}
	match node {
		Program {
			eprint('${typeof(node).name}')
			eprintln(' body:$node.body.len=\\')
			for e in node.body {
				eprint_ast_r(e, nest + 1)
			}
		}
		NumberLiteral {
			eprint('${typeof(node).name}')
			eprintln(' value=$node.value')
		}
		StringLiteral {
			eprint('${typeof(node).name}')
			eprintln(' value=$node.value')
		}
		Call {
			eprint('${typeof(node).name}')
			eprintln(' name=$node.name params=\\')
			for e in node.params {
				eprint_ast_r(e, nest + 1)
			}
		}
		ExpressionStatement {
			eprint('${typeof(node).name}')
			eprint_ast_r(node.expression, nest + 1)
		}
		CallExpression {
			eprint('${typeof(node).name}')
			eprint(' callee=')
			eprint_ast_r(node.callee, 0)
			eprintln(' arguments:$node.arguments.len=\\')
			for e in node.arguments {
				eprint_ast_r(e, nest + 1)
			}
		}
		Defun {
			eprint('${typeof(node).name}')
			eprint(' name=$node.name')
			eprintln(' arguments:$node.arguments.len=\\')
			for e in node.arguments {
				eprint_ast_r(e, nest + 1)
			}
			for i := 0; i < nest + 1; i++ {
				eprint('\t')
			}
			eprintln('body:$node.body.len=\\')
			for e in node.body {
				eprint_ast_r(e, nest + 1)
			}
			eprintln('')
		}
		Identifier {
			eprint('${typeof(node).name}')
			eprintln(' name=$node.name')
		}
		else {}
	}
}

fn eprint_ast(ast ASTNode) {
	eprintln('')
	eprintln('ast=\\')
	eprint_ast_r(ast, 0)
}

fn is_space(c byte) bool {
	return c == ` ` || c == `\n`
}

fn is_number(c byte) bool {
	return (c >= `0` && c <= `9`) || c == `.`
}

fn is_letter(c byte) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `+` || c == `-`
		|| c == `*` || c == `/`
}

fn is_alnum(c byte) bool {
	return is_letter(c) || is_number(c)
}

fn (ctx Context) dprint(flags Flags, s string) {
	if int(ctx.flags & flags) > 0 {
		eprint(s)
	}
}

fn (ctx Context) dprintln(flags Flags, s string) {
	if int(ctx.flags & flags) > 0 {
		eprintln(s)
	}
}

fn (ctx Context) tokenizer(input string) []Token {
	mut current := 0
	mut tokens := []Token{}
	for current < input.len {
		// ctx.dprintln(.dtokens, 'current=$current')
		mut c := input[current]
		// ctx.dprintln(.dtokens,'got c=$c (${c:c})')
		if c == `(` {
			ctx.dprintln(.dtokens, 'paren(')
			current++
			tokens << Paren{'('}
		} else if c == `)` {
			ctx.dprintln(.dtokens, 'paren)')
			current++
			tokens << Paren{')'}
		} else if is_space(c) {
			current++
		} else if is_number(c) {
			ctx.dprintln(.dtokens, 'number')
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
		} else if c == `\'` || c == `\`` {
			ctx.dprintln(.dtokens, 'quote')
			mut value := strings.new_builder(256)
			mut started := false
			mut nested_paren := 0
			mut in_dquote := false
			for {
				current++
				if current >= input.len {
					break
				}
				c = input[current]
				if 0 == nested_paren && !in_dquote && (is_space(c) || c == `)`) {
					if started {
						break
					} else {
						continue
					}
				}
				started = true
				if c == `(` {
					nested_paren++
				} else if c == `"` {
					if in_dquote {
						current++
						break
					} else {
						in_dquote = true
						continue
					}
				}
				value.write_b(c)
				if nested_paren > 0 {
					if c == `)` {
						nested_paren--
						if nested_paren == 0 {
							current++
							break
						}
					}
				}
			}
			tokens << String{value.str()}
		} else if c == `"` {
			ctx.dprintln(.dtokens, 'doublequote')
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
			ctx.dprintln(.dtokens, 'alnum')
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
	if ctx.flags.has(.print_tokens) {
		eprint_tokens(tokens)
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
		Name {
			n := &Identifier{
				name: token0.value
			}
			current_.value++
			return n
		}
		Paren {
			if token0.value == '(' {
				mut current := current_
				current.value++
				name := tokens[current.value] as Name
				current.value++
				if name.value == 'defun' {
					funame := tokens[current.value] as Name
					current.value++
					mut node := &Defun{
						name: funame.value
					}
					paren := tokens[current.value] as Paren
					assert paren.value == '('
					current.value++
					for {
						token := tokens[current.value]
						match token {
							Paren {
								if token.value == ')' {
									current.value++
									break
								}
							}
							else {}
						}
						mut child := &ASTNode(&ASTNode0{})
						child = ctx.walk(mut &current, tokens)
						node.arguments << child
					}
					for {
						token := tokens[current.value]
						match token {
							Paren {
								if token.value == ')' {
									current.value++
									break
								}
							}
							else {}
						}
						mut child := &ASTNode(&ASTNode0{})
						child = ctx.walk(mut &current, tokens)
						node.body << child
					}
					current_.value = current.value
					return node
				} else {
					match name.value {
						'+' { ctx.use_add = true }
						'-' { ctx.use_subtract = true }
						'*' { ctx.use_multiply = true }
						'/' { ctx.use_divide = true }
						'write', 'print' { ctx.use_print = true }
						'list' { ctx.use_list = true }
						else {}
					}
					mut node := &Call{
						name: name.value
					}
					for {
						token := tokens[current.value]
						match token {
							Paren {
								if token.value == ')' {
									current.value++
									break
								}
							}
							else {}
						}
						mut child := &ASTNode(&ASTNode0{})
						child = ctx.walk(mut &current, tokens)
						node.params << child
					}
					current_.value = current.value
					return node
				}
			} else {
				panic('Paren not (')
			}
		}
		// else {
		// panic('walk: Token type error: $token0')
		//}
	}
	panic('walk: Type error !')
}

fn (mut ctx Context) parser(tokens []Token) ASTNode {
	mut ast := Program{}
	mut current := MyInt{}
	for current.value < tokens.len {
		mut node := &ASTNode(&ASTNode0{})
		node = ctx.walk(mut &current, tokens)
		ast.body << node
	}
	if ctx.flags.has(.print_ast) {
		eprint_ast(ast)
	}
	return ast
}

fn traverse_node(node ASTNode, parent &ASTNode) ASTNode {
	if parent != voidptr(0) {
		mut child := ASTNode(ASTNode0{})
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
			Defun {
				child = node
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
		mut ctx := &ASTNode(&ASTNode0{})
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
		NumberLiteral, StringLiteral, Defun {}
		else {
			panic('node is unknown ? $node.type_name()')
		}
	}
	return node
}

fn (ctx Context) transformer(mut ast ASTNode) (ASTNode, ASTNode) {
	mut newast := &ASTNode(Program{})
	if mut ast is Program {
		ast.ctx = voidptr(newast)
	}
	ast = traverse_node(ast, voidptr(0))
	if ctx.flags.has(.print_newast) {
		eprint_ast(newast)
	}
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
			if ctx.use_list {
				sb.writeln('#include <stdarg.h>')
				sb.writeln('#include <malloc.h>')
			}
			if use_obj {
				sb.writeln('typedef enum{obj_f,obj_i,obj_s,obj_l} obj_t;')
				sb.writeln('
struct obj;
typedef struct {size_t l; struct obj *p;} List;
typedef struct obj {obj_t t;union{float f;int i;char *s; List l;};} obj;
				')
				sb.writeln('#define F(v)(obj){obj_f,.f=v}')
				sb.writeln('#define S(v)(obj){obj_s,.s=v}')

				'
#define PP_NARG(...) PP_NARG_(__VA_ARGS__,PP_RSEQ_N())
#define PP_NARG_(...) PP_ARG_N(__VA_ARGS__)
#define PP_ARG_N( _1, _2, _3, _4, _5, _6, _7, _8, _9,_10, _11,_12,_13,_14,_15,_16,_17,_18,_19,_20, _21,_22,_23,_24,_25,_26,_27,_28,_29,_30, _31,_32,_33,_34,_35,_36,_37,_38,_39,_40, _41,_42,_43,_44,_45,_46,_47,_48,_49,_50, _51,_52,_53,_54,_55,_56,_57,_58,_59,_60, _61,_62,_63,  N, ...) N
#define PP_RSEQ_N() 63,62,61,60,                   59,58,57,56,55,54,53,52,51,50, 49,48,47,46,45,44,43,42,41,40, 39,38,37,36,35,34,33,32,31,30, 29,28,27,26,25,24,23,22,21,20, 19,18,17,16,15,14,13,12,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
'
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
				sb.writeln('
void println_(obj a, int depth){
	if (a.t == obj_f){
		printf("%f", (double)a.f);
	}
	else if (a.t == obj_s){
		printf("%s", a.s);
	}
	else if (a.t == obj_l){
		printf("[");
		for (int i = 0; i < a.l.l; i++) {
			if (i > 0) {
				printf(", ");
			}
			println_(a.l.p[i], depth + 1);
		}
		printf("]");
	}
	else{
		printf("<unknown obj type %d>", a.t);
	}
	if (!depth) {
		printf("\\n");
	}
}
void println(obj a){
	println_(a, 0);
}')
				if ctx.use_list {
					sb.writeln('
obj list(int n, ...) {
	obj r = {obj_l, .l={0, 0}};
	va_list args;
	va_start(args, n);
	for (int i = 0; i < n; i++) {
		size_t new_len = r.l.l + 1;
		r.l.p = realloc(r.l.p, (r.l.l + 1) * sizeof(obj));
		r.l.p[r.l.l++] = va_arg(args, obj);
	}
	va_end(args);
	return r;
}')
				}
			}
			sb.writeln('int main() {')
			for e in node.body {
				sb.write_string(ctx.code_generator_c(e))
			}
			sb.writeln('\treturn 0;')
			sb.writeln('}')
		}
		NumberLiteral {
			sb.write_string('F($node.value)')
		}
		StringLiteral {
			sb.write_string('S("$node.value")')
		}
		ExpressionStatement {
			sb.write_string('\t')
			sb.write_string(ctx.code_generator_c(node.expression))
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
			sb.write_string(name)
		}
		CallExpression {
			callee := ctx.code_generator_c(node.callee)
			sb.write_string(callee)
			sb.write_string('(')
			if callee == 'list' {
				sb.write_string('$node.arguments.len')
				if node.arguments.len > 0 {
					sb.write_string(', ')
				}
			}
			for i, e in node.arguments {
				if i > 0 {
					sb.write_string(', ')
				}
				sb.write_string(ctx.code_generator_c(e))
			}
			sb.write_string(')')
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
			if ctx.use_obj {
				sb.writeln("require 'vector'")
			}
			if ctx.use_print {
				sb.writeln("require 'io'")
			}
			if ctx.use_obj {
				sb.writeln('local ObjT = @enum {u64=0x01,f32=0x02,int=0x04,string=0x08,list=0x10,
}
local Obj =@record{t:ObjT,u:union{
    U64:record{v:uint64,},
    F32:record{v:float32,},
    String:record{v:string,},
    List:record{v:vector(Obj),},
}}')
			}
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
			if ctx.use_print {
				sb.writeln('local function println_(a: Obj, depth: integer)
    if a.t==ObjT.u64 then
        io.stdout:write(a.u.U64.v)
    elseif a.t==ObjT.f32 then
        io.stdout:writef(\'%f\', a.u.F32.v)
    elseif a.t==ObjT.string then
        io.stdout:writef(\'"%s"\', a.u.String.v)
    elseif a.t==ObjT.list then
        io.stdout:write("[")
        for i=0,<#a.u.List.v do
            if i>0 then
                io.stdout:write(", ")
            end
            println_(a.u.List.v[i], depth + 1)
        end
        io.stdout:write("]")
    end
    if depth==0 then
        io.stdout:write("\\n")
    end
end
local function println(a: Obj)
    println_(a, 0)
end
')
			}
			if ctx.use_list {
				sb.writeln("local function list(...: varargs): Obj
    local r=Obj{t=ObjT.list}
    ## for i=1,select_varargs('#') do
        ## local argnode = select_varargs(i)
        r.u.List.v:push(#[argnode]#)
    ## end
    return r
end")
			}
			for e in node.body {
				sb.write_string(ctx.code_generator_nelua(e))
			}
		}
		NumberLiteral {
			sb.write_string('Obj{ObjT.f32,{F32={$node.value}}}')
		}
		StringLiteral {
			sb.write_string('Obj{ObjT.string,{String={"$node.value"}}}')
		}
		ExpressionStatement {
			sb.write_string(ctx.code_generator_nelua(node.expression))
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
			sb.write_string(name)
		}
		CallExpression {
			sb.write_string(ctx.code_generator_nelua(node.callee))
			sb.write_string('(')
			for i, e in node.arguments {
				if i > 0 {
					sb.write_string(', ')
				}
				sb.write_string(ctx.code_generator_nelua(e))
			}
			sb.write_string(')')
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
				sb.writeln('type Obj=u64|f32|int|string|[]Obj')
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
				sb.writeln('fn list(a...Obj)Obj{mut r:=Obj{}r=[]Obj{}if mut r is[]Obj{for e in a{r<<e}}return r}')
			}
			for e in node.body {
				sb.write_string(ctx.code_generator_v(e))
			}
		}
		NumberLiteral {
			sb.write_string('Obj(f32($node.value))')
		}
		StringLiteral {
			mut delim := "'"
			if node.value.contains("'") && !node.value.contains('"') {
				delim = '"'
			}
			sb.write_string('Obj($delim$node.value$delim)')
		}
		ExpressionStatement {
			sb.write_string(ctx.code_generator_v(node.expression))
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
			sb.write_string(name)
		}
		CallExpression {
			sb.write_string(ctx.code_generator_v(node.callee))
			sb.write_string('(')
			for i, e in node.arguments {
				if i > 0 {
					sb.write_string(', ')
				}
				sb.write_string(ctx.code_generator_v(e))
			}
			sb.write_string(')')
		}
		Call {
			name := match node.name {
				'+' { 'add' }
				'-' { 'subtract' }
				'*' { 'multiply' }
				'/' { 'divide' }
				'print', 'write' { 'println' }
				else { node.name }
			}
			sb.write_string(name)
			sb.write_string('(')
			for i, e in node.params {
				if i > 0 {
					sb.write_string(', ')
				}
				sb.write_string(ctx.code_generator_v(e))
			}
			sb.write_string(')')
		}
		Defun {
			sb.write_string('fn ')
			sb.write_string(node.name)
			sb.write_string('(')
			for i, e in node.arguments {
				if i > 0 {
					sb.write_string(', ')
				}
				sb.write_string(ctx.code_generator_v(e))
				sb.write_string(' Obj')
			}
			sb.writeln(') Obj {')
			sb.writeln('\tmut ret := Obj{}')
			for e in node.body {
				sb.write_string('\tret = ')
				sb.write_string(ctx.code_generator_v(e))
				sb.writeln('')
			}
			sb.writeln('\treturn ret')
			sb.writeln('}')
		}
		else {}
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
	if flags.has(.print_input) {
		eprintln('input=\\\n$ctx.source')
	}
	tokens := ctx.tokenizer(ctx.source)
	mut ast := ctx.parser(tokens)
	mut newast := ASTNode(ASTNode0{})
	ast, newast = ctx.transformer(mut &ast)
	mut output := ''
	if flags.has(.output_c) {
		output = ctx.code_generator_c(newast)
	}
	if flags.has(.output_nelua) {
		output = ctx.code_generator_nelua(newast)
	}
	if flags.has(.output_v) {
		output = ctx.code_generator_v(newast)
	}
	if flags.has(.print_output) {
		// println('output=\\\n$output')
		println('$output')
	}
	if '' != ctx.output_file {
		mut fout := os.create(ctx.output_file) or {
			os.File{
				cfile: 0
			}
		}
		fout.write_string(output) or {}
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
			// println('Just read input="$ctx.source"')
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
			ctx.flags.set(.print_input)
		} else if a == '--print-tokens' {
			ctx.flags.set(.print_tokens)
		} else if a == '--debug-tokens' {
			ctx.flags.set(.dtokens)
		} else if a == '--print-ast' {
			ctx.flags.set(.print_ast)
		} else if a == '--print-newast' {
			ctx.flags.set(.print_newast)
		} else if a == '--print-output' {
			ctx.flags.set(.print_output)
		} else if a == '--output-c' {
			ctx.flags.clear(output_mask)
			ctx.flags.set(.output_c)
		} else if a == '--output-nelua' {
			ctx.flags.clear(output_mask)
			ctx.flags.set(.output_nelua)
		} else if a == '--output-v' {
			ctx.flags.clear(output_mask)
			ctx.flags.set(.output_v)
		} else {
			// println('a="$a" input_file="$ctx.input_file"')
			if '' != ctx.input_file {
				panic('Input file set more than one time')
			}
			ctx.input_file = a
		}
	}
	if '' == ctx.output_file {
		ctx.flags.set(.print_output)
	}
}

fn main() {
	mut ctx := Context{
		flags: .output_c
		source: '(write(+ (* (/ 9 5) 60) 32))'
	}
	ctx.set_args()
	ctx.compiler()
}
