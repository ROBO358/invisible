require 'logger'
require 'optparse'
require 'strscan'

class INVISIBLE
    Keywords = {
        "ð·" => :left_parn,       # (         U+1D177
        "ð¸" => :right_parn,      # )         U+1D178
        "ð³" => :left_brace,      # {         U+1D173
        "ð´" => :right_brace,     # }         U+1D174
        "â" => :assign,  # :=        U+200E
        "â " => :semicolon,      # ;         U+2800
        "Â­" => :if,              # if        U+00AD
        "Í" => :then,            # then      U+0034F
        "Ø" => :else,    # else      U+061C
        "â¡" => :repeat,          # repeat    U+2061
        "â " => :print_cha,       # print_cha U+2060
        "â£" => :print_num,       # print_num U+2063
        "â¢" => :read_cha,        # read_cha  U+2062
        "â" => :read_num,       # read_num  U+205F
        "â" => :add,            # +         U+2000
        "â" => :sub,            # -         U+2001
        "â" => :mul,            # *         U+2002
        "â" => :div,            # /         U+2003
        "â" => :high,            # high      U+200D
        "â" => :low,             # low       U+200C
    }

    # ã¤ã³ã¹ã¿ã³ã¹åæã«å®è¡ããã
    def initialize
        # ã³ã¼ã
        code = nil
        # ã­ã°åºåç¨
        @logger = Logger.new(STDOUT)
        ## ãªãªã¼ã¹ç¨ã¬ãã«
        @logger.level = Logger::WARN

        # OptionParserã®ã¤ã³ã¹ã¿ã³ã¹ãä½æ
        opt = OptionParser.new

        # åãªãã·ã§ã³(.parse!æå®è¡)
        # ãããã°ç¨
        opt.on('-d', '--debug') {@logger.level = Logger::DEBUG}

        # ãªãã·ã§ã³ãåãåã
        opt.parse!(ARGV)

        # ãããã°ç¶æã®ç¢ºèª
        @logger.debug('DEBUG MODE')

        # ãã¡ã¤ã«ãæå®ããã¦ããå ´åããã¡ã¤ã«ãéã
        if ARGV.length > 0
            begin
                code = ARGF.read
            rescue Errno::ENOENT => e
                @logger.fatal(e.message)
                exit
            end
        else
            @logger.fatal("ãã¡ã¤ã«ãæå®ããã¦ãã¾ãã")
            exit
        end

        begin
            # å®è¡ããã¨ãã
            @logger.debug("code: #{code}")
            @logger.debug("code(Unicodeã³ã¼ããã¤ã³ã): #{code.codepoints.map{|v| v.to_s(16)}}")

            # å­å¥è§£æå®è¡
            tokens = tokenize(code)

            # æ§æè§£æå®è¡
            @logger.debug("### æ§æè§£æå®è¡ ###")
            constructs = parse(tokens)

            # å¤æ°ã®ããã·ã¥ãªã»ãã
            @variables = Hash.new
            # æå³è§£æå®è¡
            @logger.debug("### æå³è§£æå®è¡ ###")
            evaluate(constructs)
        rescue => e
            @logger.debug(e)
            @logger.fatal(e.message)
            exit
        end

        return
    end

    # å­å¥è§£æ
    private def tokenize(code)

        def get_token(code_scanner)
            # ããã§ããã¼ã¯ã³ã®ç¨®é¡ãå¤å¥ãã
            if  code_scanner.scan(/(?:#{Keywords.keys.map{|key|Regexp.escape(key)}.join('|')})/)
                @logger.debug("matched_key: #{code_scanner.matched.codepoints.map{|v| v.to_s(16)}.join(",")}")
                return Keywords[code_scanner.matched]
            else
                @logger.debug("matched: nil")
                return nil
            end
        end

        # ä¸è¦ãªã³ã¡ã³ããåé¤
        code = code.gsub(/[^#{Keywords.keys.map{|key|Regexp.escape(key)}.join()}]/, '')

        @logger.debug("code: #{code}")
        @logger.debug("code(Unicodeã³ã¼ããã¤ã³ã): #{code.codepoints.map{|v| v.to_s(16)}}")

        # æå­åããã¼ã¯ã³ã«åå²
        code_scanner = StringScanner.new(code)
        tokens = []
        while !code_scanner.eos?
            token = get_token(code_scanner)
            if token.nil?
                @logger.fatal("ä¸æ­£ãªæå­ãå«ã¾ãã¦ãã¾ã")
                exit
            end
            tokens << token
        end

        @logger.debug("tokens: #{tokens}")
        return tokens
    end

    # æ§æè§£æ
    private def parse(tokens)
        @tokens = tokens
        @pos = 0

        def get_token()
            token = @tokens[@pos]
            @pos += 1
            return token
        end

        def unget_token()
            @pos -= 1
            return @tokens[@pos]
        end

        # æå
        def sentences()
            unless s = sentence()
                raise Exception, "æãããã¾ãã"
            end
            result = [:block, s]
            while s = sentence()
                result << s
            end
            @logger.debug("sentences: #{result}")
            return result
        end

        # æ
        def sentence()
            case get_token()
            when :left_brace
                s = sentences()
                @logger.debug("sentences: #{s}")
                unget_token if get_token() != :semicolon
                raise Exception, "å³æ¬å¼§ãããã¾ãã" if get_token() != :right_brace
                return s
            when :if
                conditional_expression = expression()
                @logger.debug("conditional_expression: #{conditional_expression}")
                raise Exception, "thenãããã¾ãã" if get_token() != :then
                then_sentence = sentence()
                unget_token if get_token() != :semicolon
                @logger.debug("then_sentences: #{then_sentence}")
                if get_token() != :else
                    @logger.debug("elseãããã¾ãã")
                    unget_token()
                    return [:if, conditional_expression, then_sentence]
                end
                else_sentence = sentence()
                unget_token if get_token() != :semicolon
                @logger.debug("else_sentences: #{else_sentence}")
                return [:if, conditional_expression, then_sentence, else_sentence]
            when :repeat
                return [:repeat, expression(), sentence()]
            when :print_cha
                return [:print_cha, expression()]
            when :print_num
                return [:print_num, expression()]
            when :read_cha
                num = num()
                unget_token if get_token() != :semicolon
                raise Exception, "å¤æ°ãããã¾ãã" if num[0] != :variable
                return [:read_cha, num]
            when :read_num
                num = num()
                unget_token() if get_token() != :semicolon
                raise Exception, "å¤æ°ãããã¾ãã" if num[0] != :variable
                return [:read_num, num]
            when :high # assign
                unget_token()
                variable = num()
                @logger.debug("variable: #{variable}")
                if variable[0] != :variable
                    raise Exception, "å¤æ°ãããã¾ãã"
                end
                if get_token() != :assign
                    raise Exception, "ä»£å¥æ¼ç®å­ãããã¾ãã"
                end
                return [:assign, variable, expression()]
            when :right_brace
                unget_token()
                return nil
            else
                unget_token()
                @logger.debug("nil sentence: #{get_token()}"); unget_token()
                unget_token() if get_token() != :semicolon
                @logger.debug("tokens[pos-3..pos+3]: #{@tokens[@pos-3..@pos+3]}")
                return nil
            end
        end

        # å¼
        def expression()
            result = _term()
            token = get_token()
            @logger.debug("expression_token: #{token}")

            while token == :add || token == :sub
                result = [token, result, _term()]
                token = get_token()
            end
            unget_token() if token != :semicolon
            @logger.debug("expression_result: #{result}")
            @logger.debug("next_token: #{get_token}"); unget_token()
            return result
        end

        # é ã¨å å­ãåãã¦ããã®ã¯ãæ¼ç®å­ã®åªåé ä½ãå®è£ãããã

        # é 
        def _term()
            result = _factor()
            token = get_token()

            while token == :mul || token == :div
                result = [token, result, _factor()]
                token = get_token()
            end
            unget_token()
            @logger.debug("term_result: #{result}")
            return result
        end

        # å å­
        def _factor()
            token = get_token()
            @logger.debug("factor_token: #{token}")
            if token == :left_parn
                result = expression()
                token = get_token()
                if token != :right_parn
                    raise(Exception, "')'ãããã¾ãã")
                end
                @logger.debug("factor_result: #{result}")
                return result
            elsif token == :high || token == :low
                unget_token()
                num = num()
                @logger.debug("factor_result(num): #{num}")
                return num
            else
                raise(Exception, "æ°å¤ã¾ãã¯'('ãããã¾ãã")
            end
        end

        # æ°å¤ãåå¾
        def num()
            token = get_token()

            def get_num(token)
                num_s = ""
                while token == :high || token == :low
                    @logger.debug("token: #{token}")
                    if token == :high
                        num_s += "1"
                    elsif token == :low
                        num_s += "0"
                    else
                        raise Exception, "æ°å¤ãä¸æ­£ã§ã"
                    end
                    token = get_token()
                end
                unget_token()
                @logger.debug("num: #{num_s.to_i(2)}")
                return num_s.to_i(2)
            end

            @logger.debug("num_token: #{token}")
            if token == :low
                return [:integer, get_num(get_token())]
            elsif token == :high
                return [:variable, get_num(get_token())]
            else
                raise Exception, "æ°å¤ãä¸æ­£ã§ã"
            end
        end

        constructs = sentences()
        @logger.debug("æ§æè§£æDONE:constructs: #{constructs}")

        remove_instance_variable(:@tokens)
        remove_instance_variable(:@pos)

        return constructs
    end

    # è§£éå®è¡
    private def evaluate(constructs)
        @logger.debug("constructs: #{constructs}")
        if constructs.instance_of?(Array)
            case constructs[0]
            when :block
                constructs[1..-1].each do |token|
                    evaluate(token)
                end
            when :if
                @logger.debug("if_constructs: #{constructs}")
                if evaluate(constructs[1]) != 0
                    evaluate(constructs[2])
                elsif constructs[3] != nil
                    evaluate(constructs[3])
                end
            when :repeat
                @logger.debug("repeat_constructs: #{constructs}")
                while evaluate(constructs[1]) != 0
                    evaluate(constructs[2])
                end
            when :print_cha
                print(evaluate(constructs[1]).chr)
            when :print_num
                print(evaluate(constructs[1]))
            when :read_cha
                @logger.debug("read_cha: #{constructs[1]}")
                raise Exception, "å¤æ°ãããã¾ãã" if constructs[1][0] != :variable
                @variables[constructs[1][1]] = $stdin.getc.ord
                @logger.debug("read_cha: #{@variables}")
            when :read_num
                @logger.debug("read_num: #{constructs[1]}")
                raise Exception, "å¤æ°ãããã¾ãã" if constructs[1][0] != :variable
                @variables[constructs[1][1]] = $stdin.gets.to_i
                @logger.debug("read_num: #{@variables}")
            when :assign
                if constructs[1][0] != :variable
                    raise Exception, "å¤æ°ãããã¾ãã"
                end
                @logger.debug("assign: #{constructs[1][1]} = #{evaluate(constructs[2])}")
                @variables[constructs[1][1]] = evaluate(constructs[2])
            when :variable
                raise Exception, "å¤æ°ãããã¾ãã" if @variables[constructs[1]] == nil
                return @variables[constructs[1]]
            when :integer
                return constructs[1]
            when :add
                @logger.debug("add: #{evaluate(constructs[1])} + #{evaluate(constructs[2])}")
                return evaluate(constructs[1]) + evaluate(constructs[2])
            when :sub
                return evaluate(constructs[1]) - evaluate(constructs[2])
            when :mul
                return evaluate(constructs[1]) * evaluate(constructs[2])
            when :div
                return evaluate(constructs[1]) / evaluate(constructs[2])
            end
        else
            return tokens
        end
    end
end

# å®è¡
INVISIBLE.new
