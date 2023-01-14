require 'logger'
require 'optparse'
require 'strscan'

class INVISIBLE
    Keywords = {
        "𝅷" => :left_parn,       # (         U+1D177
        "𝅸" => :right_parn,      # )         U+1D178
        "𝅳" => :left_brace,      # {         U+1D173
        "𝅴" => :right_brace,     # }         U+1D174
        "‎" => :assign,  # :=        U+200E
        "⠀" => :semicolon,      # ;         U+2800
        "­" => :if,              # if        U+00AD
        "͏" => :then,            # then      U+0034F
        "؜" => :else,    # else      U+061C
        "⁡" => :repeat,          # repeat    U+2061
        "⁣" => :print,           # print     U+2063
        " " => :add,            # +         U+2000
        " " => :sub,            # -         U+2001
        " " => :mul,            # *         U+2002
        " " => :div,            # /         U+2003
        "‍" => :high,            # high      U+200D
        "‌" => :low,             # low       U+200C
    }

    # インスタンス化時に実行される
    def initialize
        # コード
        code = nil
        # ログ出力用
        @logger = Logger.new(STDOUT)
        ## リリース用レベル
        @logger.level = Logger::WARN

        # OptionParserのインスタンスを作成
        opt = OptionParser.new

        # 各オプション(.parse!時実行)
        # デバッグ用
        opt.on('-d', '--debug') {@logger.level = Logger::DEBUG}

        # オプションを切り取る
        opt.parse!(ARGV)

        # デバッグ状態の確認
        @logger.debug('DEBUG MODE')

        # ファイルが指定されていた場合、ファイルを開く
        if ARGV.length > 0
            begin
                code = ARGF.read
            rescue Errno::ENOENT => e
                @logger.fatal(e.message)
                exit
            end
        else
            @logger.fatal("ファイルが指定されていません")
            exit
        end

        begin
            # 実行するところ
            # @logger.debug("code: #{code}")
            # @logger.debug("code(Unicodeコードポイント): #{code.codepoints.map{|v| v.to_s(16)}}")

            # 字句解析実行
            tokens = tokenize(code)

            # 構文解析実行
            constructs = parse(tokens)

            # 変数のハッシュリセット
            @variables = Hash.new
            # 意味解析実行
            evaluate(constructs)
        rescue => e
            @logger.debug(e)
            @logger.fatal(e.message)
            exit
        end

        return
    end

    # 字句解析
    private def tokenize(code)

        def get_token(code_scanner)
            # ここで、トークンの種類を判別する
            if  code_scanner.scan(/(?:#{Keywords.keys.map{|key|Regexp.escape(key)}.join('|')})/)
                @logger.debug("matched_key: #{code_scanner.matched.codepoints.map{|v| v.to_s(16)}.join(",")}")
                return Keywords[code_scanner.matched]
            else
                @logger.debug("matched: nil")
                return nil
            end
        end

        # 不要なコメントを削除
        code = code.gsub(/[^#{Keywords.keys.map{|key|Regexp.escape(key)}.join()}]/, '')

        @logger.debug("code: #{code}")
        @logger.debug("code(Unicodeコードポイント): #{code.codepoints.map{|v| v.to_s(16)}}")

        # 文字列をトークンに分割
        code_scanner = StringScanner.new(code)
        tokens = []
        while !code_scanner.eos?
            token = get_token(code_scanner)
            if token.nil?
                @logger.fatal("不正な文字が含まれています")
                exit
            end
            tokens << token
        end

        @logger.debug("tokens: #{tokens}")
        return tokens
    end

    # 構文解析
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

        # 文列
        def sentences()
            unless s = sentence()
                raise Exception, "文がありません"
            end
            result = [:block, s]
            while s = sentence()
                result << s
            end
            return result
        end

        # 文
        def sentence()
            case get_token()
            when :if
                conditional_expression = expression()
                @logger.debug("conditional_expression: #{conditional_expression}")
                raise Exception, "thenがありません" if get_token() != :then
                then_sentence = sentence()
                @logger.debug("then_sentences: #{then_sentence}")
                if get_token() != :else
                    @logger.debug("elseがありません")
                    unget_token()

                    return [:if, conditional_expression, then_sentence]
                end
                else_sentence = sentence()
                @logger.debug("else_sentences: #{else_sentence}")
                return [:if, conditional_expression, then_sentence, else_sentence]
            when :repeat
                return nil
            when :print
                return [:print, expression()]
            when :high # assign
                unget_token()
                variable = num()
                @logger.debug("variable: #{variable}")
                if variable[0] != :variable
                    raise Exception, "変数がありません"
                end
                if get_token() != :assign
                    raise Exception, "代入演算子がありません"
                end
                return [:assign, variable, expression()]
            else
                unget_token()
                @logger.debug("nil sentence: #{get_token()}")
                unget_token()
                return nil
            end
        end

        # 式
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
            return result
        end

        # 項と因子を分けているのは、演算子の優先順位を実装するため

        # 項
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

        # 因子
        def _factor()
            token = get_token()
            @logger.debug("factor_token: #{token}")
            if token == :left_parn
                result = expression()
                token = get_token()
                if token != :right_parn
                    raise(Exception, "')'がありません")
                end
                @logger.debug("factor_result: #{result}")
                return result
            elsif token == :high || token == :low
                unget_token()
                num = num()
                @logger.debug("factor_result(num): #{num}")
                return num
            else
                raise(Exception, "数値または'('がありません")
            end
        end

        # 数値を取得
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
                        raise Exception, "数値が不正です"
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
                raise Exception, "数値が不正です"
            end
        end

        constructs = sentences()
        @logger.debug("constructs: #{constructs}")

        remove_instance_variable(:@tokens)
        remove_instance_variable(:@pos)

        return constructs
    end

    # 解釈実行
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
            when :print
                print(evaluate(constructs[1]).chr)
            when :assign
                if constructs[1][0] != :variable
                    raise Exception, "変数がありません"
                end
                @logger.debug("assign: #{constructs[1][1]} = #{evaluate(constructs[2])}")
                @variables[constructs[1][1]] = evaluate(constructs[2])
            when :variable
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

    private def get_token(code_scanner)
        # ここで、トークンの種類を判別する
        if  code_scanner.scan(/(?:#{Keywords.keys.map{|key|Regexp.escape(key)}.join('|')})/)
            @logger.debug("matched_key: #{code_scanner.matched.codepoints.map{|v| v.to_s(16)}.join(",")}")
            return Keywords[code_scanner.matched]
        else
            @logger.debug("matched: nil")
            return nil
        end
    end

    private def unget_token(code_scanner)
        @logger.debug("unget: #{code_scanner.matched}")
        @logger.debug("scanner_before: #{code_scanner.inspect}")
        code_scanner.unscan if !token.nil?
        @logger.debug("scanner_after: #{code_scanner.inspect}")
    end
end

# 実行
INVISIBLE.new
