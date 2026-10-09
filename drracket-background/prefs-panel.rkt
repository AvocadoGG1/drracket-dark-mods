#lang racket/base
;; Edit > Preferences > Background Image
(require racket/class
         racket/gui/base
         framework
         "background.rkt")
(provide add-background-prefs-panel! make-background-panel)

(define placement-labels
  '((fill . "Fill (crop to cover)")
    (fit . "Fit (whole picture)")
    (bottom-right . "Bottom right")
    (center . "Center")))

(define (add-background-prefs-panel!)
  (preferences:add-panel "Background Image" make-background-panel))

(define (make-background-panel parent)
  (define panel (new vertical-panel% [parent parent] [alignment '(left top)]))

  (define (current-label)
    (or (preferences:get 'drracket-background:image) "(none)"))
  (define file-row (new horizontal-panel% [parent panel] [stretchable-height #f]))
  (new message% [parent file-row] [label "Image:"])
  (define path-msg (new message% [parent file-row] [label (current-label)]
                        [stretchable-width #t]))
  (new button% [parent file-row] [label "Choose…"]
       [callback
        (λ (b e)
          (define p (get-file "Choose a background image" (send panel get-top-level-window)
                              #f #f #f '()
                              '(("Images" "*.png;*.jpg;*.jpeg;*.gif;*.bmp")
                                ("Any" "*.*"))))
          (when p
            (preferences:set 'drracket-background:image (path->string p))
            (send path-msg set-label (current-label))))])
  (new button% [parent file-row] [label "Clear"]
       [callback
        (λ (b e)
          (preferences:set 'drracket-background:image #f)
          (send path-msg set-label (current-label)))])

  (new slider% [parent panel] [label "Opacity (%)"] [min-value 0] [max-value 100]
       [init-value (preferences:get 'drracket-background:opacity)]
       [callback (λ (s e) (preferences:set 'drracket-background:opacity (send s get-value)))])

  (define placement-choice
    (new choice% [parent panel] [label "Placement"]
         [choices (map cdr placement-labels)]
         [callback
          (λ (c e)
            (preferences:set 'drracket-background:placement
                             (car (list-ref placement-labels (send c get-selection)))))]))
  (send placement-choice set-selection
        (for/first ([pl (in-list placement-labels)] [i (in-naturals)]
                    #:when (eq? (car pl) (preferences:get 'drracket-background:placement)))
          i))

  (preferences:add-check panel 'drracket-background:in-repl?
                         "Also show it behind the interactions window (REPL)")
  (new message% [parent panel]
       [label "Tip: 15–30% opacity keeps code readable on a dark color scheme."])
  panel)
