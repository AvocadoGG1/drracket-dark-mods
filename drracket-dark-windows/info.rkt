#lang info

(define collection "drracket-dark-windows")
(define deps '("base" "gui-lib" "drracket-plugin-lib"))
(define pkg-desc "Dark title bar, menu bar, toolbar, tabs and scrollbars for DrRacket on Windows")
(define version "0.1")
(define license 'MIT)

(define drracket-tools '(("tool.rkt")))
(define drracket-tool-names '("Dark Windows Chrome"))

;; The gui-lib patch file is copied into Racket's install by patch.rkt;
;; it is not a module of this collection, so don't compile it here.
(define compile-omit-paths '("gui-lib-patch"))
