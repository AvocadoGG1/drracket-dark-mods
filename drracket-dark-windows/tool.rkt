#lang racket/base
(require drracket/tool
         racket/class
         racket/unit
         "config.rkt"
         "win32-dark.rkt")
(provide tool@)

(define tool@
  (unit
    (import drracket:tool^)
    (export drracket:tool-exports^)

    (define (phase1) (void))
    (define (phase2) (void))

    (define (report e) (log-error "drracket-dark-windows: ~a" (exn-message e)))

    (define dark-frame-mixin
      (mixin (drracket:unit:frame<%>) ()
        (super-new)
        (inherit get-handle)
        ;; The menu bar is filled in after construction, so darken once the
        ;; frame is shown (and again harmlessly if it is re-shown).
        (define/override (on-superwindow-show shown?)
          (super on-superwindow-show shown?)
          (when shown?
            (with-handlers ([exn:fail? report])
              (darken-frame! (get-handle)))))))

    ;; definitions/interactions canvases, including ones made by splitting the window
    (define (dark-scrollbar-mixin %)
      (class %
        (super-new)
        (inherit get-handle)
        (with-handlers ([exn:fail? report])
          (darken-scrollbars! (get-handle)))))

    (when (eq? (system-type) 'windows)
      (ensure-config!)
      (drracket:get/extend:extend-unit-frame dark-frame-mixin)
      (drracket:get/extend:extend-definitions-canvas dark-scrollbar-mixin)
      (drracket:get/extend:extend-interactions-canvas dark-scrollbar-mixin))))
