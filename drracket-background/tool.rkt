#lang racket/base
(require drracket/tool
         racket/unit
         "background.rkt"
         "prefs-panel.rkt")
(provide tool@)

(define tool@
  (unit
    (import drracket:tool^)
    (export drracket:tool-exports^)

    (define (phase1) (void))
    (define (phase2) (void))

    (register-background-prefs!)
    (add-background-prefs-panel!)

    (drracket:get/extend:extend-definitions-text background-mixin)
    (drracket:get/extend:extend-interactions-text (λ (%) (background-mixin % #:repl? #t)))))
