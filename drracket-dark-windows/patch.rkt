#lang racket/base
;; Applies / reverts the small racket/gui patch that lets drracket-dark-windows recolor
;; the toolbar, tabs and status bar and change their font.
;;
;;   racket patch.rkt apply     (needs an Administrator prompt: Racket lives in Program Files)
;;   racket patch.rkt revert
;;   racket patch.rkt status
;;
;; Originals are backed up to gui-lib-patch/backup/ before anything is changed.
;; A Racket upgrade replaces gui-lib, which silently removes the patch; re-run apply.
(require racket/file
         racket/runtime-path
         racket/system
         setup/dirs)

(define-runtime-path here ".")
(define patch-dir (build-path here "gui-lib-patch"))
(define backup-dir
  (or (let ([d (getenv "DRRACKET_DARK_BACKUP_DIR")]) (and d (string->path d)))
      (build-path patch-dir "backup")))

(define win32-dir
  ;; DRRACKET_DARK_WIN32_DIR lets the patch be dry-run against a scratch copy
  (or (let ([d (getenv "DRRACKET_DARK_WIN32_DIR")]) (and d (string->path d)))
  (let ([p (collection-file-path "utils.rkt" "mred" "private" "wx" "win32")])
    (let-values ([(base name dir?) (split-path p)]) base))))

(define marker ";; drracket-dark-windows patch")

;; file -> list of (old . new) exact string replacements
(define edits
  `(("utils.rkt"
     ("\"const.rkt\")"
      . "\"const.rkt\"\n         \"dark-chrome.rkt\") ;; drracket-dark-windows patch")
     ("(define-user32 GetSysColor (_wfun _int -> _DWORD))"
      . ,(string-append
          "(define-user32 GetSysColor/raw (_wfun _int -> _DWORD) #:c-id GetSysColor) " marker "\n"
          "(define (GetSysColor i) (dark-sys-color i (GetSysColor/raw i)))")))
    ("wndclass.rkt"
     ("\"icons.rkt\")"
      . "\"icons.rkt\"\n         \"dark-chrome.rkt\") ;; drracket-dark-windows patch")
     ("(define background-hbrush (let ([p (ptr-add #f (+ COLOR_BTNFACE 1))])"
      . "(define background-hbrush (let ([p (or (dark-chrome-brush) (ptr-add #f (+ COLOR_BTNFACE 1)))]) ;; drracket-dark-windows patch"))
    ("procs.rkt"
     ("\"theme.rkt\""
      . "\"theme.rkt\"\n         \"dark-chrome.rkt\" ;; drracket-dark-windows patch")
     ("(define (get-control-font-face) (get-theme-font-face))"
      . "(define (get-control-font-face) (or (dark-chrome-font-face) (get-theme-font-face))) ;; drracket-dark-windows patch"))
    ("window.rkt"
     ("         \"font.rkt\")"
      . "         \"font.rkt\"\n         \"dark-chrome.rkt\") ;; drracket-dark-windows patch")
     ("[(and maybe-wx (send maybe-wx control-will-color (cast wParam _WPARAM _HDC))) => values]"
      . "[(and maybe-wx (send maybe-wx control-will-color (cast wParam _WPARAM _HDC))) => values]\n             [(dark-chrome-static-color (cast wParam _WPARAM _HDC)) => values] ;; drracket-dark-windows patch"))))

(define (target f) (build-path win32-dir f))
(define (patched? f) (regexp-match? (regexp-quote marker) (file->string (target f))))

(define (replace-once s old new file)
  (define n (length (regexp-match-positions* (regexp-quote old) s)))
  (unless (= n 1)
    (error 'patch "~a: expected exactly one match for ~s, found ~a (different Racket version?)"
           file old n))
  (string-replace-first s old new))

(define (string-replace-first s old new)
  (define m (regexp-match-positions (regexp-quote old) s))
  (string-append (substring s 0 (caar m)) new (substring s (cdar m))))

(define (recompile!)
  (define raco (build-path (find-console-bin-dir) "raco.exe"))
  (define files (cons "dark-chrome.rkt" (map car edits)))
  (define existing (filter (λ (f) (file-exists? (target f))) files))
  (printf "Recompiling ~a ...\n" existing)
  (unless (apply system* raco "make" "-v" (map (λ (f) (path->string (target f))) existing))
    (error 'patch "raco make failed")))

(define (apply-patch)
  (define already (filter patched? (map car edits)))
  (unless (null? already)
    (printf "Already patched: ~a. Reverting first so the patch is clean.\n" already)
    (revert-patch))
  ;; compute every new file first so nothing is half-applied on error
  (define new-contents
    (for/list ([e edits])
      (define f (car e))
      (cons f (for/fold ([s (file->string (target f))]) ([r (cdr e)])
                (replace-once s (car r) (cdr r) f)))))
  (make-directory* backup-dir)
  (for ([e edits])
    (copy-file (target (car e)) (build-path backup-dir (car e)) #t))
  (copy-file (build-path patch-dir "dark-chrome.rkt") (target "dark-chrome.rkt") #t)
  (for ([fc new-contents])
    (call-with-output-file (target (car fc)) #:exists 'truncate
      (λ (o) (write-string (cdr fc) o))))
  (recompile!)
  (printf "Patched ~a\nRestart DrRacket to see the dark toolbar and tabs.\n" win32-dir))

(define (revert-patch)
  (for ([e edits])
    (define f (car e))
    (define b (build-path backup-dir f))
    (cond
      [(file-exists? b) (copy-file b (target f) #t)]
      [(patched? f) (error 'patch "no backup for patched file ~a" f)]))
  (when (file-exists? (target "dark-chrome.rkt"))
    (delete-file (target "dark-chrome.rkt"))
    (for ([ext '("_rkt.zo" "_rkt.dep")])
      (define c (build-path win32-dir "compiled" (string-append "dark-chrome" ext)))
      (when (file-exists? c) (delete-file c))))
  (recompile!)
  (printf "Reverted ~a\n" win32-dir))

(define (status)
  (printf "gui-lib win32 dir: ~a\n" win32-dir)
  (for ([e edits])
    (printf "  ~a: ~a\n" (car e) (if (patched? (car e)) "patched" "original"))))

(module+ main
  (define cmd (let ([args (current-command-line-arguments)])
                (if (zero? (vector-length args)) "status" (vector-ref args 0))))
  (with-handlers ([exn:fail? (λ (e)
                               (eprintf "ERROR: ~a\n" (exn-message e))
                               (exit 1))])
    (case cmd
      [("apply") (apply-patch)]
      [("revert") (revert-patch)]
      [("status") (status)]
      [else (eprintf "usage: racket patch.rkt apply|revert|status\n") (exit 2)])))
