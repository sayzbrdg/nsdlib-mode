;;; Copyright (c) 2017-2021 Seiji Ohashi <sayzbrdg@gmail.com>
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
;;;
;;;  1. Redistributions of source code must retain the above copyright
;;;     notice, this list of conditions and the following disclaimer.
;;;  2. Redistributions in binary form must reproduce the above copyright
;;;     notice, this list of conditions and the following disclaimer in the
;;;     documentation and/or other materials provided with the distribution.
;;;  3. Neither the name of the authors nor the names of its contributors
;;;     may be used to endorse or promote products derived from this
;;;     software without specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;; A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;; HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;; TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;; PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(require 'generic-x)


;; generic mode
;;
(define-generic-mode nsdlib-mode
  '(";")                                ; コメント開始文字列
  nil                                   ; キーワード
  ;; font-lock の設定
  '(("^#[a-zA-Z0-9]+" . font-lock-builtin-face)
    ("[[:space:]]{[[:space:]]" . font-lock-keyword-face)
    ("[[:space:]]}$" . font-lock-keyword-face)
    ("^E[[:space:]]*([0-9]+)" . font-lock-constant-face)
    ("^BGM[[:space:]]*([0-9]+)" . font-lock-constant-face)
    ("^S[[:space:]]*([0-9]+)" . font-lock-constant-face)
    ("^TR[0-9]+\\([[:space:]]*,[[:space:]]*[0-9]+\\)*" . font-lock-function-name-face)
    ("Ev[0-9]+" . font-lock-type-face)
    ("E[@mn][0-9]+" . font-lock-variable-name-face)

    ("[A-Za-z0-9]+=" . font-lock-builtin-face)
    ("\\\\v[bschti][+-]?" . font-lock-builtin-face)
    ("\\\\V[+-]?" . font-lock-keyword-face)

    ("[][:]" . font-lock-warning-face)
    )
  '("\\.nsd$")                          ; モードを有効にするファイル名
  '(nsdlib-mode-setup)                     ; モード開始時に呼ばれる関数
  "NSDLIB mode")


;; key map
;;
(defvar nsdlib-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-c" 'nsdlib-save-and-compile-buffer)
    (define-key map "\C-c\C-p" 'nsdlib-play-file)
    map)
  "nsdlib-modeのキーマップ")


;; variables
;;
(defconst nsdlib-default-file-extension ".nsf"
  "PMDデータファイルのデフォルト拡張子")
(defconst nsdlib-compilation-buffer-name "*nsdlib-compilation*"
  "コンパイル結果を表示するバッファ名")

(defcustom nsdlib-mode-hook nil
  "nsdlib-modeのフック"
  :type '(hook))
(defcustom nsdlib-after-compile-hook nil
  "コンパイルコマンド正常終了時のフック"
  :type '(hook))
(defcustom nsdlib-compile-program-name "nsc.exe"
  "NSDLIBコンパイラのプログラム名"
  :type '(string))
(defcustom nsdlib-compile-program-options '()
  "NSDLIBコンパイラのコマンドラインオプション"
  :type '(repeat string))
(defcustom nsdlib-player-program-name nil
  "NSDLIBファイルプレイヤー"
  :type '(restricted-sexp :match-alternatives (stringp 'nil)))
(defcustom nsdlib-player-program-options nil
  "NSDLIBファイルプレイヤーのコマンドラインオプション"
  :type '(repeat string))
(defcustom nsdlib-play-after-compile nil
  "コンパイル後に再生する場合はtを指定"
  :type '(boolean))
(defcustom nsdlib-normalize-filename-function 'convert-standard-filename
  "ファイル名の正規化関数"
  :type '(restricted-sexp))


;; functions
;;
(defun nsdlib-mode-setup ()
  (use-local-map nsdlib-mode-map))


(defun nsdlib-search-filename (&optional buffer)
  "バッファファイル名の拡張子を'nsdlib-default-file-extension'に
置き換えたものを返す。バッファがファイルではない場合は nil を返す。
BUFFER が指定されなければ、カレントバッファを対象とする"
  (let ((basefilename (buffer-file-name buffer)))
    (and basefilename
         (concat (file-name-sans-extension basefilename)
                 nsdlib-default-file-extension))))


(defun nsdlib-play-file (&optional file)
  "FILEで指定されるコンパイル後のNSDLIBデータを再生する。
FILEが指定されなければ、カレントバッファから推測される
ファイル名を使用する。'nsdlib-player-program-name'が設定されて
いなかったり、FILEが指定されず、カレントバッファがファイル
ではない場合はエラーになる。コンパイル後のNSDLIBデータファイルが
存在するかのチェックは行わない。"
  (interactive)
  (catch 'error
    (let ((filename (or file (nsdlib-search-filename))))
      (unless nsdlib-player-program-name
        (error "nsdlib-player-program-name is not set")
        (throw 'error nil))
      (unless filename
        (error "%s is not a file buffer." (buffer-name))
        (throw 'error nil))
      ;; 起動した再生プロセスの終了を待つと、再生中の操作ができなくなる
      ;; ので待たない
      (apply 'call-process nsdlib-player-program-name nil 0 nil
             (append nsdlib-player-program-options
                     `(,(funcall nsdlib-normalize-filename-function filename)))))))


(defun nsdlib-compile-buffer-file (&optional buffer)
  "バッファのファイルを'nsdlib-compile-program-name'でコンパイルする。
'nsdlib-compile-program-name'が設定されていなかったり、バッファ
がファイルではない場合はエラーになる。事前にバッファの保存は
行わない。 BUFFER が指定されなければ、カレントバッファを
対象とする"
  (catch 'error
    (let ((filename (buffer-file-name buffer))
          (outbuffer (get-buffer-create nsdlib-compilation-buffer-name)))
      (unless nsdlib-compile-program-name
        (error "nsdlib-compile-program-name is not set")
        (throw 'error nil))
      (unless filename
        (error "%s is not a file buffer." (buffer-name buffer))
        (throw 'error nil))
      (when (one-window-p)
        (split-window-vertically))
      ;; コンパイル結果出力先のバッファがウィンドウにあればそれを利用
      ;; 無ければ next-window を使用
      (set-window-buffer (or (get-buffer-window outbuffer)
                             (next-window))
                         outbuffer)
      (if (= 0 (with-current-buffer outbuffer
                 ;; コンパイル結果出力先のバッファは常に read only に
                 (let ((coding-system-for-read 'cp932-dos))
                   (unwind-protect
                       (progn
                         (setq buffer-read-only nil)
                         (erase-buffer)
                         (setq default-process-coding-system '(cp932-dos . cp932-dos))
                         (apply 'call-process nsdlib-compile-program-name nil
                                outbuffer nil
                                (append nsdlib-compile-program-options
                                        `(,(funcall nsdlib-normalize-filename-function filename)))
                                ))
                     (setq buffer-read-only t)))))
          ;; コンパイル正常終了時はフックを実行
          (progn
            (run-hooks 'nsdlib-after-compile-hook)
            t)
        nil))))


(defun nsdlib-save-and-compile-buffer (&optional buffer)
  "バッファを保存しコンパイルする。指定があればその後再生する。
'nsdlib-compile-program-name'が設定されていなかったり、バッファ
がファイルではない場合はエラーになる。
BUFFER が指定されなければ、カレントバッファを対象とする"
  (interactive)
  (catch 'error
    (let* ((targetbuffer (or buffer (current-buffer)))
           (filename (buffer-file-name targetbuffer)))
      (unless nsdlib-compile-program-name
        (error "nsdlib-compile-program-name is not set")
        (throw 'error nil))
      (unless filename
        (error "%s is not a file buffer." (buffer-name buffer))
        (throw 'error nil))
      (with-current-buffer targetbuffer
        (save-buffer))
      (when (and (nsdlib-compile-buffer-file buffer) ; 異常時は継続しない
                 nsdlib-play-after-compile)
        (nsdlib-play-file (nsdlib-search-filename buffer))))))


(provide 'nsdlib-mode)

;; Local variables:
;; coding: utf-8
;; end:
