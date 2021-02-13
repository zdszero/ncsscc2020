%{
  #include "globals.h"
  #include "scan.h"
  #include "util.h"
  #include "symtab.h"
  #include "analyze.h"
  #include <string.h>
  #include <stdio.h>
  #include <stdlib.h>
  #include <ctype.h>
  int yylex();
  void yyerror(const char *);
  TreeNode *syntaxTree;
  static int ptrDepth = 0;
%}

%define api.value.type { TreeNode * }
%define parse.error detailed
%token INT VOID CHAR LONG IDENT NUM CH SEMI ASSIGN IF ELSE WHILE FOR RETURN
%token AND OR AMPERSAND ASTERISK
%token GLUE FUNC DECL CALL
%token PLUS MINUS TIMES OVER
%token EQ NE LE LT GE GT
%token LP RP LC RC
%left AND OR
%left EQ NE LE LT GE GT
%left PLUS MINUS
%left TIMES OVER
/* solve dangling else problem, prefer shift to reduce */
%precedence RP
%precedence ELSE

%%

program : declaration_list { syntaxTree = $1; }
        ;

declaration_list : declaration_list declaration
                   { YYSTYPE t = $1;
                     while (t->sibling)
                       t = t->sibling;
                     t->sibling = $2;
                     $$ = $1;
                   }
                 | declaration { $$ = $1; }
                 ;

declaration : var_declaraton   { $$ = $1; }
            | func_declaration { $$ = $1; }
            ;

var_declaraton : type_specifier var SEMI
                 { $$ = mkTreeNode(DECL);
                   setIdentType($2, Sym_Var, $1->type, ptrDepth);
                   ptrDepth = 0;
                   $$->children[0] = $2;
                   free($1);
                 }
               | type_specifier var ASSIGN expression SEMI
                 { $$ = mkTreeNode(DECL);
                   setIdentType($2, Sym_Var, $1->type, ptrDepth);
                   ptrDepth = 0;
                   typeCheck_Assign($2, $4);
                   $$->children[0] = $2;
                   $$->children[1] = $4;
                   free($1);
                 }
               ;

func_declaration : type_specifier var LP RP compound_statement
                   { $$ = mkTreeNode(FUNC);
                     setIdentType($2, Sym_Func, $1->type, ptrDepth);
                     ptrDepth = 0;
                     $$->children[0] = $2; $$->children[1] = $5;
                     typeCheck_HasReturn($1, $5, $2->attr.id);
                     free($1);
                   }
                 ;

type_specifier : INT   { $$ = mkTreeNode(INT);  $$->type = T_Int;  }
               | VOID  { $$ = mkTreeNode(VOID); $$->type = T_Void; }
               | CHAR  { $$ = mkTreeNode(CHAR); $$->type = T_Char; }
               | LONG  { $$ = mkTreeNode(LONG); $$->type = T_Long; }
               ;

statements : statements statement
             { YYSTYPE t = $1;
               while (t->sibling)
                 t = t->sibling;
               t->sibling = $2;
               $$ = $1;
             }
           | statement { $$ = $1; }
           ;

statement : var_declaraton       { $$ = $1; }
          | assign_statement     { $$ = $1; }
          | compound_statement   { $$ = $1; }
          | if_statement         { $$ = $1; }
          | while_statement      { $$ = $1; }
          | for_statement        { $$ = $1; }
          | expression_statement { $$ = $1; }
          | return_statement     { $$ = $1; }
          ;

assign_statement : var_ref ASSIGN expression SEMI
                   { typeCheck_Assign($1, $3);
                     $$ = mkTreeNode(ASSIGN);
                     $$->children[0] = $1;
                     $$->children[1] = $3;
                   }
                 ;

compound_statement : LC statements RC { $$ = $2; }
                   ;

if_statement : if_head
               { $$ = $1; }
             | if_head ELSE compound_statement
               { $$ = $1;
                 $$->children[2] = $3;
               }
             ;

if_head : IF LP expression RP compound_statement
          { $$ = mkTreeNode(IF);
            $$->children[0] = $3;
            $$->children[1] = $5;
          }
        ;

while_statement : WHILE LP expression RP compound_statement
                  { $$ = mkTreeNode(WHILE);
                    $$->children[0] = $3;
                    $$->children[1] = $5;
                  }
                ;

for_statement : FOR LP statement expression_statement post_statement RP compound_statement
                { $$ = mkTreeNode(GLUE);
                  $$->children[0] = $3;
                  $$->children[1] = mkTreeNode(WHILE);
                  $$->children[1]->children[0] = $4;
                  $$->children[1]->children[1] = mkTreeNode(GLUE);
                  $$->children[1]->children[1]->children[0] = $7;
                  $$->children[1]->children[1]->children[1] = $5;
                }
              ;

post_statement : var_ref ASSIGN expression
                 { $$ = mkTreeNode(ASSIGN);
                   $$->children[0] = $1;
                   $$->children[1] = $3;
                 }
               ;

expression_statement : expression SEMI { /* skip */ }
                     | SEMI { /* skip */ }
                     ;

return_statement : RETURN expression SEMI
                   { $$ = mkTreeNode(RETURN);
                     $$->children[0] = $2;
                   }
                 ;

var : TIMES var
      { ptrDepth++;
        $$ = $2;
      }
    | IDENT
      { $$ = mkTreeNode(IDENT);
        if (getIdentId(Tok.text) == -1) {
          /* cannot resolve symbol kind and type for now */
          $$->attr.id = newIdent(Tok.text, Sym_Unknown, T_None);
        }
        else {
          fprintf(Outfile, "Error: variable %s already defined, redefined at line %d\n", Tok.text, lineno);
          exit(1);
        }
      }
    ;

var_ref : TIMES var_ref
          { $$ = mkTreeNode(ASTERISK);
            $$->type = valueAt($2->type);
            $$->children[0] = $2;
          }
        | AMPERSAND var_ref
          { $$ = mkTreeNode(AMPERSAND);
            $$->type = pointerTo($2->type);
            $$->children[0] = $2;
          }
        | IDENT
          { $$ = mkTreeNode(IDENT);
            /* primitive function: printint */
            int id = getIdentId(Tok.text);
            if (id == -1) {
              fprintf(Outfile, "Error: variable %s is referred before defination at line %d\n", Tok.text, lineno);
              exit(1);
            } else {
              $$->attr.id = id;
              $$->type = getIdentType(id);
            }
          }
        ;

expression : expression AND expression
             { typeCheck_Compare($1, $3);
               $$ = mkTreeNode(AND);
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression OR expression
             { typeCheck_Compare($1, $3);
               $$ = mkTreeNode(OR);
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression EQ expression
             { typeCheck_Compare($1, $3);
               $$ = mkTreeNode(EQ);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression NE expression
             { typeCheck_Compare($1, $3);
               $$ = mkTreeNode(NE);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression GT expression
             { typeCheck_Compare($1, $3);
               $$ = mkTreeNode(GT);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression GE expression
             { typeCheck_Compare($1, $3);
               $$ = mkTreeNode(GE);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression LT expression
             { typeCheck_Compare($1, $3);
               $$ = mkTreeNode(LT);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression LE expression
             { typeCheck_Compare($1, $3);
               $$ = mkTreeNode(LE);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression PLUS expression
             { typeCheck_Calc($1, $3);
               $$ = mkTreeNode(PLUS);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression MINUS expression
             { typeCheck_Calc($1, $3);
               $$ = mkTreeNode(MINUS);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression TIMES expression
             { typeCheck_Calc($1, $3);
               $$ = mkTreeNode(TIMES);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | expression OVER expression
             { typeCheck_Calc($1, $3);
               $$ = mkTreeNode(OVER);
               $$->type = T_Long;
               $$->children[0] = $1;
               $$->children[1] = $3;
             }
           | LP expression RP { $$ = $2; }
           | NUM
             { $$ = mkTreeNode(NUM);
               $$->type = T_Long;
               $$->attr.val = Tok.numval;
             }
           | var_ref { $$ = $1; }
           | function_call { $$ = $1; }
           | CH
             { $$ = mkTreeNode(CH);
               $$->type = T_Char;
               $$->attr.ch = Tok.text[0];
             }
           ;

function_call : var_ref LP expression RP
                { $$ = mkTreeNode(CALL);
                  $$->children[0] = $1;
                  $$->children[1] = $3;
                }
              ;

%%

int yylex() {
  scan();
  return Tok.token;
}

void yyerror(const char *msg) {
  fprintf(stderr, "%s in line %d\n", msg, lineno);
  exit(1);
}
