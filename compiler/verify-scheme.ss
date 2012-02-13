;; verify-scheme.ss
;;
;; part of p423-sp12/srwaggon-p423 assign4
;; http://github.iu.edu/p423-sp12/srwaggon-p423
;;
;; Samuel Waggoner
;; srwaggon@indiana.edu
;; 2012/2/13

#!chezscheme
(library (compiler verify-scheme)
(export verify-scheme)
(import
 ;; Load Chez Scheme primitives:
 (chezscheme)
 ;; Load compiler framework:
 (framework match)
 (framework helpers)
 (compiler helpers)
)
  
 #| verify-scheme : program --> program
  | verify-scheme takes an expression representing a program and verifies
  | that it is an expression consiting solely of the provided language.
  | A descrition of the language is as follows.

  | Defiant to scheme unquote syntax (or whatever it's called),
  | unquotes here signify a member also found within the language.
  | Consecutive unquoted members are not necessarily the same member,
  | so much as the same part of the grammar.

  Program   -->  (letrec ([,label (lambda () ,Body)]*) ,Body)

  Body      -->  (locals (,uvar*) ,Tail)

  Tail      -->  (,Triv)
  |   (if ,Pred ,Tail ,Tail)
  |   (begin ,Effect* ,Tail)

  Pred      -->  (true)
  |   (false)
  |   (,Relop ,Triv ,Triv)
  |   (if ,Pred ,Pred ,Pred)
  |   (begin ,Effect* ,Pred)

  Effect    -->  (nop)
  |   (set! ,Var ,Triv)
  |   (set! ,Var (,Binop ,Triv ,Triv))
  |   (if ,Pred ,Effect ,Effect)
  |   (begin ,Effect* ,Effect)

  Triv      -->  ,Var | ,integer | ,label

  Var       -->  ,uvar | ,Loc

  Loc       -->  ,Register | ,frame-var

  Register  -->  rax | rcx | rdx | rbx | rbp | rsi | rdi
  |   r8 | r9 | r10 | r11 | r12 | r13 | r14 | r15

  Binop     -->  + | - | * | logand | logor | sra

  Relop     -->  < | <= | = | >= | >

  | If the program matches the language, the expression is returned.
  |#

(define-who (verify-scheme program)

  (define (verify-x-list x* x? what)
    (let loop ([x* x*] [id* '()])
      (unless (null? x*)
        (let ([x (car x*)])
          (error-unless (x? x) who "invalid ~s ~s" what x)
          (let ([id (extract-suffix x)])
            (error-when (member id id*)  who "non-unique ~s suffix ~s" what id)
            (loop (cdr x*) (cons id id*)))))))
  
  (define (Var->Loc v env)
    (if (uvar? v) (cdr (memq v env)) v))
  
  (define (Loc loc)
    (error-unless (or (register? loc) (frame-var? loc)) who "invalid Loc ~s" loc))
  
  (define (Var uvar*)
    (lambda (exp)
      (match exp
        [,v (guard (uvar? v))
            (error-unless (memq v uvar*) "unbound uvar ~s" v)]
        [,v (guard (loc? v)) (void)]
        [,else (invalid who 'Var else)])))
  
  (define (Triv lbl* uvar*)
    (lambda (exp)
      (match exp
        [,x (guard (uvar? exp))
            (error-unless (memq exp uvar*) who "unbound uvar ~s" exp)]
        [,x (guard (label? exp))
            (error-unless (memq exp lbl*) who "unbound lable ~s" exp)]
        [,x (guard (triv? exp)) (void)]
        [,else (invalid who 'Triv exp)])))
  
  (define (Effect lbl* uvar*)
    (lambda (exp)
      (match exp
        [(nop) exp]
        [(set! ,[(Var uvar*) -> v] (,b ,[(Triv lbl* uvar*) -> t1] ,[(Triv lbl* uvar*) -> t2]))
         (guard (or (binop? b) (relop? b))) exp]
        [(set! ,[(Var uvar*) -> v] ,[(Triv lbl* uvar*) -> t]) exp]
        [(if ,[(Pred lbl* uvar*) -> p] ,[(Effect lbl* uvar*) -> e0] ,[(Effect lbl* uvar*) -> e1]) exp]
        [(begin ,[(Effect lbl* uvar*) -> e*] ... ,[(Effect lbl* uvar*) -> e]) exp]
        [,else (invalid who 'Effect else)])))
  
  (define (Pred lbl* uvar*)
    (lambda (exp)
      (match exp
        [(true) exp]
        [(false) exp]
        [(,r ,[(Triv lbl* uvar*) -> t0] ,[(Triv lbl* uvar*) -> t1])
         (error-unless (relop? r) who "invalid relop: ~s" exp)]
        [(if ,[p0] ,[p1] ,[p2]) exp]
        [(begin ,[(Effect lbl* uvar*) -> e*] ... ,[p]) (void)]
        [,else (invalid who 'Pred else)])))
  
  (define (Tail lbl* uvar*)
    (lambda (exp)
      (match exp
        [(if ,[(Pred lbl* uvar*) -> p] ,[(Tail lbl* uvar*) -> t0] ,[(Tail lbl* uvar*) -> t1]) (void)]
        [(begin ,[(Effect lbl* uvar*) -> e*] ... ,[(Tail lbl* uvar*) -> t]) (void)]
        [(,[(Triv lbl* uvar*) -> t])
         (error-when (integer? t) who "machine constraint violation: jump must be to label, not address: ~s" exp)]
        [,else (invalid who 'Tail else)])))
  
  (define (Body lbl*)
    (lambda (exp)
      (match exp
        [(locals (,uvar* ...) ,tail)
         (verify-x-list `(,uvar* ...) uvar? 'uvar)
         ((Tail lbl* uvar*) tail)]
        [,else (invalid who 'Body else)])))
  
  (define (Program exp)
    (match exp
      [(letrec ([,lbl* (lambda () ,bn)] ...) ,b0)
       (verify-x-list lbl* label? 'label)
       ((Body lbl*) b0)
       (for-each (Body lbl*) bn)]
      [,else (invalid who 'Program else)])
    exp)
  (Program program))

) ;; End Library.