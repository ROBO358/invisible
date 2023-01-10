require 'logger'
require 'optparse'
require 'strscan'

# キーワード
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

def to_binary(num)
    binary = num.to_s(2)

    binary.gsub!(/0/, "‌")
    binary.gsub!(/1/, "‍")

    return binary
end

# コード
code = nil
filepath = nil
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
if ARGV.length == 2
    begin
        file = open(ARGV[0])
        code = file.read
        file.close
        filepath = ARGV[1]
    rescue Errno::ENOENT => e
        @logger.fatal(e.message)
        exit
    end
else
    @logger.fatal("引数が正しく指定されていません。")
    exit
end

begin
    # 実行するところ
    @logger.debug(code)

    # ハッシュをコピペで使えるようにキーと値を逆にしている
    Keywords = Keywords.invert

    # ハッシュのキーを文字列に変換
    Keywords.keys.each do |key|
        Keywords[key.to_s] = Keywords.delete(key)
    end
    Keywords[";"] = Keywords.delete("semicolon")
    Keywords["+"] = Keywords.delete("add")
    Keywords["-"] = Keywords.delete("sub")
    Keywords["*"] = Keywords.delete("mul")
    Keywords["/"] = Keywords.delete("div")

    @logger.debug(Keywords)

    code.gsub!(/\s+/, "")
    code.gsub!(/(#{Keywords.keys.map{|key|Regexp.escape(key)}.join('|')})/, Keywords)
    code.gsub!(/\d+/) {|matched| to_binary(matched.to_i)}

    @logger.debug("code: #{code}")
    @logger.debug("code(Unicodeコードポイント): #{code.codepoints.map{|v| v.to_s(16)}}")

    # ファイルに書き込む
    file = File.open(filepath, "w")
    file.write(code)
    file.close
rescue => e
    @logger.debug(e)
    @logger.fatal(e.message)
    exit
end
