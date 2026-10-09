#lang racket/base
;; Draws a picture behind the text of DrRacket's editors, faded into the
;; color scheme's background, like VS Code's background-image extensions.
;; The picture stays fixed to the visible area while the text scrolls over it.
(require racket/class
         racket/draw
         racket/gui/base
         framework)
(provide register-background-prefs!
         background-mixin
         placements)

;; ---------------------------------------------------------------------------
;; preferences

(define placements '(fill fit bottom-right center))

(define (register-background-prefs!)
  (preferences:set-default 'drracket-background:image #f (λ (v) (or (not v) (string? v))))
  (preferences:set-default 'drracket-background:opacity 25 (λ (v) (and (exact-integer? v) (<= 0 v 100))))
  (preferences:set-default 'drracket-background:placement 'fill (λ (v) (memq v placements)))
  (preferences:set-default 'drracket-background:in-repl? #t boolean?)
  (for ([p '(drracket-background:image drracket-background:opacity
             drracket-background:placement drracket-background:in-repl?)])
    (preferences:add-callback p (λ (k v) (queue-callback settings-changed!))))
  (color-prefs:register-color-scheme-entry-change-callback
   'framework:basic-canvas-background
   (λ (c) (queue-callback settings-changed!))))

;; ---------------------------------------------------------------------------
;; the source picture, loaded once per path

(define loaded-path #f)
(define loaded-bitmap #f)

(define (source-bitmap)
  (define path (preferences:get 'drracket-background:image))
  (unless (equal? path loaded-path)
    (set! loaded-path path)
    (set! loaded-bitmap
          (and path
               (file-exists? path)
               (with-handlers ([exn:fail? (λ (e)
                                            (log-error "drracket-background: ~a" (exn-message e))
                                            #f)])
                 (define bm (read-bitmap path))
                 (and (send bm ok?) bm)))))
  loaded-bitmap)

;; ---------------------------------------------------------------------------
;; every background-mixin text redraws when a setting changes

(define live-texts (make-weak-hasheq))
(define settings-version 0)

(define (settings-changed!)
  (set! settings-version (add1 settings-version))
  (for ([t (in-list (hash-keys live-texts))])
    (send t invalidate-bitmap-cache 0 0 'display-end 'display-end)))

;; Render the picture, already faded, at exactly the size of the visible area.
(define (render-composite w h scale)
  (define bm (make-bitmap (max 1 w) (max 1 h) #f #:backing-scale scale))
  (define dc (new bitmap-dc% [bitmap bm]))
  (send dc set-smoothing 'smoothed)
  (send dc set-background (color-prefs:lookup-in-color-scheme 'framework:basic-canvas-background))
  (send dc clear)
  (define src (source-bitmap))
  (when src
    (define sw (send src get-width))
    (define sh (send src get-height))
    (define placement (preferences:get 'drracket-background:placement))
    (define s
      (case placement
        [(fill) (max (/ w sw) (/ h sh))]
        [(fit) (min (/ w sw) (/ h sh))]
        [(bottom-right) (min 1 (/ (* 0.6 h) sh) (/ (* 0.5 w) sw))]
        [else (min 1 (/ w sw) (/ h sh))]))
    (define dw (* s sw))
    (define dh (* s sh))
    (define-values (x y)
      (case placement
        [(bottom-right) (values (- w dw) (- h dh))]
        [else (values (/ (- w dw) 2) (/ (- h dh) 2))]))
    (send dc set-alpha (/ (preferences:get 'drracket-background:opacity) 100))
    (send dc set-scale s s)
    (send dc draw-bitmap src (/ x s) (/ y s))
    (send dc set-scale 1 1)
    (send dc set-alpha 1))
  (send dc set-bitmap #f)
  bm)

(define (background-mixin % #:repl? [repl? #f])
  (class %
    (inherit get-admin invalidate-bitmap-cache)
    (super-new)
    (hash-set! live-texts this #t)

    (define cache #f)      ; composite bitmap for the current view size
    (define cache-key #f)  ; (list w h scale settings-version)

    (define/private (active?)
      (and (preferences:get 'drracket-background:image)
           (or (not repl?) (preferences:get 'drracket-background:in-repl?))
           (source-bitmap)))

    (define/override (on-paint before? dc left top right bottom dx dy draw-caret)
      ;; draw first, so highlights the framework paints in its own `before?` pass stay on top
      (when (and before? (active?))
        (with-handlers ([exn:fail? (λ (e) (log-error "drracket-background: ~a" (exn-message e)))])
          (paint-background dc left top right bottom dx dy)))
      (super on-paint before? dc left top right bottom dx dy draw-caret))

    (define/private (paint-background dc left top right bottom dx dy)
      (define admin (get-admin))
      (when admin
        (define xb (box 0)) (define yb (box 0)) (define wb (box 0)) (define hb (box 0))
        (send admin get-view xb yb wb hb)
        (define vx (unbox xb))
        (define vy (unbox yb))
        (define w (inexact->exact (ceiling (unbox wb))))
        (define h (inexact->exact (ceiling (unbox hb))))
        (define scale (send dc get-backing-scale))
        (define key (list w h scale settings-version))
        (unless (equal? key cache-key)
          (set! cache (render-composite w h scale))
          (set! cache-key key))
        ;; copy just the part of the visible area being repainted
        (define l (max left vx))
        (define t (max top vy))
        (define r (min right (+ vx w)))
        (define b (min bottom (+ vy h)))
        (when (and (< l r) (< t b))
          (send dc draw-bitmap-section cache
                (+ l dx) (+ t dy)
                (- l vx) (- t vy)
                (- r l) (- b t)))))

    ;; the picture is fixed to the view, so after scrolling the whole view must be redrawn
    (define/override (after-scroll-to)
      (super after-scroll-to)
      (when (active?)
        (invalidate-bitmap-cache 0 0 'display-end 'display-end)))))
