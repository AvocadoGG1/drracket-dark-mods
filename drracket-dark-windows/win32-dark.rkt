#lang racket/base
;; Win32 tricks that need no changes to Racket itself:
;;  - dark title bar           (DwmSetWindowAttribute, documented)
;;  - dark dropdown menus      (uxtheme SetPreferredAppMode, undocumented but stable since Win10 1903)
;;  - dark menu bar strip      (subclass the frame and paint the undocumented WM_UAHDRAWMENU* messages)
(require ffi/unsafe
         ffi/winapi
         racket/list
         "config.rkt")
(provide darken-frame! darken-scrollbars!)

(define user32   (ffi-lib "user32.dll"))
(define gdi32    (ffi-lib "gdi32.dll"))
(define kernel32 (ffi-lib "kernel32.dll"))
(define comctl32 (ffi-lib "comctl32.dll"))
(define dwmapi   (with-handlers ([exn:fail? (λ (e) #f)]) (ffi-lib "dwmapi.dll")))

(define-syntax-rule (defapi name lib type)
  (define name (and lib (get-ffi-obj 'name lib type (λ () #f)))))

(define _HWND _pointer)
(define _HDC _pointer)
(define-cstruct _RECT ([left _int32] [top _int32] [right _int32] [bottom _int32]))
(define-cstruct _MENUBARINFO ([cbSize _uint32] [rcBar _RECT] [hMenu _pointer]
                              [hwndMenu _pointer] [flags _int32]))
(define-cstruct _MENUITEMINFOW
  ([cbSize _uint] [fMask _uint] [fType _uint] [fState _uint] [wID _uint]
   [hSubMenu _pointer] [hbmpChecked _pointer] [hbmpUnchecked _pointer]
   [dwItemData _uintptr] [dwTypeData _pointer] [cch _uint] [hbmpItem _pointer]))
(define MIIM_FTYPE #x100) (define MIIM_DATA #x20) (define MFT_OWNERDRAW #x100)
(define-cstruct _SIZE ([cx _int32] [cy _int32]))

(defapi DwmSetWindowAttribute dwmapi (_fun #:abi winapi _HWND _uint32 _pointer _uint32 -> _int32))
(defapi SetWindowSubclass comctl32
  (_fun #:abi winapi _HWND _fpointer _uintptr _uintptr -> _bool))
(defapi DefSubclassProc comctl32
  (_fun #:abi winapi _HWND _uint _uintptr _intptr -> _intptr))
(defapi GetMenuBarInfo user32 (_fun #:abi winapi _HWND _int32 _int32 _MENUBARINFO-pointer -> _bool))
(defapi GetWindowRect user32 (_fun #:abi winapi _HWND _RECT-pointer -> _bool))
(defapi GetMenuStringW user32 (_fun #:abi winapi _pointer _uint _pointer _int _uint -> _int))
(defapi FillRect user32 (_fun #:abi winapi _HDC _RECT-pointer _pointer -> _int))
(defapi DrawTextW user32 (_fun #:abi winapi _HDC _string/utf-16 _int _RECT-pointer _uint -> _int))
(defapi GetWindowDC user32 (_fun #:abi winapi _HWND -> _HDC))
(defapi GetDC user32 (_fun #:abi winapi _HWND -> _HDC))
(defapi ReleaseDC user32 (_fun #:abi winapi _HWND _HDC -> _int))
(defapi GetMenu user32 (_fun #:abi winapi _HWND -> _pointer))
(defapi SetMenu user32 (_fun #:abi winapi _HWND _pointer -> _bool))
(defapi GetMenuItemCount user32 (_fun #:abi winapi _pointer -> _int))
(defapi GetMenuItemInfoW user32 (_fun #:abi winapi _pointer _uint _bool _MENUITEMINFOW-pointer -> _bool))
(defapi SetMenuItemInfoW user32 (_fun #:abi winapi _pointer _uint _bool _MENUITEMINFOW-pointer -> _bool))
(defapi GetMenuItemRect user32 (_fun #:abi winapi _HWND _pointer _uint _RECT-pointer -> _bool))
(defapi DrawMenuBar user32 (_fun #:abi winapi _HWND -> _bool))
(defapi GetDpiForWindow user32 (_fun #:abi winapi _HWND -> _uint))
(defapi CreateSolidBrush gdi32 (_fun #:abi winapi _uint32 -> _pointer))
(defapi CreateFontW gdi32
  (_fun #:abi winapi _int _int _int _int _int _uint32 _uint32 _uint32 _uint32
        _uint32 _uint32 _uint32 _uint32 _string/utf-16 -> _pointer))
(defapi SelectObject gdi32 (_fun #:abi winapi _HDC _pointer -> _pointer))
(defapi SetTextColor gdi32 (_fun #:abi winapi _HDC _uint32 -> _uint32))
(defapi SetBkMode gdi32 (_fun #:abi winapi _HDC _int -> _int))
(defapi GetTextExtentPoint32W gdi32
  (_fun #:abi winapi _HDC _string/utf-16 _int _SIZE-pointer -> _bool))
(defapi LoadLibraryW kernel32 (_fun #:abi winapi _string/utf-16 -> _pointer))
(define GetProcAddress
  (get-ffi-obj "GetProcAddress" kernel32 (_fun #:abi winapi _pointer _intptr -> _fpointer)))

;; ---------------------------------------------------------------------------
;; colors / GDI objects

(define (colorref rgb) (+ (first rgb) (* 256 (second rgb)) (* 65536 (third rgb))))
(define conf (read-config))
(define bg (colorref (hash-ref conf 'background)))
(define hover (colorref (hash-ref conf 'hover)))
(define fg (colorref (hash-ref conf 'foreground)))
(define disabled (colorref (hash-ref conf 'disabled)))
(define bg-brush (and CreateSolidBrush (CreateSolidBrush bg)))
(define hover-brush (and CreateSolidBrush (CreateSolidBrush hover)))

(define menu-fonts (make-hash)) ; dpi -> HFONT
(define (menu-font hwnd)
  (define face (hash-ref conf 'menu-font))
  (and face
       (let ([dpi (if GetDpiForWindow (GetDpiForWindow hwnd) 96)])
         (hash-ref! menu-fonts dpi
                    (λ ()
                      (define px (round (/ (* (hash-ref conf 'menu-font-points) dpi) 72)))
                      ;; height, width, esc, orient, weight 400, italic, underline, strike,
                      ;; DEFAULT_CHARSET, out prec, clip prec, CLEARTYPE_QUALITY, pitch
                      (CreateFontW (- px) 0 0 0 400 0 0 0 1 0 0 5 0 face))))))

;; ---------------------------------------------------------------------------
;; dark title bar

(define (dark-title-bar! hwnd)
  (when DwmSetWindowAttribute
    (define (set-attr! attr v)
      (define p (malloc 4 'raw))
      (ptr-set! p _uint32 v)
      (DwmSetWindowAttribute hwnd attr p 4)
      (free p))
    (set-attr! 20 1)      ; DWMWA_USE_IMMERSIVE_DARK_MODE
    (set-attr! 35 bg)     ; DWMWA_CAPTION_COLOR (Windows 11 only; ignored elsewhere)
    (set-attr! 36 fg)))   ; DWMWA_TEXT_COLOR

;; ---------------------------------------------------------------------------
;; dark dropdown menus via undocumented uxtheme ordinals

(define uxtheme-done? #f)
(define (uxtheme-ord n type)
  (define h (LoadLibraryW "uxtheme.dll"))
  (define p (and h (GetProcAddress h n)))
  (and p (cast p _fpointer type)))

(define (dark-popup-menus! hwnd)
  (with-handlers ([exn:fail? void])
    (unless uxtheme-done?
      (set! uxtheme-done? #t)
      (define set-preferred-app-mode (uxtheme-ord 135 (_fun #:abi winapi _int -> _int)))
      (define flush-menu-themes (uxtheme-ord 136 (_fun #:abi winapi -> _void)))
      (when set-preferred-app-mode (set-preferred-app-mode 2)) ; ForceDark
      (when flush-menu-themes (flush-menu-themes)))
    (define allow-dark (uxtheme-ord 133 (_fun #:abi winapi _HWND _bool -> _bool)))
    (when allow-dark (allow-dark hwnd #t))))

;; ---------------------------------------------------------------------------
;; dark menu bar: handle the undocumented "UAH" menu bar paint messages

(define WM_NCPAINT #x85)
(define WM_NCACTIVATE #x86)
(define WM_UAHDRAWMENU #x91)
(define WM_UAHDRAWMENUITEM #x92)
(define WM_MEASUREITEM #x2C)
(define WM_DRAWITEM #x2B)
(define OBJID_MENU -3)
(define MF_BYPOSITION #x400)
(define ODS_SELECTED #x1) (define ODS_GRAYED #x2) (define ODS_DISABLED #x4)
(define ODS_HOTLIGHT #x40) (define ODS_NOACCEL #x100)
(define DT_CENTER #x1) (define DT_VCENTER #x4) (define DT_SINGLELINE #x20)
(define DT_HIDEPREFIX #x100000)

(define (menu-bar-rect hwnd)  ; menu bar rectangle in window coordinates
  (define mbi (make-MENUBARINFO (ctype-sizeof _MENUBARINFO) (make-RECT 0 0 0 0) #f #f 0))
  (define wr (make-RECT 0 0 0 0))
  (and (GetMenuBarInfo hwnd OBJID_MENU 0 mbi)
       (GetWindowRect hwnd wr)
       (let ([r (MENUBARINFO-rcBar mbi)])
         (make-RECT (- (RECT-left r) (RECT-left wr)) (- (RECT-top r) (RECT-top wr))
                    (- (RECT-right r) (RECT-left wr)) (- (RECT-bottom r) (RECT-top wr))))))

(define (menu-item-text hmenu pos)
  (define buf (malloc 512 'raw))
  (define n (GetMenuStringW hmenu pos buf 255 MF_BYPOSITION))
  (define s (if (> n 0) (cast buf _pointer _string/utf-16) ""))
  (free buf)
  s)

(define (scale hwnd n) (quotient (* n (if GetDpiForWindow (GetDpiForWindow hwnd) 96)) 96))

(define (draw-item hwnd hdc rc state text)
  (define hot? (positive? (bitwise-and state (bitwise-ior ODS_HOTLIGHT ODS_SELECTED))))
  (define dim? (positive? (bitwise-and state (bitwise-ior ODS_GRAYED ODS_DISABLED))))
  (FillRect hdc rc (if hot? hover-brush bg-brush))
  (SetBkMode hdc 1) ; TRANSPARENT
  (SetTextColor hdc (if dim? disabled fg))
  (define font (menu-font hwnd))
  (define old-font (and font (SelectObject hdc font)))
  (define flags (bitwise-ior DT_CENTER DT_VCENTER DT_SINGLELINE
                             (if (positive? (bitwise-and state ODS_NOACCEL)) DT_HIDEPREFIX 0)))
  (DrawTextW hdc text -1 rc flags)
  (when old-font (SelectObject hdc old-font)))

(define (text-size hwnd text)
  (define dc (GetDC hwnd))
  (define font (menu-font hwnd))
  (define old (and font (SelectObject dc font)))
  (define sz (make-SIZE 0 0))
  (GetTextExtentPoint32W dc text (string-length text) sz)
  (when old (SelectObject dc old))
  (ReleaseDC hwnd dc)
  (values (SIZE-cx sz) (SIZE-cy sz)))

;; Owner-drawn menu-bar items carry item-data = MAGIC + position
(define MAGIC #x4D430000)
(define (our-item? p data-offset)
  (and (= 1 (ptr-ref p _uint32 'abs 0))                 ; ODT_MENU
       (= MAGIC (bitwise-and (ptr-ref p _uintptr 'abs data-offset) #xFFFF0000))))
;; labels captured before items became owner-drawn: (hmenu-address . pos) -> text
(define labels (make-hash))
(define (label-key hmenu pos) (cons (cast hmenu _pointer _uintptr) pos))
(define (item-text hwnd p data-offset)
  (define hmenu (GetMenu hwnd))
  (define pos (bitwise-and (ptr-ref p _uintptr 'abs data-offset) #xFFFF))
  (hash-ref labels (label-key hmenu pos) (λ () (menu-item-text hmenu pos))))

(define (strip-ampersands s) (regexp-replace* #rx"&(.)" s "\\1"))

(define (subclass-proc hwnd msg wparam lparam id data)
  (with-handlers ([(λ (e) #t) (λ (e) (DefSubclassProc hwnd msg wparam lparam))])
    (cond
      [(= msg WM_UAHDRAWMENU)
       ;; lParam -> UAHMENU { HMENU hmenu; HDC hdc; DWORD flags; }
       (define um (cast lparam _intptr _pointer))
       (define hdc (ptr-ref um _pointer 1))
       (define r (menu-bar-rect hwnd))
       (when r (FillRect hdc r bg-brush))
       1]
      [(= msg WM_UAHDRAWMENUITEM)
       ;; lParam -> { DRAWITEMSTRUCT dis (64 bytes); UAHMENU um (24); UAHMENUITEM umi }
       (define p (cast lparam _intptr _pointer))
       (define state (ptr-ref p _uint32 'abs 16))
       (define hdc (ptr-ref p _pointer 'abs 32))
       (define rc (ptr-ref (ptr-add p 40) _RECT))
       (define hmenu (ptr-ref p _pointer 'abs 64))
       (define pos (ptr-ref p _int32 'abs 88))
       (draw-item hwnd hdc rc state (menu-item-text hmenu pos))
       1]
      [(and (= msg WM_MEASUREITEM) (our-item? (cast lparam _intptr _pointer) 24))
       ;; MEASUREITEMSTRUCT: CtlType 0, CtlID 4, itemID 8, itemWidth 12, itemHeight 16, itemData 24
       (define p (cast lparam _intptr _pointer))
       (define-values (w h) (text-size hwnd (strip-ampersands (item-text hwnd p 24))))
       (define pad (scale hwnd 14))
       ;; Windows adds roughly one check-mark width to owner-drawn bar items; compensate
       (ptr-set! p _uint32 'abs 12 (max 1 (- (+ w pad) (scale hwnd 12))))
       (ptr-set! p _uint32 'abs 16 h)
       1]
      [(and (= msg WM_DRAWITEM) (our-item? (cast lparam _intptr _pointer) 56))
       ;; DRAWITEMSTRUCT: itemState 16, hDC 32, rcItem 40, itemData 56
       (define p (cast lparam _intptr _pointer))
       (draw-item hwnd (ptr-ref p _pointer 'abs 32) (ptr-ref (ptr-add p 40) _RECT)
                  (ptr-ref p _uint32 'abs 16) (item-text hwnd p 56))
       1]
      [(or (= msg WM_NCPAINT) (= msg WM_NCACTIVATE))
       ;; Windows draws a light 1px line under the menu bar, and leaves the empty
       ;; space right of owner-drawn items light; paint over both
       (define result (DefSubclassProc hwnd msg wparam lparam))
       (define r (menu-bar-rect hwnd))
       (when r
         (define dc (GetWindowDC hwnd))
         (FillRect dc (make-RECT (RECT-left r) (RECT-bottom r) (RECT-right r) (add1 (RECT-bottom r)))
                   bg-brush)
         (define hmenu (GetMenu hwnd))
         (define n (if hmenu (GetMenuItemCount hmenu) 0))
         (define last (make-RECT 0 0 0 0))
         (define wr (make-RECT 0 0 0 0))
         (when (and (> n 0) (GetMenuItemRect hwnd hmenu (sub1 n) last) (GetWindowRect hwnd wr))
           (define x (- (RECT-right last) (RECT-left wr)))
           (when (< x (RECT-right r))
             (FillRect dc (make-RECT x (RECT-top r) (RECT-right r) (RECT-bottom r)) bg-brush)))
         (ReleaseDC hwnd dc))
       result]
      [else (DefSubclassProc hwnd msg wparam lparam)])))

(define keep-alive (box null))
(define _SUBCLASSPROC
  (_fun #:abi winapi #:atomic? #t #:keep keep-alive
        _HWND _uint _uintptr _intptr _uintptr _uintptr -> _intptr))
(define subclass-proc-ptr (function-ptr subclass-proc _SUBCLASSPROC))

(define (dark-menu-bar! hwnd)
  (when (and SetWindowSubclass DefSubclassProc bg-brush)
    (SetWindowSubclass hwnd subclass-proc-ptr #x4D435244 0) ; id "MCRD"
    ;; Make the top-level items owner-drawn so we control their width
    ;; (a custom font may be wider than the default menu font).
    (define hmenu (GetMenu hwnd))
    (when (and hmenu (hash-ref conf 'menu-font))
      (for ([pos (in-range (GetMenuItemCount hmenu))])
        (define mii (make-MENUITEMINFOW (ctype-sizeof _MENUITEMINFOW) 0 0 0 0 #f #f #f 0 #f 0 #f))
        (set-MENUITEMINFOW-fMask! mii MIIM_FTYPE)
        (when (GetMenuItemInfoW hmenu pos #t mii)
          (hash-ref! labels (label-key hmenu pos) (λ () (menu-item-text hmenu pos)))
          (set-MENUITEMINFOW-fMask! mii (bitwise-ior MIIM_FTYPE MIIM_DATA))
          (set-MENUITEMINFOW-fType! mii (bitwise-ior (MENUITEMINFOW-fType mii) MFT_OWNERDRAW))
          (set-MENUITEMINFOW-dwItemData! mii (+ MAGIC pos))
          (SetMenuItemInfoW hmenu pos #t mii))))
    (DrawMenuBar hwnd)))

;; ---------------------------------------------------------------------------

;; ---------------------------------------------------------------------------
;; dark scrollbars: the editor canvases use the window's own (non-client) scrollbars,
;; which follow the window's visual theme

(define uxtheme (ffi-lib "uxtheme.dll"))
(defapi SetWindowTheme uxtheme (_fun #:abi winapi _HWND _string/utf-16 _pointer -> _int32))
(defapi GetWindow user32 (_fun #:abi winapi _HWND _uint -> _HWND))
(define GW_HWNDNEXT 2) (define GW_CHILD 5)

(define (darken-scrollbars! hwnd)
  (when (and hwnd SetWindowTheme (eq? (system-type) 'windows) (hash-ref conf 'enabled))
    (dark-popup-menus! hwnd) ; sets the process to dark mode and allows it for this window
    (let loop ([h hwnd] [depth 0])
      (SetWindowTheme h "DarkMode_Explorer" #f)
      (when (< depth 3)
        (let child ([c (GetWindow h GW_CHILD)])
          (when c
            (loop c (add1 depth))
            (child (GetWindow c GW_HWNDNEXT))))))))

(define (darken-frame! hwnd)
  (when (and hwnd (eq? (system-type) 'windows) (hash-ref conf 'enabled))
    (dark-popup-menus! hwnd)
    (dark-title-bar! hwnd)
    (dark-menu-bar! hwnd)))
