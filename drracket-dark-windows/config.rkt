#lang racket/base
;; Shared settings for the plugin. The gui-lib patch (gui-lib-patch/dark-chrome.rkt)
;; reads the same file, so one edit controls both halves.
(require racket/file)
(provide config-path read-config ensure-config! cfg)

(define config-path
  (build-path (find-system-path 'pref-dir) "drracket-dark-windows.rktd"))

(define defaults
  (hash 'enabled #t
        'drracket-only #t                  ; patch only affects DrRacket, not other racket/gui apps
        'background '(37 37 38)            ; toolbar / tabs / menu bar
        'hover '(62 62 66)                 ; hovered / open menu-bar item
        'foreground '(220 220 220)
        'disabled '(128 128 128)
        'control-font #f                   ; toolbar, tabs, status line: a font name, or #f for the Windows default
        'menu-font #f                      ; menu bar: a font name, or #f for the Windows default
        'menu-font-points 9))

(define (read-config)
  (define h (with-handlers ([exn:fail? (λ (e) (hash))])
              (define v (file->value config-path))
              (if (hash? v) v (hash))))
  (for/fold ([acc defaults]) ([(k v) (in-hash h)])
    (hash-set acc k v)))

(define (ensure-config!)
  (unless (file-exists? config-path)
    (with-handlers ([exn:fail? void])
      (with-output-to-file config-path
        (λ ()
          (printf ";; drracket-dark-windows settings for DrRacket. Restart DrRacket after editing.\n")
          (printf ";; Colors are (red green blue), 0-255. Fonts are a face name or #f.\n")
          (write defaults)
          (newline))))))

(define (cfg key) (hash-ref (read-config) key))
