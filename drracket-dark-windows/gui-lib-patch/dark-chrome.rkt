#lang racket/base
;; Installed into gui-lib/mred/private/wx/win32/ by drracket-dark-windows/patch.rkt.
;; Overrides the Windows "button face" colors and control font that racket/gui
;; uses for panels, toolbars and tabs. Settings come from
;; <pref-dir>/drracket-dark-windows.rktd (written by the drracket-dark-windows plugin).
(require ffi/unsafe
         ffi/winapi)
(provide dark-chrome-enabled?
         dark-sys-color
         dark-chrome-brush
         dark-chrome-font-face
         dark-chrome-static-color)

(define config
  (with-handlers ([(λ (e) #t) (λ (e) #f)])
    (define p (build-path (find-system-path 'pref-dir) "drracket-dark-windows.rktd"))
    (and (file-exists? p)
         (let ([v (call-with-input-file p read)])
           (and (hash? v) v)))))

(define (conf key default) (if config (hash-ref config key default) default))

(define dark-chrome-enabled?
  (and config
       (eq? (system-type) 'windows)
       (conf 'enabled #t)
       (or (not (conf 'drracket-only #t))
           (regexp-match? #rx"(?i:drracket)"
                          (path->string (find-system-path 'run-file))))))

(define (->colorref rgb default)
  (if (and (list? rgb) (= 3 (length rgb)) (andmap exact-nonnegative-integer? rgb))
      (+ (car rgb) (* 256 (cadr rgb)) (* 65536 (caddr rgb)))
      default))

(define bg (->colorref (conf 'background #f) #x262525))
(define fg (->colorref (conf 'foreground #f) #xDCDCDC))

(define COLOR_BTNFACE 15)
(define COLOR_BTNTEXT 18)

(define (dark-sys-color index original)
  (cond
    [(not dark-chrome-enabled?) original]
    [(= index COLOR_BTNFACE) bg]
    [(= index COLOR_BTNTEXT) fg]
    [else original]))

(define gdi32 (ffi-lib "gdi32.dll"))
(define CreateSolidBrush (get-ffi-obj "CreateSolidBrush" gdi32 (_fun #:abi winapi _uint32 -> _pointer)))
(define SetTextColor (get-ffi-obj "SetTextColor" gdi32 (_fun #:abi winapi _pointer _uint32 -> _uint32)))
(define SetBkColor (get-ffi-obj "SetBkColor" gdi32 (_fun #:abi winapi _pointer _uint32 -> _uint32)))

(define brush (and dark-chrome-enabled? (CreateSolidBrush bg)))

;; a fresh cpointer each call, so callers can tag it
(define (dark-chrome-brush) (and brush (ptr-add brush 0)))

(define (dark-chrome-font-face)
  (and dark-chrome-enabled?
       (let ([f (conf 'control-font #f)])
         (and (string? f) f))))

;; WM_CTLCOLORSTATIC fallback for plain labels: light text on the dark brush
(define (dark-chrome-static-color hdc)
  (and brush
       (begin
         (SetTextColor hdc fg)
         (SetBkColor hdc bg)
         (cast brush _pointer _intptr))))
