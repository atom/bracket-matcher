# Bracket Matcher package [![Build Status](https://travis-ci.org/atom/bracket-matcher.svg?branch=master)](https://travis-ci.org/atom/bracket-matcher)

Highlights and jumps between `[]`, `()`, and `{}`. Also highlights matching XML
and HTML tags.

Autocompletes `[]`, `()`, and `{}`, `""`, `''`, `“”`, `‘’` and backticks.

From the settings menu you can toggle whether (English- and
French-style) quotation marks (`“”`, `‘’`, `«»` and `‹›`)
are treated like brackets in autocompletion.

Use `ctrl-m` to jump to the bracket matching the one adjacent to the cursor.
It jumps to the nearest enclosing bracket when there's no adjacent bracket,

Use `ctrl-cmd-m` to select all the text inside the current brackets.

Matching brackets and quotes are sensibly inserted for you. If you dislike this
functionality, you can disable it from the Bracket Matcher section of the
Settings view (`cmd-,`).
