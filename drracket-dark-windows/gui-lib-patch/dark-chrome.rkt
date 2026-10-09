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
         dark-chrome-static-color
         dark-chrome-style-control!
         dark-chrome-style-window!)

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

;; ---------------------------------------------------------------------------
;; Native buttons. Themed check boxes and radio buttons always draw black text,
;; so they get classic (unthemed) drawing, which uses the WM_CTLCOLORSTATIC text
;; color above. Push buttons get Windows' own dark button theme.

(define user32 (ffi-lib "user32.dll"))
(define kernel32 (ffi-lib "kernel32.dll"))
(define uxtheme (ffi-lib "uxtheme.dll"))
(define GetClassNameW
  (get-ffi-obj "GetClassNameW" user32 (_fun #:abi winapi _pointer _pointer _int -> _int)))
(define GetWindowLongW
  (get-ffi-obj "GetWindowLongW" user32 (_fun #:abi winapi _pointer _int -> _int32)))
(define SetWindowTheme
  (get-ffi-obj "SetWindowTheme" uxtheme
               (_fun #:abi winapi _pointer _string/utf-16 _string/utf-16 -> _int32)))
(define LoadLibraryW
  (get-ffi-obj "LoadLibraryW" kernel32 (_fun #:abi winapi _string/utf-16 -> _pointer)))
(define GetProcAddress
  (get-ffi-obj "GetProcAddress" kernel32 (_fun #:abi winapi _pointer _intptr -> _fpointer)))

;; undocumented uxtheme exports, by ordinal (stable since Windows 10 1903)
(define (uxtheme-ord n type)
  (with-handlers ([(λ (e) #t) (λ (e) #f)])
    (define p (GetProcAddress (LoadLibraryW "uxtheme.dll") n))
    (and p (cast p _fpointer type))))
(define allow-dark-mode-for-window
  (and dark-chrome-enabled? (uxtheme-ord 133 (_fun #:abi winapi _pointer _bool -> _bool))))
(when dark-chrome-enabled?
  (define set-preferred-app-mode (uxtheme-ord 135 (_fun #:abi winapi _int -> _int)))
  (when set-preferred-app-mode (void (set-preferred-app-mode 2)))) ; ForceDark

(define (class-name hwnd)
  (define buf (malloc 128 'raw))
  (define n (GetClassNameW hwnd buf 64))
  (define s (if (> n 0) (cast buf _pointer _string/utf-16) ""))
  (free buf)
  s)

(define GWL_STYLE -16)

(define (dark-chrome-style-control! hwnd)
  (when dark-chrome-enabled?
    (with-handlers ([(λ (e) #t) void])
      (when (string-ci=? (class-name hwnd) "PLTBUTTON")
        (define kind (bitwise-and (GetWindowLongW hwnd GWL_STYLE) #xF))
        (cond
          [(memv kind '(0 1)) ; BS_PUSHBUTTON, BS_DEFPUSHBUTTON
           (when allow-dark-mode-for-window (allow-dark-mode-for-window hwnd #t))
           (SetWindowTheme hwnd "DarkMode_Explorer" #f)]
          [else ; check boxes, radio buttons, group boxes
           (SetWindowTheme hwnd "" "")])))))

;; Top-level windows (frames and dialogs): dark title bar
(define dwmapi (with-handlers ([(λ (e) #t) (λ (e) #f)]) (ffi-lib "dwmapi.dll")))
(define DwmSetWindowAttribute
  (and dwmapi (get-ffi-obj "DwmSetWindowAttribute" dwmapi
                           (_fun #:abi winapi _pointer _uint32 _pointer _uint32 -> _int32)
                           (λ () #f))))
(define WS_CHILD #x40000000)

(define (dark-chrome-style-window! hwnd)
  (when (and dark-chrome-enabled? DwmSetWindowAttribute)
    (with-handlers ([(λ (e) #t) void])
      (when (zero? (bitwise-and (GetWindowLongW hwnd GWL_STYLE) WS_CHILD))
        (define (set-attr! attr v)
          (define p (malloc 4 'raw))
          (ptr-set! p _uint32 v)
          (DwmSetWindowAttribute hwnd attr p 4)
          (free p))
        (set-attr! 20 1)    ; DWMWA_USE_IMMERSIVE_DARK_MODE
        (set-attr! 35 bg)   ; DWMWA_CAPTION_COLOR (Windows 11)
        (set-attr! 36 fg))))) ; DWMWA_TEXT_COLOR
