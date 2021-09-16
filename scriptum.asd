(asdf:defsystem #:scriptum
  :description "Reader extensions for Scribble-like syntax"
  :author "Erik Davis <erik@cadlag.org>, Robert Smith <robert@stylewarning.com>"
  :maintainer "Robert Smith <robert@stylewarning.com>"
  :license "MIT"
  :depends-on (#:named-readtables #:cl-ppcre)
  :serial t
  :components ((:file "scriptum")))
