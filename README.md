# invisible
真の不可視を目指すプログラミング言語

## 概要

[Unicode characters you can not see ( https://invisible-characters.com/ )](https://invisible-characters.com/)を参考に表示されない文字たちで構成された言語

変数名やリテラルは、2進数で表現される。

## 言語仕様

このルールでは、Unicodeコードポイントで表記する。

- 文列 = 文 (文)*
- 文 = 代入文 | if文 | repeat文 | print文 | `U+1D173` 文列 `U+1D174`
- 代入文 = 変数 `U+200E` 式 `U+2800`
- if文 = `U+00AD` 式 `U+0034F` 文 `U+061C` 文
- repeat文 = `U+2061` 式 文
- print文(文字コード) = `U+2060` 式 `U+2800`
- print文(数値) = `U+2063` 式 `U+2800`
- read文(文字コード) = `U+2062` 変数 `U+2800`
- read文(数値) = `U+205F` 変数 `U+2800`
- 式 = 項 (( `U+2000` | `U+2001` ) 項)*
- 項 = 因子 (( `U+2003` | `U+2004` ) 因子)*
- 因子 = リテラル | 変数 | `U+1D177` 式 `U+1D178`
- リテラル = `U+200C`を先頭に付け、`U+200D` を1に、`U+200C` を0に変換した2進数
- 変数 = `U+200D`を先頭に付け、`U+200D` を1に、`U+200C` を0に変換した2進数

> 見づらい。とっても見辛い。

### その他

- 拡張子: `.invisible`

## 実装

### メンバ変数

なし

### 定数

- `Keyword`: print文等を表すキーワードを格納している

### メソッド

- `initialize`: クラスがインスタンス化されたときに呼ばれるメソッド。各種設定と実行するプログラムを読み込んだ。

- `tokenize`: プログラムをトークンに分割する。トークンは、戻り値として返す。
- `parse`: トークンをパースする。パースした結果を戻り値として返す。
- `evaluate`: パースした結果を実行する。実行結果を戻り値として返す。

それぞれのメソッド内にて、トークンのゲッターセッターが定義されている。
