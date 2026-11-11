# rcfiles-setup 用: setup.d/*.yml を読んで、シェルの代入文（y_<キー>='値'）にして出力する
#
# YAML の全部は読めない。読めるのは次の形だけ（macOS の awk でも動くように、素朴に書いてある）
#   key: 値                    1行の値。'...' や "..." で囲める（"..." の中では \n \t \" \\ が使える）
#   key: |                     複数行の値。次の行からの字下げ（スペース）された行が値になる
#     1行目
#     2行目
#   key:                       リスト
#     - 値
#     - 値
#   # コメント                  行頭の # と、値の後ろの " #..." は無視する
# 読めない行や未知のキーは y_warn にまとめて出力する

BEGIN {
	nk = split("description default os requires_dir link file where marker text status install uninstall", ks, " ")
	for (i = 1; i <= nk; i++) known[ks[i]] = 1
	key = ""; mode = ""; buf = ""; nitems = 0; bi = 0; warn = ""
}

# シェルのシングルクォートで囲んだ文字列にする
function q(s,   out, i) {
	out = ""
	while ((i = index(s, "'")) > 0) {
		out = out substr(s, 1, i - 1) "'\\''"
		s = substr(s, i + 1)
	}
	return "'" out s "'"
}

function emit(k, v) { print "y_" k "=" q(v) }

function problem(msg) { warn = warn (warn == "" ? "" : "\n") NR "行目: " msg }

function unquote_dq(s,   out, i, c, n) {
	out = ""; n = length(s)
	for (i = 2; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == "\\") {
			i++; c = substr(s, i, 1)
			if (c == "n") out = out "\n"
			else if (c == "t") out = out "\t"
			else out = out c
		} else if (c == "\"") {
			return out
		} else {
			out = out c
		}
	}
	problem("\" が閉じていません")
	return out
}

function unquote_sq(s,   out, i, c, n) {
	out = ""; n = length(s)
	for (i = 2; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == "'") {
			if (substr(s, i + 1, 1) == "'") { out = out "'"; i++ }
			else return out
		} else {
			out = out c
		}
	}
	problem("' が閉じていません")
	return out
}

function scalar(s) {
	if (substr(s, 1, 1) == "\"") return unquote_dq(s)
	if (substr(s, 1, 1) == "'") return unquote_sq(s)
	sub(/[ \t]+#.*$/, "", s)
	sub(/[ \t]+$/, "", s)
	return s
}

# 読んでいたリスト・複数行の値を確定する
function flush() {
	if (key == "") return
	if (mode == "block") sub(/\n+$/, "", buf)
	emit(key, buf)
	key = ""; mode = ""; buf = ""; nitems = 0
}

{
	sub(/\r$/, "")
	line = $0

	if (mode == "block") {
		if (line ~ /^[ \t]*$/) { buf = buf "\n"; next }
		match(line, /^ */)
		ind = RLENGTH
		if (ind > 0) {
			if (bi == 0) bi = ind
			if (ind >= bi) { buf = buf substr(line, bi + 1) "\n"; next }
		}
		flush()
	}

	if (line ~ /^[ \t]*(#.*)?$/) next

	if (mode == "list" && line ~ /^ *-( |$)/) {
		item = line
		sub(/^ *- */, "", item)
		item = scalar(item)
		if (item != "") buf = (nitems++ ? buf "\n" : "") item
		next
	}

	if (line ~ /^[A-Za-z_][A-Za-z0-9_]*:( |$)/) {
		flush()
		k = line; sub(/:.*$/, "", k)
		v = line; sub(/^[^:]*: */, "", v)
		if (!(k in known)) problem("未知のキー: " k)
		if (v == "" || v ~ /^#/) { key = k; mode = "list"; buf = ""; nitems = 0 }
		else if (v ~ /^\|[-+]? *(#.*)?$/) { key = k; mode = "block"; buf = ""; bi = 0 }
		else emit(k, scalar(v))
		next
	}

	problem("読めない行: " line)
}

END {
	flush()
	if (warn != "") emit("warn", warn)
}
