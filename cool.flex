/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int comment_depth=0;
int escape_pending=0;
int string_error=0;

#define inc_line() \
    {\
        curr_lineno++;\
    }

%}

/*
 * Define names for regular expressions here.
 */


TYPEID	        [A-Z][_a-zA-Z0-9]*
OBJID	        [a-z][_a-zA-Z0-9]*
WHITESPACE      [ \r\f\t\v]+
SINGLE          [:@,;(){}=<~/\-\*\+\.]
NEWLINE         [\n]
INTEGER         [0-9]+
BEGINC          \(\*
ENDC            \*\)
BEGIN_LINEC     --
CLASS           [cC][lL][aA][sS][sS]
ELSE            [eE][lL][sS][eE]
FI		[fF][iI]
IF		[iI][fF]
IN		[iI][nN]
INHERITS	[iI][nN][hH][eE][rR][iI][tT][sS]
LET		[lL][eE][tT]
LOOP		[lL][oO][oO][pP]
POOL		[pP][oO][oO][lL]
THEN		[tT][hH][eE][nN]
WHILE		[wW][hH][iI][lL][eE]
CASE		[cC][aA][sS][eE]
ESAC		[eE][sS][aA][cC]
OF		[oO][fF]
NEW		[nN][eE][wW]
TRUE            t[rR][uU][eE]
FALSE           f[aA][lL][sS][eE]
ISVOID          [iI][sS][vV][oO][iI][dD]
NOT             [nN][oO][tT]
ASSIGN          <-
LE              <=
DARROW          =>



%START COMMENT
%START LINECOMMENT
%START STRING

%%

 /*
  *  Nested comments
  */


 /*
  *  The multiple-character operators.
  */

<COMMENT>{BEGINC}       { comment_depth++;BEGIN COMMENT;}
<INITIAL>{BEGINC}       { comment_depth++;BEGIN COMMENT;}
<COMMENT>{NEWLINE}      { inc_line(); }
<COMMENT>[^\*\(\n]+     ;
<COMMENT>\([^\*\n]      ;
<COMMENT>\*             ;
<COMMENT>{ENDC}         { comment_depth--;if (0==comment_depth) { BEGIN 0;}}
<COMMENT><<EOF>>        { 
                            cool_yylval.error_msg = "EOF in comment";
                            BEGIN INITIAL;
                            return(ERROR); 
                        }
<INITIAL>{ENDC}         { 
                            cool_yylval.error_msg = "unmatched *)";
                            return(ERROR); 
                        }
<INITIAL>{BEGIN_LINEC}  { BEGIN LINECOMMENT;}
<LINECOMMENT>{NEWLINE}  { inc_line(); BEGIN INITIAL;}
<LINECOMMENT>.+         ;
<STRING><<EOF>>         { 
                            cool_yylval.error_msg = "EOF in string constant";
                            BEGIN INITIAL;
                            return(ERROR); 
                        }
<STRING>\n              { 
                            inc_line();
                            if (escape_pending) {
                                char c = yytext[0];
                                string_buf_ptr[-1] = c;
                                *string_buf_ptr = '\0';
                                escape_pending=0;
                           } else {
                                BEGIN INITIAL;
                                if (!string_error) {
                                    cool_yylval.error_msg = "Unterminated string constant";
                                    return(ERROR); 
                                }
                           }
                        }
<STRING>.               { 
                            char c = yytext[0];
                            if (escape_pending) {
                                if (c=='n') {
                                    c='\n';
                                } else if (c=='t') {
                                    c='\t';
                                } else if (c=='f') {
                                    c='\f';
                                } else if (c=='b') {
                                    c='\b';
                                } else if (c=='\0') {
                                    cool_yylval.error_msg = "String contains escaped null character.";
                                    escape_pending=0;
                                    string_error = 1;
                                    return(ERROR); 
                                }

                                string_buf_ptr[-1] = c;
                                *string_buf_ptr = '\0';
                                escape_pending=0;
                            } else if (c=='\0') {
                                cool_yylval.error_msg = "String contains null character.";
                                string_error = 1;
                                return(ERROR); 
                            } else if (c=='"' || c=='\n') {
                                if (!string_error) {
                                    *string_buf_ptr = '\0';
                                    cool_yylval.symbol = stringtable.add_string(string_buf);
                                    string_error = 0;
                                    BEGIN INITIAL; 
                                    return(STR_CONST); 
                                }
                                string_error = 0;
                                BEGIN INITIAL; 
                            } else if (strlen(string_buf)+2>MAX_STR_CONST) {
                                if (!string_error) {
                                    cool_yylval.error_msg = "string constant too long";
                                    string_error = 1;
                                    return(ERROR); 
                                }
                            } else {
                                if (c=='\\') {
                                    escape_pending=1;
                                }
                                *string_buf_ptr++ = c;
                                *string_buf_ptr = '\0';
                            }
                        }
<INITIAL>\"             { 
                            string_buf_ptr = &string_buf[0]; 
                            *string_buf_ptr='\0';
                            BEGIN STRING;
                        }
<INITIAL>{NEWLINE}               {inc_line();}
<INITIAL>{WHITESPACE}            ;
<INITIAL>{SINGLE}                { return(yytext[0]); }
<INITIAL>{ASSIGN}                { return(ASSIGN); }
<INITIAL>{LE}                    { return(LE); }
<INITIAL>{DARROW}                { return(DARROW); }
<INITIAL>{CLASS}                 { return(CLASS);}
<INITIAL>{ELSE}                  { return(ELSE);}
<INITIAL>{FI}                    { return(FI); };
<INITIAL>{IF}                    { return(IF); };
<INITIAL>{IN}                    { return(IN); };
<INITIAL>{INHERITS}              { return(INHERITS); };
<INITIAL>{LET}                   { return(LET); };
<INITIAL>{LOOP}                  { return(LOOP); };
<INITIAL>{POOL}                  { return(POOL); };
<INITIAL>{THEN}                  { return(THEN); };
<INITIAL>{WHILE}                 { return(WHILE); };
<INITIAL>{CASE}                  { return(CASE); };
<INITIAL>{ESAC}                  { return(ESAC); };
<INITIAL>{OF}                    { return(OF); };
<INITIAL>{NEW}                   { return(NEW); };
<INITIAL>{ISVOID}                { return(ISVOID); };
<INITIAL>{NOT}                   { return(NOT); };
<INITIAL>{TRUE}                  { 
                            cool_yylval.boolean = 1;
                            return(BOOL_CONST); 
                        }
<INITIAL>{FALSE}                 { 
                            cool_yylval.boolean = 0;
                            return(BOOL_CONST); 
                        }

<INITIAL>{TYPEID}       { 
                            cool_yylval.symbol = idtable.add_string(yytext);
                            return(TYPEID); 
                        } 
<INITIAL>{OBJID}        { 
                            cool_yylval.symbol = idtable.add_string(yytext);
                            return(OBJECTID); 
                        } 
<INITIAL>{INTEGER}               { 
                            cool_yylval.symbol = inttable.add_string(yytext);
                            return(INT_CONST); 
                        } 

<INITIAL>.              { 
                            cool_yylval.error_msg = yytext;
                            return(ERROR); 
                        }




 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


%%

