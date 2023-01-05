require 'logger'
require 'optparse'
require 'strscan'

class INVISIBLE
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
            @logger.debug("code: #{code}")
            @logger.debug("code(Unicodeコードポイント): #{code.codepoints.map{|v| v.to_s(16)}}")
            evaluate(code)
        rescue => e
            @logger.fatal(e.message)
            exit
        end

    end

    # 実行
    private def evaluate()
        # ここに実行の処理を書く
    end
end

# 実行
INVISIBLE.new
