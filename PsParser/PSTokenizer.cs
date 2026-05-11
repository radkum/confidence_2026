using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace PSParser;

/// <summary>
/// Tokenizer dla PowerShela - rozpoznaje tokeny i obsługuje string interpolation
/// </summary>
public class PSTokenizer
{
    private readonly string _source;
    private int _position;
    private int _line = 1;
    private int _column = 1;
    private readonly List<Token> _tokens = new();

    private static readonly Dictionary<string, TokenType> Keywords = new(StringComparer.OrdinalIgnoreCase)
    {
        ["if"] = TokenType.If,
        ["else"] = TokenType.Else,
        ["elseif"] = TokenType.ElseIf,
        ["for"] = TokenType.For,
        ["foreach"] = TokenType.ForEach,
        ["while"] = TokenType.While,
        ["do"] = TokenType.Do,
        ["try"] = TokenType.Try,
        ["catch"] = TokenType.Catch,
        ["finally"] = TokenType.Finally,
        ["function"] = TokenType.Function,
        ["filter"] = TokenType.Filter,
        ["param"] = TokenType.Param,
        ["return"] = TokenType.Return,
        ["break"] = TokenType.Break,
        ["continue"] = TokenType.Continue,
        ["throw"] = TokenType.Throw,
        ["true"] = TokenType.Boolean,
        ["false"] = TokenType.Boolean,
    };

    private static readonly Dictionary<string, TokenType> CompoundOperators = new(StringComparer.OrdinalIgnoreCase)
    {
        ["-eq"] = TokenType.EqualTo,
        ["-ne"] = TokenType.NotEqualTo,
        ["-lt"] = TokenType.LessThan,
        ["-gt"] = TokenType.GreaterThan,
        ["-le"] = TokenType.LessThanOrEqual,
        ["-ge"] = TokenType.GreaterThanOrEqual,
        ["-match"] = TokenType.Match,
        ["-notmatch"] = TokenType.NotMatch,
        ["-like"] = TokenType.Like,
        ["-notlike"] = TokenType.NotLike,
        ["-contains"] = TokenType.Contains,
        ["-notcontains"] = TokenType.NotContains,
        ["-in"] = TokenType.In,
        ["-notin"] = TokenType.NotIn,
        ["-and"] = TokenType.And,
        ["-or"] = TokenType.Or,
        ["-not"] = TokenType.Not,
        ["-band"] = TokenType.BitwiseAnd,
        ["-bor"] = TokenType.BitwiseOr,
        ["-bxor"] = TokenType.BitwiseXor,
        ["-bnot"] = TokenType.BitwiseNot,
        ["-shl"] = TokenType.LeftShift,
        ["-shr"] = TokenType.RightShift,
    };

    public PSTokenizer(string source)
    {
        _source = source ?? string.Empty;
    }

    /// <summary>
    /// Tokenizuje kod i zwraca listę tokenów
    /// </summary>
    public List<Token> Tokenize()
    {
        while (_position < _source.Length)
        {
            SkipWhitespace();

            if (_position >= _source.Length)
                break;

            if (PeekChar() == '#')
            {
                ScanComment();
            }
            else if (PeekChar() == '\r' || PeekChar() == '\n')
            {
                ScanNewline();
            }
            else if (PeekChar() == '"')
            {
                ScanExpandableString();
            }
            else if (PeekChar() == '\'')
            {
                ScanLiteralString();
            }
            else if (PeekChar() == '$')
            {
                ScanVariable();
            }
            else if (char.IsLetter(PeekChar()) || PeekChar() == '_')
            {
                ScanIdentifierOrKeyword();
            }
            else if (char.IsDigit(PeekChar()))
            {
                ScanNumber();
            }
            else
            {
                ScanOperatorOrDelimiter();
            }
        }

        _tokens.Add(new Token(TokenType.EndOfFile, "", _line, _column, _position, 0));
        return _tokens;
    }

    private void SkipWhitespace()
    {
        while (_position < _source.Length && char.IsWhiteSpace(PeekChar()) && PeekChar() != '\r' && PeekChar() != '\n')
        {
            Advance();
        }
    }

    private void ScanComment()
    {
        int start = _position;
        int startCol = _column;
        Advance(); // Skip '#'

        while (_position < _source.Length && PeekChar() != '\r' && PeekChar() != '\n')
        {
            Advance();
        }

        string value = _source[start.._position];
        AddToken(TokenType.Comment, value, startCol);
    }

    private void ScanNewline()
    {
        int start = _position;
        int startCol = _column;

        if (PeekChar() == '\r' && PeekNextChar() == '\n')
        {
            Advance();
            Advance();
        }
        else
        {
            Advance();
        }

        _line++;
        _column = 1;
        AddToken(TokenType.Newline, "\n", startCol);
    }

    /// <summary>
    /// Skanuje expandowalny string (z $variables lub $(expressions))
    /// </summary>
    private void ScanExpandableString()
    {
        int start = _position;
        int startCol = _column;
        Advance(); // Skip opening "

        var stringParts = new StringBuilder();
        bool hasInterpolation = false;

        while (_position < _source.Length && PeekChar() != '"')
        {
            if (PeekChar() == '\\')
            {
                // Escape sequence
                Advance();
                if (_position < _source.Length)
                {
                    stringParts.Append(HandleEscapeSequence());
                    Advance();
                }
            }
            else if (PeekChar() == '$')
            {
                hasInterpolation = true;
                stringParts.Append(ScanInterpolationExpression());
            }
            else
            {
                stringParts.Append(PeekChar());
                Advance();
            }
        }

        if (_position < _source.Length)
        {
            Advance(); // Skip closing "
        }

        string value = _source[start.._position];
        AddToken(hasInterpolation ? TokenType.ExpandableString : TokenType.String, value, startCol);
    }

    /// <summary>
    /// Skanuje wyrażenie interpolacji w stringu (np. $variable lub $(expression))
    /// </summary>
    private string ScanInterpolationExpression()
    {
        var result = new StringBuilder();
        result.Append(PeekChar()); // Append $
        Advance();

        if (_position < _source.Length && PeekChar() == '{')
        {
            // $(expression) - complex interpolation
            result.Append('{');
            Advance();

            int braceDepth = 1;
            while (_position < _source.Length && braceDepth > 0)
            {
                if (PeekChar() == '{')
                    braceDepth++;
                else if (PeekChar() == '}')
                    braceDepth--;

                result.Append(PeekChar());
                Advance();
            }
        }
        else
        {
            // $variable - simple variable reference
            while (_position < _source.Length && (char.IsLetterOrDigit(PeekChar()) || PeekChar() == '_'))
            {
                result.Append(PeekChar());
                Advance();
            }
        }

        return result.ToString();
    }

    private void ScanLiteralString()
    {
        int start = _position;
        int startCol = _column;
        Advance(); // Skip opening '

        while (_position < _source.Length && PeekChar() != '\'')
        {
            if (PeekChar() == '\\' && PeekNextChar() == '\'')
            {
                // Escaped quote
                Advance();
                Advance();
            }
            else
            {
                Advance();
            }
        }

        if (_position < _source.Length)
        {
            Advance(); // Skip closing '
        }

        string value = _source[start.._position];
        AddToken(TokenType.String, value, startCol);
    }

    private void ScanVariable()
    {
        int start = _position;
        int startCol = _column;
        Advance(); // Skip $

        if (_position < _source.Length && PeekChar() == '{')
        {
            // ${variable name}
            Advance();
            while (_position < _source.Length && PeekChar() != '}')
            {
                Advance();
            }
            if (_position < _source.Length)
                Advance();
        }
        else
        {
            // $variableName
            while (_position < _source.Length && (char.IsLetterOrDigit(PeekChar()) || PeekChar() == '_'))
            {
                Advance();
            }
        }

        string value = _source[start.._position];
        AddToken(TokenType.Variable, value, startCol);
    }

    private void ScanIdentifierOrKeyword()
    {
        int start = _position;
        int startCol = _column;

        while (_position < _source.Length && (char.IsLetterOrDigit(PeekChar()) || PeekChar() == '_' || PeekChar() == '-'))
        {
            Advance();
        }

        string value = _source[start.._position];

        if (Keywords.TryGetValue(value, out var keywordType))
        {
            AddToken(keywordType, value, startCol);
        }
        else
        {
            AddToken(TokenType.Identifier, value, startCol);
        }
    }

    private void ScanNumber()
    {
        int start = _position;
        int startCol = _column;

        while (_position < _source.Length && char.IsDigit(PeekChar()))
        {
            Advance();
        }

        if (_position < _source.Length && PeekChar() == '.' && PeekNextChar() != '.')
        {
            Advance();
            while (_position < _source.Length && char.IsDigit(PeekChar()))
            {
                Advance();
            }
        }

        string value = _source[start.._position];
        AddToken(TokenType.Number, value, startCol);
    }

    private void ScanOperatorOrDelimiter()
    {
        int startCol = _column;

        // Try two-character operators first
        if (_position + 1 < _source.Length)
        {
            string twoChar = new string(new[] { PeekChar(), PeekNextChar() });

            if (CompoundOperators.TryGetValue(twoChar, out var opType))
            {
                Advance();
                Advance();
                AddToken(opType, twoChar, startCol);
                return;
            }

            if (twoChar == "::")
            {
                Advance();
                Advance();
                AddToken(TokenType.DoubleColon, "::", startCol);
                return;
            }
        }

        // Single character operators
        char ch = PeekChar();
        Advance();

        TokenType type = ch switch
        {
            '|' => TokenType.Pipe,
            '+' => TokenType.Plus,
            '-' => TokenType.Minus,
            '*' => TokenType.Multiply,
            '/' => TokenType.Divide,
            '%' => TokenType.Modulo,
            '=' => TokenType.Equals,
            '(' => TokenType.LeftParen,
            ')' => TokenType.RightParen,
            '{' => TokenType.LeftBrace,
            '}' => TokenType.RightBrace,
            '[' => TokenType.LeftBracket,
            ']' => TokenType.RightBracket,
            ';' => TokenType.Semicolon,
            ',' => TokenType.Comma,
            '.' => TokenType.Dot,
            ':' => TokenType.Colon,
            '?' => TokenType.Question,
            '@' => TokenType.At,
            _ => TokenType.Unknown
        };

        AddToken(type, ch.ToString(), startCol);
    }

    private char HandleEscapeSequence()
    {
        char ch = PeekChar();
        return ch switch
        {
            'n' => '\n',
            't' => '\t',
            'r' => '\r',
            '\\' => '\\',
            '"' => '"',
            '$' => '$',
            '`' => '`',
            _ => ch
        };
    }

    private char PeekChar() => _position < _source.Length ? _source[_position] : '\0';

    private char PeekNextChar() => _position + 1 < _source.Length ? _source[_position + 1] : '\0';

    private void Advance()
    {
        if (_position < _source.Length)
        {
            if (_source[_position] == '\n')
            {
                _line++;
                _column = 1;
            }
            else
            {
                _column++;
            }
            _position++;
        }
    }

    private void AddToken(TokenType type, string value, int startCol)
    {
        _tokens.Add(new Token(type, value, _line, startCol, _position - value.Length, value.Length));
    }
}
