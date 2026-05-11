using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace PSParser;

/// <summary>
/// Parser dla PowerShela - konwertuje tokeny na AST
/// </summary>
public class PSParser
{
    private readonly List<Token> _tokens;
    private int _current;

    public PSParser(List<Token> tokens)
    {
        _tokens = tokens;
    }

    public static PSParser FromSource(string source)
    {
        var tokenizer = new PSTokenizer(source);
        var tokens = tokenizer.Tokenize();
        return new PSParser(tokens);
    }

    /// <summary>
    /// Parsuje kod i zwraca AST
    /// </summary>
    public ScriptBlock Parse()
    {
        var script = new ScriptBlock();

        while (!IsAtEnd())
        {
            SkipNewlines();

            if (IsAtEnd())
                break;

            var stmt = ParseStatement();
            if (stmt != null)
            {
                script.Statements.Add(stmt);
            }

            SkipNewlines();
        }

        return script;
    }

    private Statement ParseStatement()
    {
        SkipNewlines();

        if (Check(TokenType.If))
            return ParseIfStatement();

        if (Check(TokenType.Function))
            return ParseFunctionDefinition();

        if (Check(TokenType.Variable))
        {
            var varToken = Peek();
            Advance();

            if (Check(TokenType.Equals))
            {
                Advance();
                var expr = ParseExpression();
                SkipStatementTerminator();
                return new AssignmentStatement
                {
                    Line = varToken.Line,
                    Column = varToken.Column,
                    VariableName = varToken.Value,
                    Value = expr
                };
            }
            else
            {
                _current--;
                var expr = ParseExpression();
                SkipStatementTerminator();
                return new ExpressionStatement
                {
                    Line = varToken.Line,
                    Column = varToken.Column,
                    Expression = expr
                };
            }
        }

        if (Check(TokenType.Identifier))
        {
            var expr = ParseExpression();
            SkipStatementTerminator();
            return new ExpressionStatement
            {
                Line = expr.Line,
                Column = expr.Column,
                Expression = expr
            };
        }

        if (Check(TokenType.String, TokenType.ExpandableString, TokenType.Number,
                  TokenType.Boolean, TokenType.LeftParen))
        {
            var expr = ParseExpression();
            SkipStatementTerminator();
            return new ExpressionStatement
            {
                Line = expr.Line,
                Column = expr.Column,
                Expression = expr
            };
        }

        // Safety: skip unknown token to avoid infinite loop
        if (!IsAtEnd())
            SkipStatementTerminator();
        if (!IsAtEnd() && !Check(TokenType.Newline, TokenType.Semicolon))
            Advance();
        return null;
    }

    private IfStatement ParseIfStatement()
    {
        var ifToken = Advance();
        Consume(TokenType.LeftParen, "Expected '(' after 'if'");

        var condition = ParseExpression();

        Consume(TokenType.RightParen, "Expected ')' after if condition");
        Consume(TokenType.LeftBrace, "Expected '{' for if body");

        var thenBranch = ParseStatementBlock();

        var elseBranch = new List<Statement>();
        if (Check(TokenType.Else))
        {
            Advance();
            if (Check(TokenType.LeftBrace))
            {
                Advance();
                elseBranch = ParseStatementBlock();
            }
        }

        return new IfStatement
        {
            Line = ifToken.Line,
            Column = ifToken.Column,
            Condition = condition,
            ThenBranch = thenBranch,
            ElseBranch = elseBranch
        };
    }

    private FunctionDefinition ParseFunctionDefinition()
    {
        var funcToken = Advance();
        var nameToken = Consume(TokenType.Identifier, "Expected function name");

        var parameters = new List<string>();

        if (Check(TokenType.LeftParen))
        {
            Advance();
            while (!Check(TokenType.RightParen) && !IsAtEnd())
            {
                var paramToken = Consume(TokenType.Identifier, "Expected parameter name");
                parameters.Add(paramToken.Value);

                if (Check(TokenType.Comma))
                    Advance();
            }
            Consume(TokenType.RightParen, "Expected ')' after parameters");
        }

        Consume(TokenType.LeftBrace, "Expected '{' for function body");
        var body = ParseStatementBlock();

        return new FunctionDefinition
        {
            Line = funcToken.Line,
            Column = funcToken.Column,
            FunctionName = nameToken.Value,
            Parameters = parameters,
            Body = body
        };
    }

    private List<Statement> ParseStatementBlock()
    {
        var statements = new List<Statement>();

        while (!Check(TokenType.RightBrace) && !IsAtEnd())
        {
            SkipNewlines();
            if (Check(TokenType.RightBrace))
                break;

            var stmt = ParseStatement();
            if (stmt != null)
                statements.Add(stmt);
        }

        Consume(TokenType.RightBrace, "Expected '}' after block");
        return statements;
    }

    private Expression ParseExpression()
    {
        return ParsePipeline();
    }

    private Expression ParsePipeline()
    {
        var left = ParseLogicalOr();

        if (Check(TokenType.Pipe))
        {
            var segments = new List<Expression> { left };

            while (Check(TokenType.Pipe))
            {
                Advance();
                segments.Add(ParseLogicalOr());
            }

            return new PipelineExpression
            {
                Line = left.Line,
                Column = left.Column,
                Segments = segments
            };
        }

        return left;
    }

    private Expression ParseLogicalOr()
    {
        var left = ParseLogicalAnd();

        while (Check(TokenType.Or))
        {
            var opToken = Advance();
            var right = ParseLogicalAnd();
            left = new BinaryExpression
            {
                Line = left.Line,
                Column = left.Column,
                Left = left,
                Operator = opToken.Value,
                Right = right
            };
        }

        return left;
    }

    private Expression ParseLogicalAnd()
    {
        var left = ParseComparison();

        while (Check(TokenType.And))
        {
            var opToken = Advance();
            var right = ParseComparison();
            left = new BinaryExpression
            {
                Line = left.Line,
                Column = left.Column,
                Left = left,
                Operator = opToken.Value,
                Right = right
            };
        }

        return left;
    }

    private Expression ParseComparison()
    {
        var left = ParseAddition();

        while (Check(TokenType.EqualTo, TokenType.NotEqualTo, TokenType.LessThan,
                     TokenType.GreaterThan, TokenType.LessThanOrEqual, TokenType.GreaterThanOrEqual,
                     TokenType.Match, TokenType.NotMatch, TokenType.Like, TokenType.NotLike,
                     TokenType.Contains, TokenType.NotContains, TokenType.In, TokenType.NotIn))
        {
            var opToken = Advance();
            var right = ParseAddition();
            left = new BinaryExpression
            {
                Line = left.Line,
                Column = left.Column,
                Left = left,
                Operator = opToken.Value,
                Right = right
            };
        }

        return left;
    }

    private Expression ParseAddition()
    {
        var left = ParseMultiplication();

        while (Check(TokenType.Plus, TokenType.Minus))
        {
            var opToken = Advance();
            var right = ParseMultiplication();
            left = new BinaryExpression
            {
                Line = left.Line,
                Column = left.Column,
                Left = left,
                Operator = opToken.Value,
                Right = right
            };
        }

        return left;
    }

    private Expression ParseMultiplication()
    {
        var left = ParseUnary();

        while (Check(TokenType.Multiply, TokenType.Divide, TokenType.Modulo))
        {
            var opToken = Advance();
            var right = ParseUnary();
            left = new BinaryExpression
            {
                Line = left.Line,
                Column = left.Column,
                Left = left,
                Operator = opToken.Value,
                Right = right
            };
        }

        return left;
    }

    private Expression ParseUnary()
    {
        if (Check(TokenType.Not, TokenType.Minus))
        {
            var opToken = Advance();
            var expr = ParseUnary();
            // Wrap as binary expression with unary operator
            return new BinaryExpression
            {
                Line = opToken.Line,
                Column = opToken.Column,
                Left = null,
                Operator = opToken.Value,
                Right = expr
            };
        }

        return ParsePostfix();
    }

    private Expression ParsePostfix()
    {
        var expr = ParsePrimary();

        while (Check(TokenType.LeftBracket) || Check(TokenType.Dot))
        {
            if (Check(TokenType.LeftBracket))
            {
                Advance();
                var index = ParseExpression();
                Consume(TokenType.RightBracket, "Expected ']'");
                // For now, just continue with expr
            }
            else if (Check(TokenType.Dot))
            {
                Advance();
                var memberName = Consume(TokenType.Identifier, "Expected member name");
                // For now, just continue with expr
            }
        }

        return expr;
    }

    private Expression ParsePrimary()
    {
        var token = Peek();

        if (Check(TokenType.String, TokenType.ExpandableString))
        {
            return ParseString();
        }

        if (Check(TokenType.Number))
        {
            Advance();
            return new NumberLiteral
            {
                Line = token.Line,
                Column = token.Column,
                Value = token.Value
            };
        }

        if (Check(TokenType.Boolean))
        {
            Advance();
            return new BooleanLiteral
            {
                Line = token.Line,
                Column = token.Column,
                Value = token.Value.Equals("true", StringComparison.OrdinalIgnoreCase)
            };
        }

        if (Check(TokenType.Variable))
        {
            Advance();
            return new VariableReference
            {
                Line = token.Line,
                Column = token.Column,
                Name = token.Value
            };
        }

        if (Check(TokenType.LeftParen))
        {
            Advance();
            var expr = ParseExpression();
            Consume(TokenType.RightParen, "Expected ')'");
            return expr;
        }

        if (Check(TokenType.Identifier))
        {
            return ParseFunctionCallOrIdentifier();
        }

        throw new ParseException($"Unexpected token: {token}");
    }

    private StringLiteral ParseString()
    {
        var token = Advance();
        var literal = new StringLiteral
        {
            Line = token.Line,
            Column = token.Column,
            Value = token.Value,
            IsExpandable = token.Type == TokenType.ExpandableString
        };

        if (literal.IsExpandable)
        {
            literal.InterpolationSegments = ExtractInterpolationSegments(token.Value);
        }

        return literal;
    }

    /// <summary>
    /// Wyodrębnia segmenty interpolacji z expandowalnego stringu
    /// </summary>
    private List<InterpolationSegment> ExtractInterpolationSegments(string expandableString)
    {
        var segments = new List<InterpolationSegment>();

        // Usuwamy cudzysłowy
        string content = expandableString;
        if (content.StartsWith("\"") && content.EndsWith("\""))
        {
            content = content[1..^1];
        }

        // Regex do matchowania $variables i $(expressions)
        var regex = new Regex(@"\$(?:\{([^}]+)\}|([a-zA-Z_]\w*))");
        int lastIndex = 0;

        foreach (Match match in regex.Matches(content))
        {
            // Dodajemy tekst przed matchem
            if (match.Index > lastIndex)
            {
                segments.Add(new InterpolationSegment
                {
                    Type = "text",
                    Content = content[lastIndex..match.Index]
                });
            }

            // Dodajemy variable/expression
            string varContent = match.Groups[1].Value;
            if (string.IsNullOrEmpty(varContent))
                varContent = match.Groups[2].Value;

            segments.Add(new InterpolationSegment
            {
                Type = "variable",
                Content = varContent
            });

            lastIndex = match.Index + match.Length;
        }

        // Dodajemy pozostały tekst
        if (lastIndex < content.Length)
        {
            segments.Add(new InterpolationSegment
            {
                Type = "text",
                Content = content[lastIndex..]
            });
        }

        return segments;
    }

    private Expression ParseFunctionCallOrIdentifier()
    {
        var token = Advance();

        if (Check(TokenType.LeftParen))
        {
            Advance();
            var args = ParseArguments();
            Consume(TokenType.RightParen, "Expected ')'");

            return new FunctionCall
            {
                Line = token.Line,
                Column = token.Column,
                FunctionName = token.Value,
                Arguments = args
            };
        }

        return new FunctionCall
        {
            Line = token.Line,
            Column = token.Column,
            FunctionName = token.Value,
            Arguments = new List<Expression>()
        };
    }

    private List<Expression> ParseArguments()
    {
        var args = new List<Expression>();

        while (!Check(TokenType.RightParen) && !IsAtEnd())
        {
            args.Add(ParseExpression());
            if (Check(TokenType.Comma))
                Advance();
        }

        return args;
    }

    private void SkipNewlines()
    {
        while (Check(TokenType.Newline))
            Advance();
    }

    private void SkipStatementTerminator()
    {
        while (Check(TokenType.Semicolon, TokenType.Newline))
            Advance();
    }

    private bool Check(params TokenType[] types)
    {
        if (IsAtEnd())
            return false;
        return types.Contains(Peek().Type);
    }

    private Token Advance()
    {
        if (!IsAtEnd())
            _current++;
        return Previous();
    }

    private bool IsAtEnd()
    {
        return Peek().Type == TokenType.EndOfFile;
    }

    private Token Peek()
    {
        return _tokens[_current];
    }

    private Token Previous()
    {
        return _tokens[_current - 1];
    }

    private Token Consume(TokenType type, string message)
    {
        if (Check(type))
            return Advance();

        throw new ParseException($"{message} (got {Peek().Type})");
    }
}

public class ParseException : Exception
{
    public ParseException(string message) : base(message) { }
}
