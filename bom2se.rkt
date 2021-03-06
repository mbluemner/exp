#lang racket
(require racket/package
         (for-syntax racket/syntax
                     syntax/parse)
         openssl/sha1
         net/url
         xml
         (planet neil/html-parsing/html-parsing)
         (planet clements/sxml2))

(define *cache-directory* "/Users/jay/Downloads/bom2se.cache")
(make-directory* *cache-directory*)
(define (call/input-url/cache u y z)
  (define s (url->string u))
  (define tag (sha1 (open-input-string s)))
  (define pth (build-path *cache-directory* tag))
  (cond
    [(file-exists? pth)
     (file->value pth)]
    [else
     (define v (call/input-url u y z))
     (write-to-file v pth)
     v]))

(define (los->s los)
  (regexp-replace*
   #rx"^ +"
   (regexp-replace* #rx" +$"
                    (regexp-replace* #rx"\u200B" (apply string-append los) "")
                    "")
   ""))

(define (snoc l x)
  (append l (list x)))

(define-syntax (define-protected stx)
  (syntax-parse stx
    [(_ x:id ...)
     (with-syntax ([(x* ...)
                    (for/list ([x (in-list (syntax->list #'(x ...)))])
                      (format-id x "~a*" x))])
       (syntax/loc stx
         (begin (define (x* . args)
                  (and (andmap (λ (a) a) args)
                       (apply x args)))
                ...)))]))
(define-protected list-tail los->s rest first)

(define (get-div xe class)
  (match ((sxpath (format "//div[@class=~s]" class)) xe)
    [(list x) x]
    [x
     (cond
       [(or (string=? class "subtitle")
            (string=? class "intro")
            (string=? class "summary")
            (string=? class "studyIntro"))
        #f]
       [else
        (pretty-print xe)
        (error 'get-div "Failed on ~e with ~e" class x)])]))

(define (space-string? s)
  (and (string? s)
       (regexp-match #rx"^ *$" s)))

(define (u->jpn u-base)
  (define u (format "~a?lang=jpn" u-base))
  (define xe (call/input-url/cache (string->url u) get-pure-port html->xexp))

  (define verses-xe (list '*TOP* (get-div xe "verses")))

  (define (simpl-verse p)
    (append-map
     (match-lambda
      [(? string? e)
       (list e)]
      [(and x `(ruby ,kanji))
       (simpl-verse (list kanji))]
      [(and x `(ruby (rp "(") (rt ,reading) (rp ")")))
       (list x)]
      [(and x (list 'ruby kanji ...`(rp "(") `(rt ,reading) `(rp ")")))
       (snoc (simpl-verse kanji)
             `(ruby (rp "(") (rt ,reading) (rp ")")))]
      [(and x `(ruby ,(? space-string?) ,kanji ,(? space-string?) (rp "(") ,(? space-string?) (rt ,reading) ,(? space-string?) (rp ")") ,(? space-string?)))
       (snoc (simpl-verse (list kanji))
             `(ruby (rp "(") (rt ,reading) (rp ")")))]
      [(list 'a `(@ . ,_) rest ...)
       (simpl-verse rest)]
      [`(span (@ (class "small")) . ,rest)
       (simpl-verse rest)]
      [`(span (@ (class "center")) . ,rest)
       (simpl-verse rest)]
      [`(div (@ (class "signature")) . ,rest)
       (simpl-verse rest)]
      [`(span (@ (class "language emphasis") (xml:lang "en")) . ,rest)
       (simpl-verse rest)]
      [`(div (@ (class "preface")) . ,rest)
       (simpl-verse rest)]
      [`(b . ,rest)
       (simpl-verse rest)]
      [`(em . ,rest)
       (simpl-verse rest)]
      [`(div (@ (class "comprising")) . ,rest)
       (simpl-verse rest)]
      [`(span (@ (class "verse")) ,_)
       empty]
      [`(br)
       empty]
      [`(sup (@ (class "studyNoteMarker")) ,_)
       empty]
      [x (error 'simpl-verse "Can't handle ~v in ~v" x p)])
     p))

  (define (simpl-verse->expression l)
    (append-map
     (match-lambda
      [(? string? e)
       (list e)]
      [`(ruby (rp "(") (rt ,reading) (rp ")"))
       empty]
      [x (error 'simpl-verse->expression "Can't handle ~v in ~v" x l)])
     l))
  (define (simpl-verse->reading l)
    (append-map
     (match-lambda
      [(? string? e)
       (list e)]
      [`(ruby (rp "(") (rt ,reading) (rp ")"))
       (list (format "「~a」" reading))]
      [x (error 'simpl-verse->reading "Can't handle ~v in ~v" x l)])
     l))

  (define prep-verse
    (match-lambda
     [`(p (a (@ (name ,_) (class "bookmark dontHighlight")) " ") (a (@ (name "note")) "*") . ,inside)
      (list* " " inside)]
     [`(p (@ (class "") (uri ,_)) . ,inside)
      inside]
     [`(p (a (@ (name "closing") (class "bookmark dontHighlight")) " ") . ,inside)
      inside]
     [`(p ,(? string? s) . ,inside)
      (list* " " s inside)]
     [`(" " . ,rest)
      rest]
     [`(,(? space-string?) . ,rest)
      rest]
     [v
      (error 'prep-verse:jpn "Can't handle ~v" v)]))
  (define (combine-verse sv)
    (define kanji (simpl-verse->expression sv))
    (define reading (simpl-verse->reading sv))
    (cons (los->s kanji)
          (los->s reading)))  

  (define parse-verse (compose combine-verse simpl-verse))
  (define-protected parse-verse)

  (define studyIntro-raw (list-tail* (get-div xe "studyIntro") 2))
  (define studyIntro (parse-verse* studyIntro-raw))
  (define summary-raw (rest* (first* (list-tail* (get-div xe "summary") 2))))
  (define summary (parse-verse* summary-raw))
  (define verses
    (map (compose combine-verse prep-verse simpl-verse prep-verse)
         ((sxpath "//p") verses-xe)))

  (define subtitle-raw (list-tail* (get-div xe "subtitle")  2))
  (define intro-raw (list-tail* (get-div xe "intro") 2))
  (define subtitle (parse-verse* subtitle-raw))
  (define intro (parse-verse* intro-raw))

  (list* subtitle intro (or studyIntro summary) verses))

(define (u->eng u-base)
  (define u (format "~a?lang=eng" u-base))
  (define xe (call/input-url/cache (string->url u) get-pure-port html->xexp))

  (define verses-xe (list '*TOP* (get-div xe "verses")))

  (define prep-verse
    (match-lambda
     [`(p (a (@ (name ,_) (class "bookmark dontHighlight")) " ") (a (@ (name "*")) "*") . ,inside)
      (list* " " inside)]
     [`(p (a (@ (name ,_) (class "bookmark dontHighlight")) " ") . ,inside)
      (list* " " inside)]
     [`(p (@ (class "") (uri ,_)) . ,inside)
      inside]
     [`(p (a (@ (name "closing") (class "bookmark dontHighlight")) " ") . ,inside)
      inside]
     [`(p ,(? string? s) . ,inside)
      (list* " " s inside)]
     [v
      (error 'prep-verse:eng "Can't handle ~v" v)]))
  (define (parse-verse v)
    (append-map
     (match-lambda
      [(? string? s)
       (list s)]
      [`(span (@ (class "verse")) . ,inside)
       empty]
      [`(span (@ (class "small")) . ,inside)
       (parse-verse inside)]
      [`(span (@ (class "deitySmallCaps")) . ,inside)
       (parse-verse inside)]
      [`(span (@ (class "language") . ,_) . ,inside)
       (parse-verse inside)]
      [`(b . ,inside)
       (parse-verse inside)]
      [`(em . ,inside)
       (parse-verse inside)]
      [`(span (@ (class "smallCaps")) . ,inside)
       (parse-verse inside)]
      [`(div (@ (class "question")) . ,inside)
       (parse-verse inside)]
      [`(div (@ (class "answer")) . ,inside)
       (parse-verse inside)]
      [`(div (@ (class "line")) . ,inside)
       (parse-verse inside)]
      [`(div (@ (class "signature")) . ,inside)
       (parse-verse inside)]
      [`(div (@ (class "office")) . ,inside)
       (parse-verse inside)]
      [`(a (@ (class "footnote") . ,more) . ,inside)
       (parse-verse inside)]
      [`(sup (@ (class "studyNoteMarker")) . ,inside)
       empty]
      [`(a (@ (class "bookmark-anchor dontHighlight") (name ,_)) " ")
       empty]
      [`(a (@ (href ,_) . ,_) . ,inside)
       (parse-verse inside)]
      [x (error 'parse-verse "Can't handle ~v in ~v" x v)])
     v))

  (define-protected parse-verse)
  (define studyIntro-raw (list-tail* (get-div xe "studyIntro") 2))
  (define studyIntro (los->s* (parse-verse* studyIntro-raw)))
  (define summary-raw (rest* (first* (list-tail* (get-div xe "summary") 2))))
  (define summary (los->s* (parse-verse* summary-raw)))
  (define verses (map (compose los->s parse-verse prep-verse)
                      ((sxpath "//p") verses-xe)))

  (define subtitle-raw (list-tail* (get-div xe "subtitle") 2))
  (define intro-raw (list-tail* (get-div xe "intro") 2))
  (define subtitle (los->s* (parse-verse* subtitle-raw)))
  (define intro (los->s* (parse-verse* intro-raw)))

  (list* subtitle (or intro studyIntro) (or summary studyIntro) verses))

(struct card (volume book chapter verse kanji reading meaning)
        #:transparent)

(define (parse-chapter volume book chapter)
  (printf "Parsing ~a > ~a > ~a\n" volume book chapter)
  (define u (format "http://www.lds.org/scriptures/~a~a/~a" volume
                    (if book (format "/~a" book) "") chapter))
  (define jpn (u->jpn u))
  (define eng 
    (let ()
      (define e (u->eng u))
      (if (and (equal? volume "bofm")
               (equal? book "moro")
               (equal? chapter "10"))
        (snoc e "Moroni")
        e)))
  (unless (= (length jpn) (length eng))
    (pretty-print jpn)
    (pretty-print eng)
    (error 'bom2se "Japanese and English are different lengths! ~a, ~a vs ~a"
           u (length jpn) (length eng)))

  (define cards
    (for/list
        ([k*r (in-list jpn)]
         [m (in-list eng)]
         [verse (in-sequences (in-list (list "Subtitle" "Introduction" "Summary"))
                              (in-naturals 1))])
      (match* (k*r m)
        [((cons k r) (and m (not #f)))
         (card volume book chapter verse k r m)]
        [(#f _)
         #f]
        [((cons "" "") #f)
         #f]
        [(j e)
         (error 'parse-chapter "Failed with ~a and ~a on ~a: ~a"
                j e
                (list volume book chapter verse)
                u)])))

  cards)

(define (parse-book volume book)
  (printf "Parsing ~a > ~a\n" volume book)
  (define u (format "http://www.lds.org/scriptures/~a~a?lang=eng" volume
                    (if book (format "/~a" book) "")))
  (define xe (call/input-url/cache (string->url u) get-pure-port html->xexp))
  (define chs
    ((sxpath "//ul[@class=\"jump-to-chapter\"]/li/a/text()") xe))

  (append-map (curry parse-chapter volume (or book "dc")) chs))

(define (parse-bom-volume volume)
  (printf "Parsing ~a\n" volume)
  (define u (format "http://www.lds.org/scriptures/~a?lang=eng" volume))
  (define xe (call/input-url/cache (string->url u) get-pure-port html->xexp))

  (define bs
    ((sxpath "//ul[@class=\"books\"]/li/@id/text()") xe))

  (append-map (curry parse-book volume) bs))

(define (parse-pgp-volume volume)
  (printf "Parsing ~a\n" volume)
  (define u (format "http://www.lds.org/scriptures/~a?lang=eng" volume))
  (define xe (call/input-url/cache (string->url u) get-pure-port html->xexp))

  (define bs
    ((sxpath "//ul[@class=\"frontmatter\"]/li/@id/text()") xe))

  (append-map (curry parse-book volume) bs))

(define all
  (filter-map 
   (λ (x) x)
   (append
    #;(parse-pgp-volume "pgp")
    (parse-bom-volume "bofm")
    (parse-book "dc-testament" #f)
    #;(parse-bom-volume "study-helps"))))

(define (write-csv l)
  (for ([r (in-list l)])
    (for ([e (in-list r)])
      (define s 
        (regexp-replace* #rx"[\t\n]" (xexpr->string e) " "))
      (display s)
      (display #\tab))
    (display #\newline)))

(define card->csv-row
  (match-lambda
   [(card volume book chapter verse kanji reading meaning)
    (list volume
          book
          chapter 
          (if (number? verse)
            (number->string verse)
            verse) 
          kanji
          reading
          meaning)]))

(with-output-to-file
    "/Users/jay/Downloads/lds.csv"
  #:exists 'replace
  (λ ()
    (write-csv
      (map card->csv-row
           all))))

(printf "Should be ~a cards\n" (length all))

;; DONE Parse a Japanese page
;; DONE Parse an English page
;; DONE Parse a book TOC
;; DONE Parse a volume TOC
;; DONE Parse the list of volumes TOC
;; DONE Caching system?
;; DONE Make it work for all of bofm
;; DONE Make it work for dc-testament
;; CANCELLED Make it work for pgp (js-h is hard to parse)
;; CANCELLED Make it work for study-helps
;; TODO Output to Anki input file
