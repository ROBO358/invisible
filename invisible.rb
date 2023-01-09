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

            # 意味解析実行
            #evaluate(constructs)
        rescue => e
            @logger.debug(e)
            @logger.fatal(e.message)
            exit
        end

        return
    end

    # 字句解析
    private def tokenize(code)
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

        def sentence()
            case @tokens[@pos]
            when :if
                @pos += 1
                return if_statement()
            when :repeat
                @pos += 1
                return repeat_statement()
            when :print
                @pos += 1
                return print_statement()
            else
                return assignment_statement()
            end
        end

        def if_statement()
        end

        def repeat_statement()
        end

        def print_statement()
        end

        def assignment_statement()
        end

        def num()
        end

        constructs = sentences()
        @logger.debug("constructs: #{constructs}")

        remove_instance_variable(:@tokens)
        remove_instance_variable(:@pos)
    end

    # 解釈実行
    private def evaluate(tokens)
        # ここに実行の処理を書く
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
