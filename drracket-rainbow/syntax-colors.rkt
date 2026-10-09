#lang racket/base
;; VS Code-style coloring: wraps whatever lexer DrRacket's language provides and
;; adds a color to tokens for extra roles the stock Racket lexer doesn't distinguish:
;;   special forms (define, lambda, cond ...)   -> rb:special
;;   the function in call position (f x)        -> rb:call
;;   the name being defined (define (f ...))    -> rb:def-name
;;   brackets, colored by nesting depth         -> rb:paren0 / 1 / 2
(require racket/class
         racket/set
         racket/draw
         framework
         syntax-color/lexer-contract)
(provide register-syntax-styles!
         syntax-color-mixin)

(define special-forms
  (set "define" "define-values" "define-syntax" "define-syntax-rule" "define-struct"
       "struct" "lambda" "λ" "case-lambda" "let" "let*" "letrec" "let-values" "let*-values"
       "letrec-values" "let-syntax" "if" "cond" "case" "when" "unless" "and" "or" "else"
       "begin" "begin0" "set!" "quote" "quasiquote" "unquote" "require" "provide"
       "module" "module+" "module*" "for" "for*" "for/list" "for*/list" "for/fold"
       "for*/fold" "for/vector" "for/hash" "for/and" "for/or" "for/sum" "for/first"
       "match" "match-define" "match-lambda" "with-handlers" "parameterize" "class"
       "define/public" "define/private" "define/override" "define/augment" "new" "send"
       "mixin" "do" "delay" "local" "check-expect" "check-within" "check-error"
       "check-satisfied" "check-random" "check-member-of" "check-range" "test-case"
       "define-type" "type-case" "shared" "time" "define-values/invoke-unit"))

;; after one of these, the next identifier (or the head of the next list) is a definition name
(define define-forms
  (set "define" "define-values" "define-syntax" "define-syntax-rule" "define-struct"
       "struct" "define/public" "define/private" "define/override" "define/augment"
       "define-type"))

(define quote-prefixes (set "'" "`" "#'" "#`" "'#"))

;; style name, VS Code (Monokai Pro) color for dark backgrounds, color for light ones
(define roles
  `((rb:special  "drracket-rainbow:special-form" (255 97 136)  (190 30 80))
    (rb:call     "drracket-rainbow:function"     (169 220 118) (40 120 30))
    (rb:def-name "drracket-rainbow:definition"   (169 220 118) (40 120 30))
    (rb:paren0   "drracket-rainbow:bracket-1"    (255 215 0)   (175 135 0))
    (rb:paren1   "drracket-rainbow:bracket-2"    (218 112 214) (150 50 150))
    (rb:paren2   "drracket-rainbow:bracket-3"    (23 159 255)  (20 90 200))))

(define (register-syntax-styles!)
  (for ([r (in-list roles)])
    (define style (cadr r))
    (define (->color rgb) (apply make-object color% rgb))
    (color-prefs:add-color-scheme-entry (string->symbol style)
                                        #:style style
                                        (->color (cadddr r))
                                        (->color (caddr r)))))

(define role->style (for/hasheq ([r (in-list roles)]) (values (car r) (cadr r))))

;; lexer mode we thread through: the wrapped lexer's own mode plus our context
(struct rb-mode (inner depth prev) #:prefab)
;; prev: 'none | 'open (just after an open bracket) | 'quoted-open
;;       | 'define-head (just after "(define") | 'define-open (just after "(define (")
;;       | 'quote (just after a quote prefix)

(define (attribs-type a) (if (hash? a) (hash-ref a 'type 'other) a))
;; Only the 'color key changes: the token's 'type stays the same, so indentation
;; and s-expression navigation (which look at the type) behave as before.
(define (set-attribs-color a c) (if (hash? a) (hash-set a 'color c) (hash 'type a 'color c)))

(define (wrap-lexer get-token pairs)
  (define opens (for/set ([p (in-list pairs)]) (car p)))
  (define closes (for/set ([p (in-list pairs)]) (cadr p)))
  (λ (in offset mode)
    (define-values (inner depth prev)
      (if (rb-mode? mode)
          (values (rb-mode-inner mode) (rb-mode-depth mode) (rb-mode-prev mode))
          (values mode 0 'none)))
    (define-values (lexeme attribs paren start end backup new-inner/cont)
      (get-token in offset inner))
    (define stop? (not (dont-stop? new-inner/cont)))
    (define new-inner (if stop? new-inner/cont (dont-stop-val new-inner/cont)))
    (define type (attribs-type attribs))
    (define text (and (string? lexeme) lexeme))
    (define-values (new-type new-depth new-prev)
      (cond
        [(memq type '(white-space comment sexp-comment eof))
         (values #f depth prev)]
        [(and paren (set-member? opens paren))
         (values (paren-role depth)
                 (add1 depth)
                 (case prev
                   [(define-head) 'define-open]
                   [(quote quoted-open) 'quoted-open]
                   [else 'open]))]
        [(and paren (set-member? closes paren))
         (define d (max 0 (sub1 depth)))
         (values (paren-role d) d 'none)]
        ;; racket mode retags known forms like `define` as 'keyword before we see them
        [(and (memq type '(symbol keyword)) text (not (regexp-match? #rx"^#:" text)))
         (case prev
           [(open)
            (cond
              [(set-member? special-forms text)
               (values 'rb:special depth (if (set-member? define-forms text) 'define-head 'none))]
              [else (values 'rb:call depth 'none)])]
           [(define-head define-open) (values 'rb:def-name depth 'none)]
           [else (values #f depth 'none)])]
        [(and text (set-member? quote-prefixes text))
         (values #f depth 'quote)]
        [else (values #f depth 'none)]))
    (define out-mode (rb-mode new-inner new-depth new-prev))
    (values lexeme
            (if new-type (set-attribs-color attribs new-type) attribs)
            paren start end backup
            (if stop? out-mode (dont-stop out-mode)))))

(define (paren-role depth)
  (case (modulo depth 3) [(0) 'rb:paren0] [(1) 'rb:paren1] [else 'rb:paren2]))

(define (wrap-style token-sym->style)
  (λ (sym)
    (or (hash-ref role->style sym #f)
        (token-sym->style sym))))

(define wrapped (make-weak-hasheq))

;; for DrRacket's definitions and interactions texts
(define (syntax-color-mixin %)
  (class %
    (define/override (start-colorer token-sym->style get-token pairs)
      (cond
        [(or (hash-ref wrapped get-token #f)
             (not (procedure-arity-includes? get-token 3)))
         (super start-colorer token-sym->style get-token pairs)]
        [else
         (define lexer (wrap-lexer get-token pairs))
         (hash-set! wrapped lexer #t)
         (super start-colorer (wrap-style token-sym->style) lexer pairs)]))
    (super-new)))
