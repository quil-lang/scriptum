# Scriptum: Documentation Syntax for Common Lisp

Scriptum a handful of reader macros to allow for S-expressions that contain many strings.

## Getting Started

Load Scriptum and activate the `scriptum:syntax` readtable:

```lisp
CL-USER> (named-readtables:in-readtable scrawl:syntax)
CL-USER> '@a[:href "https://quil-lang.github.io"]{C o a l t o n}
(A :HREF "https://coalton-lang.github.io" "C o a l t o n")
```

It's incredibly important to recognize that Scriptum is _just an alternative S-expression syntax_, optimized for a different use-case. That means expressions must be appropriately quoted lest you want evaluation to occur..

## Details

Scriptum provides an extension to the standard readtable which gives special treatment to the `@ [ ] { }` characters. The general form of a *Scriptum expression* is

``` 
'@' <op> <args>? <body>?
```

where

- `<op>` is any Lisp expression,
- `<args>` is an optional square-bracketed list of Lisp expressions, e.g. `[1 2 3]`, and
- `<body>` is an optional sequence of (mostly) unescaped text, surrounded by braces, e.g. `{ foo frob }`.

Note that the above is sensitive to spaces, so `@foo [1 2 3]` is different from `@foo[1 2 3]`.

The body of a Scriptum expression consists of text, possibly containing further Scriptum expressions. This is read recursively as a sequence of strings and Scriptum expressions. The result of reading 
```
@<op>[<arg1> ... <argN>]{ <body1> ... <bodyM> }
```
is
```
(<op> <arg1> ... <argN> <body1> ... <bodyM>)
```
where `<body>` contained a total of `M` text-segments (possibly containing whitespace) and Scriptum expressions.

Here's an extended example:
```
@div[:id "my-div"]{
  @h1{
    Hello World!
  }
  @p{
    The quick @b{brown}
    fox jumps over
    the lazy dog.
  }
}
```

is read as

```
(DIV :ID "my-div" (H1 "Hello World!")
 (P "The quick " (B "brown") "
    fox jumps over
    the lazy dog."))
```

### A few design decisions

There are a few choices we have made. 

- Whitespace is trimmed from the start of the first string and the end
  of the last, e.g. `@foo{ bar @baz frob }` results in `(FOO "bar " BAZ " frob")`

- Whitespace-only strings are ignored, e.g.  `@foo{ }` results in `(FOO)`.

- Escaping within the body of a Scriptum expression is accomplished via
  `@`, e.g. `@foo{ @"@" }` yields `(FOO "@")`

- The easiest way force inclusion of whitespace is to escape it:
  `@foo{@" "bar}` yields `'(FOO " " "bar")`

- Nested braces are fine if they are balanced: `@foo{ { } }` yields `(FOO "{ }")`

- Unbalanced braces must be escaped, e.g. `@foo{ @"{"  }` yields `(FOO "{")`

## Customizing Scriptum

### Debugging

Scriptum comingles with the ordinary Lisp reader, which may lead to inscrutible parse errors. The variable `scriptum:*debug-stream*` can be set to a stream (e.g., `*standard-output*`) and Scriptum will print its progress in processing Scriptum data.

### Handling Forms

By default, Scriptum assembles a list for a Scriptum expression, but this behavior can be customized. A *form handler* is a function with lambda list

```lisp
(operator &key options body)
```

where

- `operator` represents the expression after `@`
- `options` represents the list of options in `[` brackets `]`
- `body` represents the list of character and nested data.

One may bind a new form handler to the variable `scriptum:*form-handler*`. The default form handler is `#'scriptum:default-form-handler`.

One use-case is to produce CLOS objects instead of lists, by dispatching off of the `operator` and building an object.

### Handling Strings

Strings within the body of a Scriptum expression may also be customized with a *string handler* function bound to `scrawl:*string-handler*`. A string handler must take a string and return an object (which may not be a string). The default string handler is `#'identity`, and thus strings remain unprocessed.

## Acknowledgements

Scriptum was forked from  [Scrawl](https://github.com/kilimanjaro/scrawl), which is a pedagogical clone of [Scribble](https://docs.racket-lang.org/scribble/).

Eli Barzilay's [The Scribble Reader](http://barzilay.org/misc/scribble-reader.pdf) was also inspiration in the design decisions around Scriptum.

