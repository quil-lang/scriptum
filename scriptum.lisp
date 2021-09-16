(defpackage #:scriptum
  (:use #:cl #:named-readtables)
  (:export #:syntax
           #:*debug-stream*
           #:*form-handler*
           #:default-form-handler
           #:*string-handler*))

(in-package #:scriptum)

;;; For debugging

(declaim (type (or boolean stream) *debug-stream*))
(defvar *debug-stream* nil)
(defun dbg* (control &rest args)
  (format *debug-stream* "; SCRIPTUM: ")
  (apply #'format *debug-stream* control args)
  (fresh-line *debug-stream*)
  (finish-output *debug-stream*))
(defmacro dbg (control &rest args)
  `(when *debug-stream*
     (dbg* ,control ,@args)))
(defun at-most (n obj)
  (let ((str (remove #\Newline (prin1-to-string obj))))
    (if (< n (length str))
        (concatenate 'string (subseq str 0 (- n 3)) "...")
        str)))


;;; Customizing Scriptum Behavior

(defun default-form-handler (operator &key options body)
  "The default handler for *FORM-HANDLER*. This function produces a list

    (<operator> <spliced options> <spliced body>)

which follows the behavior of Racket's Scribble system."
  (append (list operator) options body))

(defvar *form-handler* 'default-form-handler
  "How should we handle each produced form?

This must be a function with the following lambda list:

    (OPERATOR &key (OPTIONS nil OPTIONS-PRESENT-P)
                   (BODY    nil BODY-PRESENT-P))

The arguments indicate the following:

    - OPERATOR: A Lisp form (almost always a symbol in idiomatic usage) representing the operator.

    - OPTIONS: If OPTIONS-PRESENT-P, then a list of options, typically a p-list. If OPTIONS-PRESENT-P is null, then the form as read did not have options present.

    - BODY: If BODY-PRESENT-P, a list of strings and sub-forms. If BODY-PRESENT-P is null, then the form as read did not have a body present.

The function should produce an object representative of the form being handled.

The default handler is SCRIPTUM:DEFAULT-FORM-HANDLER.")

(defvar *string-handler* 'identity
  "How should plain strings be handled?

This should be a unary function taking a string and returning an object. By default, it just returns the string.")

;;; Scriptum Stuff

(defconstant +at-sign+ #\@)
(defconstant +left-brace+ #\{)
(defconstant +right-brace+ #\})
(defconstant +left-bracket+ #\[)
(defconstant +right-bracket+ #\])

(defparameter *trim-characters*
  (vector #\Space #\Newline #\Backspace #\Tab 
          #\Linefeed #\Page #\Return #\Rubout)
  "Additional characters to trim.")

(defun whitespacep (string)
  (and (cl-ppcre:scan "^\\s+$" string) t))

(defun whitespace-char-p (c)
  (let ((s (load-time-value
            (make-string 1))))
    (setf (char s 0) c)
    (whitespacep s)))

(defun read-string (stream balance)
  "Read a string from STREAM until BALANCE is zero, or we hit another Scriptum form. 

BALANCE indicates the difference (# of left braces) - (# of right braces) so far."
  (let* ((whitespace-only t)
         (raw
           (with-output-to-string (out-stream)
             ;; If we're balanced, or the next char is @, we don't want
             ;; to consume any more.
             (loop :for c := (peek-char nil stream nil nil t)
                   :until (or (null c)
                              (zerop balance)
                              (char= c +at-sign+))
                   ;; Ok, consume the next character.
                   :do (progn
                         (read-char stream t nil t)
                         (incf balance
                               (cond ((char= c +left-brace+) 1)
                                     ((char= c +right-brace+) -1)
                                     (t 0)))
                         (when (plusp balance)
                           (unless (whitespace-char-p c)
                             (setf whitespace-only nil))
                           (write-char c out-stream))
                         (cond ((zerop balance) )))))))
    (values
     (if whitespace-only
         ""
         raw)
     balance)))


(defun read-left-bracket (stream char)
  "Read a list delimited by brackets."
  (declare (ignore char))
  (read-delimited-list +right-bracket+ stream t))


(defun read-left-brace (stream char)
  "Read from a left brace until we have a matching right brace."
  (declare (ignore char))
  (loop :with balance := 1
        :for iter :from 0
        :for (string new-balance) := (multiple-value-list
                                      (read-string stream balance))
        :do (setf balance new-balance)
        ;; we need to trim the start of the first string
        :when (zerop iter)
          :do (setf string (string-left-trim *trim-characters* string))
        ;; and the end of the last
        :when (zerop balance)
          :do (setf string (string-right-trim *trim-characters* string))
        :when (plusp (length string))
          :collect (funcall *string-handler* string)
        :when (plusp balance)
          :collect (read stream t nil t)
        :until (zerop balance)))


(defun error-on-delimiter (stream char)
  "Raise an error if we hit a delimiter (e.g. }) in an unexpected context."
  (declare (ignore stream))
  (error "Delimiter ~S shouldn't be read alone" char))


(defun read-scriptum-expression (stream char)
  "Read a full Scriptum expression."
  (declare (ignore char))
  (flet ((peek () (peek-char nil stream nil nil t)))
    (when (and (peek) (char= #\@ (peek)))
      (dbg "Literal @ sign")
      (assert (char= #\@ (read-char stream t nil t)))
      (return-from read-scriptum-expression "@"))
    (let ((operator (read stream t nil t))
          (args '()))
      (dbg "@~S" operator)
      (when (and (peek) (char= +left-bracket+ (peek)))
        (setf (getf args ':options) (read stream nil nil t)))
      (when (and (peek) (char= +left-brace+ (peek)))
        (setf (getf args ':body) (read stream nil nil t))
        (dbg "    ~A" (at-most 50 (getf args ':body))))
      (apply *form-handler* operator args))))


(named-readtables:defreadtable syntax
  (:merge :standard)
  (:macro-char +at-sign+ 'read-scriptum-expression)
  (:macro-char +left-bracket+ 'read-left-bracket)
  (:macro-char +right-bracket+ (get-macro-character #\) nil))
  (:macro-char +left-brace+ 'read-left-brace)
  (:macro-char +right-brace+ 'error-on-delimiter))

