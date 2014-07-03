# Bracket Matcher package [![Build Status](https://travis-ci.org/atom/bracket-matcher.svg?branch=master)](https://travis-ci.org/atom/bracket-matcher)

Highlights and jumps between `[]`, `()`, and `{}`. Also highlights matching XML
and HTML tags.

Autocompletes `[]`, `()`, and `{}`, `""`, `''`, `“”`, `‘’`, `«»`, `‹›`, and
backticks.

You can toggle whether English/French style quotation marks (`“”`, `‘’`, `«»`
and `‹›`) are autocompleted via the *Autocomplete Smart Quotes*  setting in the
settings view.

Use `ctrl-m` to jump to the bracket matching the one adjacent to the cursor.
It jumps to the nearest enclosing bracket when there's no adjacent bracket,

Use `ctrl-cmd-m` to select all the text inside the current brackets.

Use `alt-cmd-.` to close the current XML/HTML tag.

Matching brackets and quotes are sensibly inserted for you. If you dislike this
functionality, you can disable it from the Bracket Matcher section of the
Settings view (`cmd-,`).
