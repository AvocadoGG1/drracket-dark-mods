#lang racket/base
(require drracket/tool
         racket/class
         racket/unit
         "syntax-colors.rkt")
(provide tool@)

(define tool@
  (unit
    (import drracket:tool^)
    (export drracket:tool-exports^)

    (define (phase1) (void))
    (define (phase2) (void))

    (register-syntax-styles!)

    (drracket:get/extend:extend-definitions-text syntax-color-mixin)
    (drracket:get/extend:extend-interactions-text syntax-color-mixin)))
