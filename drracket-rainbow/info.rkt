#lang info

(define collection "drracket-rainbow")
(define deps '("base" "gui-lib" "drracket-plugin-lib" "syntax-color-lib"))
(define pkg-desc "Rainbow brackets and VS Code-style syntax colors for DrRacket")
(define version "0.1")
(define license 'MIT)

(define drracket-tools '(("tool.rkt")))
(define drracket-tool-names '("Rainbow Brackets"))

;; "Monokai Rainbow" color scheme (Edit > Preferences > Colors > Color Schemes).
;; Monokai Pro colors, like the VS Code theme. The extra roles the plugin adds
;; (special forms, function names, rainbow brackets) are in syntax-colors.rkt.
(define framework:color-schemes
  (list
   (hash
    'name "Monokai Rainbow"
    'white-on-black-base? #t
    'colors
    '((framework:basic-canvas-background #(30 30 30))
      (framework:default-text-color #(252 252 250))
      (framework:paren-match-color #(60 60 72))
      (framework:line-numbers #(110 110 110))
      (framework:line-numbers-current-line-number-foreground #(30 30 30))
      (framework:line-numbers-current-line-number-background #(169 220 118))
      (framework:syntax-color:scheme:symbol #(252 252 250))
      (framework:syntax-color:scheme:other #(252 252 250))
      (framework:syntax-color:scheme:keyword #(252 152 103))
      (framework:syntax-color:scheme:comment #(139 136 143))
      (framework:syntax-color:scheme:string #(255 216 102))
      (framework:syntax-color:scheme:text #(255 216 102))
      (framework:syntax-color:scheme:constant #(171 157 242))
      (framework:syntax-color:scheme:hash-colon-keyword #(255 97 136))
      (framework:syntax-color:scheme:parenthesis #(255 215 0))
      (framework:syntax-color:scheme:error #(255 85 85))
      (drracket:read-eval-print-loop:value-color #(120 220 232))
      (drracket:read-eval-print-loop:out-color #(169 220 118))
      (drracket:read-eval-print-loop:error-color #(255 97 136))
      (drracket:check-syntax:lexically-bound #(252 252 250))
      (drracket:check-syntax:imported #(120 220 232))
      (drracket:check-syntax:free-variable #(255 85 85))
      (drracket:check-syntax:set!d #(255 85 85))
      (drracket:check-syntax:unused-require #(255 85 85))
      (drracket:syncheck:var-arrow #(120 220 232))
      (drracket:syncheck:template-arrow #(252 152 103))
      (drracket:syncheck:tail-arrow #(169 220 118))))))
