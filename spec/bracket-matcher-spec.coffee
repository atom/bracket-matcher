{WorkspaceView} = require 'atom'

path = require 'path'

describe "bracket matching", ->
  [editorView, editor, buffer] = []

  beforeEach ->
    atom.config.set 'bracket-matcher.autocompleteBrackets', true

    atom.workspaceView = new WorkspaceView
    atom.workspaceView.attachToDom()

    waitsForPromise ->
      atom.workspace.open('sample.js')

    waitsForPromise ->
      atom.packages.activatePackage('bracket-matcher')

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('language-xml')

    runs ->
      editorView = atom.workspaceView.getActiveView()
      {editor} = editorView
      {buffer} = editor

  describe "matching bracket highlighting", ->
    describe "when the cursor is before a starting pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveCursorToEndOfLine()
        editor.moveCursorLeft()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,28])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([12,0])

        expect(editorView.underlayer.find('.bracket-matcher:first').width()).toBeGreaterThan 0
        expect(editorView.underlayer.find('.bracket-matcher:last').width()).toBeGreaterThan 0
        expect(editorView.underlayer.find('.bracket-matcher:first').height()).toBeGreaterThan 0
        expect(editorView.underlayer.find('.bracket-matcher:last').height()).toBeGreaterThan 0

    describe "when the cursor is after a starting pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveCursorToEndOfLine()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,28])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([12,0])

    describe "when the cursor is before an ending pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveCursorToBottom()
        editor.moveCursorLeft()
        editor.moveCursorLeft()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([12,0])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,28])

    describe "when the cursor is after an ending pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveCursorToBottom()
        editor.moveCursorLeft()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([12,0])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,28])

    describe "when there are unpaired brackets", ->
      it "highlights the correct start/end pairs", ->
        editor.setText '(()'
        editor.setCursorBufferPosition([0,0])
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0

        editor.setCursorBufferPosition([0,1])
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,2])

        editor.setCursorBufferPosition([0,2])
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,2])

        editor.setText ('())')
        editor.setCursorBufferPosition([0,0])
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,0])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])

        editor.setCursorBufferPosition([0,1])
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,0])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])

        editor.setCursorBufferPosition([0,2])
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0

    describe "when the cursor is moved off a pair", ->
      it "removes the starting pair and ending pair highlights", ->
        editor.moveCursorToEndOfLine()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        editor.moveCursorToBeginningOfLine()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0

    describe "when the pair moves", ->
      it "repositions the highlights", ->
        editor.moveCursorToEndOfLine()
        editor.moveCursorLeft()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        editor.backspaceToBeginningOfLine()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2

    describe "when the font size changes", ->
      it "repositions the highlights", ->
        editor.moveCursorToBottom()
        editor.moveCursorLeft()
        atom.config.set('editor.fontSize', editorView.getFontSize() + 10)
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([12,0])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,28])

    describe "when the soft wrap setting changes on the editor", ->
      it "repositions the highlights", ->
        editorView.setWidthInChars(200)
        editor.setSoftWrap(true)
        editor.moveCursorToBottom()
        editor.moveCursorLeft()
        editorView.setWidthInChars(23)

        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([12,0])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,28])

        editor.setSoftWrap(false)
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([12,0])
        expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,28])

    describe "pair balancing", ->
      describe "when a second starting pair preceeds the first ending pair", ->
        it "advances to the second ending pair", ->
          editor.setCursorBufferPosition([8,42])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([8,42])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([8,54])

    describe "when the cursor is destroyed", ->
      it "updates the highlights to use the editor's last cursor", ->
        editor.setCursorBufferPosition([0,29])
        editor.addCursorAtBufferPosition([9,0])
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
        editor.consolidateSelections()
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0
        editor.setCursorBufferPosition([0,29])
        expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2

    describe "HTML/XML tag matching", ->
      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('sample.xml')

        runs ->
          editorView = atom.workspaceView.getActiveView()
          {editor} = editorView
          {buffer} = editor

      describe "when on an opening tag", ->
        it "highlight the opening and closing tag", ->
          buffer.setText """
            <test>
              <test>text</test>
              <!-- </test> -->
            </test>
          """
          editor.setCursorBufferPosition([0,0])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0

          editor.setCursorBufferPosition([0,1])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([3,2])

      describe "when on a closing tag", ->
        it "highlight the opening and closing tag", ->
          buffer.setText """
            <test>
              <!-- <test> -->
              <test>text</test>
            </test>
          """
          editor.setCursorBufferPosition([0,0])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0

          editor.setCursorBufferPosition([3,2])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([3,2])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])

      describe "when the tag spans multiple lines", ->
        it "highlights the opening and closing tag", ->
          buffer.setText """
            <test
              a="test">
              text
            </test>
          """
          editor.setCursorBufferPosition([0,0])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0

          editor.setCursorBufferPosition([3,2])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([3,2])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])

          editor.setCursorBufferPosition([0,1])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([3,2])

      describe "when the tag has attributes", ->
        it "highlights the opening and closing tags", ->
          buffer.setText """
            <test a="test">
              text
            </test>
          """
          editor.setCursorBufferPosition([0,0])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0

          editor.setCursorBufferPosition([2,2])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([2,2])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])

          editor.setCursorBufferPosition([0,7])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([2,2])

      describe "when the opening and closing tags are on the same line", ->
        it "highlight the opening and closing tags", ->
          buffer.setText "<test>text</test>"
          editor.setCursorBufferPosition([0,0])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 0

          editor.setCursorBufferPosition([0,2])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,12])

          editor.setCursorBufferPosition([0,12])
          expect(editorView.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editorView.underlayer.find('.bracket-matcher:first').position()).toEqual editorView.pixelPositionForBufferPosition([0,12])
          expect(editorView.underlayer.find('.bracket-matcher:last').position()).toEqual editorView.pixelPositionForBufferPosition([0,1])

  describe "when bracket-matcher:go-to-matching-bracket is triggered", ->
    describe "when the cursor is before the starting pair", ->
      it "moves the cursor to after the ending pair", ->
        editor.moveCursorToEndOfLine()
        editor.moveCursorLeft()
        editorView.trigger "bracket-matcher:go-to-matching-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [12, 1]

    describe "when the cursor is after the starting pair", ->
      it "moves the cursor to before the ending pair", ->
        editor.moveCursorToEndOfLine()
        editorView.trigger "bracket-matcher:go-to-matching-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [12, 0]

    describe "when the cursor is before the ending pair", ->
      it "moves the cursor to after the starting pair", ->
        editor.setCursorBufferPosition([12, 0])
        editorView.trigger "bracket-matcher:go-to-matching-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [0, 29]

    describe "when the cursor is after the ending pair", ->
      it "moves the cursor to before the starting pair", ->
        editor.setCursorBufferPosition([12, 1])
        editorView.trigger "bracket-matcher:go-to-matching-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [0, 28]

    describe "when the cursor is not adjacent to a pair", ->
      describe "when within a `{}` pair", ->
        it "moves the cursor to before the enclosing brace", ->
          editor.setCursorBufferPosition([11, 2])
          editorView.trigger "bracket-matcher:go-to-matching-bracket"
          expect(editor.getCursorBufferPosition()).toEqual [0, 28]

      describe "when within a `()` pair", ->
        it "moves the cursor to before the enclosing brace", ->
          editor.setCursorBufferPosition([2, 14])
          editorView.trigger "bracket-matcher:go-to-matching-bracket"
          expect(editor.getCursorBufferPosition()).toEqual [2, 7]

  describe "when bracket-matcher:go-to-enclosing-bracket is triggered", ->
    describe "when within a `{}` pair", ->
      it "moves the cursor to before the enclosing brace", ->
        editor.setCursorBufferPosition([11, 2])
        editorView.trigger "bracket-matcher:go-to-enclosing-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [0, 28]

    describe "when within a `()` pair", ->
      it "moves the cursor to before the enclosing brace", ->
        editor.setCursorBufferPosition([2, 14])
        editorView.trigger "bracket-matcher:go-to-enclosing-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [2, 7]

  describe "when bracket-match:select-inside-brackets is triggered", ->
    describe "when the cursor on the left side of a bracket", ->
      it "selects the text inside the brackets", ->
        editor.setCursorBufferPosition([0,28])
        editorView.trigger "bracket-matcher:select-inside-brackets"
        expect(editor.getSelectedBufferRange()).toEqual [[0, 29], [12, 0]]

    describe "when the cursor on the right side of a brack", ->
      it "selects the text inside the brackets", ->
        editor.setCursorBufferPosition([1,30])
        editorView.trigger "bracket-matcher:select-inside-brackets"
        expect(editor.getSelectedBufferRange()).toEqual [[1, 30], [9, 2]]

    describe "when the cursor is inside the brackets", ->
      it "selects the text for the closest outer brackets", ->
        editor.setCursorBufferPosition([6,6])
        editorView.trigger "bracket-matcher:select-inside-brackets"
        expect(editor.getSelectedBufferRange()).toEqual [[4, 29], [7, 4]]

  describe "matching bracket deletion", ->
    beforeEach ->
      editor.buffer.setText("")

    describe "when selection is not a matching pair of brackets", ->
      it "does not change the text", ->
        editor.insertText("\"woah(")
        editor.selectAll()
        editorView.trigger "bracket-matcher:remove-brackets-from-selection"
        expect(editor.buffer.getText()).toBe "\"woah("

    describe "when selecting a matching pair of brackets", ->
      describe "on the same line", ->
        beforeEach ->
          editor.buffer.setText("it \"does something\", :meta => true")
          editor.setSelectedBufferRange([[0, 3],[0,19]])
          editorView.trigger "bracket-matcher:remove-brackets-from-selection"

        it "removes the brackets", ->
          expect(editor.buffer.getText()).toBe "it does something, :meta => true"

        it "selects the newly unbracketed text", ->
          expect(editor.getSelectedText()).toBe "does something"

      describe "on separate lines", ->
        beforeEach ->
          editor.buffer.setText("it (\"does something\" do\nend)")
          editor.setSelectedBufferRange([[0, 3],[1,4]])
          editorView.trigger "bracket-matcher:remove-brackets-from-selection"

        it "removes the brackets", ->
          expect(editor.buffer.getText()).toBe "it \"does something\" do\nend"

        it "selects the newly unbracketed text", ->
          expect(editor.getSelectedText()).toBe "\"does something\" do\nend"

  describe "matching bracket insertion", ->
    beforeEach ->
      editor.buffer.setText("")

    describe "when more than one character is inserted", ->
      it "does not insert a matching bracket", ->
        editor.insertText("woah(")
        expect(editor.buffer.getText()).toBe "woah("

    describe "when there is a word character after the cursor", ->
      it "does not insert a matching bracket", ->
        editor.buffer.setText("ab")
        editor.setCursorBufferPosition([0, 1])
        editor.insertText("(")

        expect(editor.buffer.getText()).toBe "a(b"

    describe "when autocompleteBrackets configuration is disabled", ->
      it "does not insert a matching bracket", ->
        atom.config.set 'bracket-matcher.autocompleteBrackets', false
        editor.buffer.setText("}")
        editor.setCursorBufferPosition([0, 0])
        editor.insertText '{'
        expect(buffer.lineForRow(0)).toBe "{}"
        expect(editor.getCursorBufferPosition()).toEqual([0,1])

    describe "when there are multiple cursors", ->
      it "inserts ) at each cursor", ->
        editor.buffer.setText("()\nab\n[]\n12")
        editor.setCursorBufferPosition([3, 1])
        editor.addCursorAtBufferPosition([2, 1])
        editor.addCursorAtBufferPosition([1, 1])
        editor.addCursorAtBufferPosition([0, 1])
        editor.insertText ')'

        expect(editor.buffer.getText()).toBe "())\na)b\n[)]\n1)2"

    describe "when there is a non-word character after the cursor", ->
      it "inserts a closing bracket after an opening bracket is inserted", ->
        editor.buffer.setText("}")
        editor.setCursorBufferPosition([0, 0])
        editor.insertText '{'
        expect(buffer.lineForRow(0)).toBe "{}}"
        expect(editor.getCursorBufferPosition()).toEqual([0,1])

    describe "when the cursor is at the end of the line", ->
      it "inserts a closing bracket after an opening bracket is inserted", ->
        editor.buffer.setText("")
        editor.insertText '{'
        expect(buffer.lineForRow(0)).toBe "{}"
        expect(editor.getCursorBufferPosition()).toEqual([0,1])

        editor.buffer.setText("")
        editor.insertText '('
        expect(buffer.lineForRow(0)).toBe "()"
        expect(editor.getCursorBufferPosition()).toEqual([0,1])

        editor.buffer.setText("")
        editor.insertText '['
        expect(buffer.lineForRow(0)).toBe "[]"
        expect(editor.getCursorBufferPosition()).toEqual([0,1])

        editor.buffer.setText("")
        editor.insertText '"'
        expect(buffer.lineForRow(0)).toBe '""'
        expect(editor.getCursorBufferPosition()).toEqual([0,1])

        editor.buffer.setText("")
        editor.insertText "'"
        expect(buffer.lineForRow(0)).toBe "''"
        expect(editor.getCursorBufferPosition()).toEqual([0,1])

    describe "when the cursor is on a closing bracket and a closing bracket is inserted", ->
      describe "when the closing bracket was there previously", ->
        it "inserts a closing bracket", ->
          editor.insertText '()x'
          editor.setCursorBufferPosition([0, 1])
          editor.insertText ')'
          expect(buffer.lineForRow(0)).toBe "())x"
          expect(editor.getCursorBufferPosition().column).toBe 2

      describe "when the closing bracket was automatically inserted from inserting an opening bracket", ->
        it "only moves cursor over the closing bracket one time", ->
          editor.insertText '('
          expect(buffer.lineForRow(0)).toBe "()"
          editor.setCursorBufferPosition([0, 1])
          editor.insertText ')'
          expect(buffer.lineForRow(0)).toBe "()"
          expect(editor.getCursorBufferPosition()).toEqual [0, 2]

          editor.setCursorBufferPosition([0, 1])
          editor.insertText ')'
          expect(buffer.lineForRow(0)).toBe "())"
          expect(editor.getCursorBufferPosition()).toEqual [0, 2]

        it "moves cursor over the closing bracket after other text is inserted", ->
          editor.insertText '('
          editor.insertText 'ok cool'
          expect(buffer.lineForRow(0)).toBe "(ok cool)"
          editor.setCursorBufferPosition([0, 8])
          editor.insertText ')'
          expect(buffer.lineForRow(0)).toBe "(ok cool)"
          expect(editor.getCursorBufferPosition()).toEqual [0, 9]

        it "works with nested brackets", ->
          editor.insertText '('
          editor.insertText '1'
          editor.insertText '('
          editor.insertText '2'
          expect(buffer.lineForRow(0)).toBe "(1(2))"
          editor.setCursorBufferPosition([0, 4])
          editor.insertText ')'
          expect(buffer.lineForRow(0)).toBe "(1(2))"
          expect(editor.getCursorBufferPosition()).toEqual [0, 5]
          editor.insertText ')'
          expect(buffer.lineForRow(0)).toBe "(1(2))"
          expect(editor.getCursorBufferPosition()).toEqual [0, 6]

        it "works with mixed brackets", ->
          editor.insertText '('
          editor.insertText '}'
          expect(buffer.lineForRow(0)).toBe "(})"
          editor.insertText ')'
          expect(buffer.lineForRow(0)).toBe "(})"
          expect(editor.getCursorBufferPosition()).toEqual [0, 3]

        it "closes brackets with the same begin/end character correctly", ->
          editor.insertText '"'
          editor.insertText 'ok'
          expect(buffer.lineForRow(0)).toBe '"ok"'
          expect(editor.getCursorBufferPosition()).toEqual [0, 3]
          editor.insertText '"'
          expect(buffer.lineForRow(0)).toBe '"ok"'
          expect(editor.getCursorBufferPosition()).toEqual [0, 4]

    describe "when there is text selected on a single line", ->
      it "wraps the selection with brackets", ->
        editor.setText 'text'
        editor.moveCursorToBottom()
        editor.selectToTop()
        editor.selectAll()
        editor.insertText '('
        expect(buffer.getText()).toBe '(text)'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 5]]
        expect(editor.getSelection().isReversed()).toBeTruthy()

      describe "when the bracket-matcher.wrapSelectionsInBrackets is falsy", ->
        it "does not wrap the selection in brackets", ->
          atom.config.set('bracket-matcher.wrapSelectionsInBrackets', false)
          editor.setText 'text'
          editor.moveCursorToBottom()
          editor.selectToTop()
          editor.selectAll()
          editor.insertText '('
          expect(buffer.getText()).toBe '('
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

    describe "when there is text selected on multiple lines", ->
      it "wraps the selection with brackets", ->
        editor.insertText 'text\nabcd'
        editor.moveCursorToBottom()
        editor.selectToTop()
        editor.selectAll()
        editor.insertText '('
        expect('(text\nabcd)').toBe buffer.getText()
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [1, 4]]
        expect(editor.getSelection().isReversed()).toBeTruthy()

      describe "when there are multiple selections", ->
        it "wraps each selection with brackets", ->
          editor.setText "a b\nb c\nc b"
          editor.setSelectedBufferRanges [
            [[0, 2], [0, 3]]
            [[1, 0], [1, 1]]
            [[2, 2], [2, 3]]
          ]

          editor.insertText '"'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 3], [0, 4]]
            [[1, 1], [1, 2]]
            [[2, 3], [2, 4]]
          ]

          expect(buffer.lineForRow(0)).toBe 'a "b"'
          expect(buffer.lineForRow(1)).toBe '"b" c'
          expect(buffer.lineForRow(2)).toBe 'c "b"'

    describe "when inserting a quote", ->
      describe "when a word character is before the cursor", ->
        it "does not automatically insert the closing quote", ->
          editor.buffer.setText("abc")
          editor.setCursorBufferPosition([0, 3])
          editor.insertText '"'
          expect(buffer.lineForRow(0)).toBe "abc\""

          editor.buffer.setText("abc")
          editor.setCursorBufferPosition([0, 3])
          editor.insertText '\''
          expect(buffer.lineForRow(0)).toBe "abc\'"

      describe "when a quote is before the cursor", ->
        it "does not automatically insert the closing quote", ->
          editor.buffer.setText("''")
          editor.setCursorBufferPosition([0, 3])
          editor.insertText "'"
          expect(buffer.lineForRow(0)).toBe "'''"

          editor.buffer.setText('""')
          editor.setCursorBufferPosition([0, 3])
          editor.insertText '"'
          expect(buffer.lineForRow(0)).toBe '"""'

          editor.buffer.setText("''")
          editor.setCursorBufferPosition([0, 3])
          editor.insertText '"'
          expect(buffer.lineForRow(0)).toBe "''\"\""

      describe "when a non word character is before the cursor", ->
        it "automatically inserts the closing quote", ->
          editor.buffer.setText("ab@")
          editor.setCursorBufferPosition([0, 3])
          editor.insertText '"'
          expect(buffer.lineForRow(0)).toBe "ab@\"\""
          expect(editor.getCursorBufferPosition()).toEqual [0, 4]

      describe "when the cursor is on an empty line", ->
        it "automatically inserts the closing quote", ->
          editor.buffer.setText("")
          editor.setCursorBufferPosition([0, 0])
          editor.insertText '"'
          expect(buffer.lineForRow(0)).toBe "\"\""
          expect(editor.getCursorBufferPosition()).toEqual [0, 1]

      describe "when the select option to Editor::insertText is true", ->
        it "does not automatically insert the closing quote", ->
          editor.buffer.setText("")
          editor.setCursorBufferPosition([0, 0])
          editor.insertText '"', select: true
          expect(buffer.lineForRow(0)).toBe '"'
          expect(editor.getCursorBufferPosition()).toEqual [0, 1]

      describe "when the undo option to Editor::insertText is 'skip'", ->
        it "does not automatically insert the closing quote", ->
          editor.buffer.setText("")
          editor.setCursorBufferPosition([0, 0])
          editor.insertText '"', undo: 'skip'
          expect(buffer.lineForRow(0)).toBe '"'
          expect(editor.getCursorBufferPosition()).toEqual [0, 1]

    describe "when return is pressed inside a matching pair", ->
      it "puts cursor on autoindented empty line", ->
        editor.insertText 'void main() '
        editor.insertText '{'
        expect(buffer.lineForRow(0)).toBe 'void main() {}'
        editor.insertNewline()
        expect(editor.getCursorBufferPosition()).toEqual [1, 2]
        expect(buffer.lineForRow(1)).toBe '  '
        expect(buffer.lineForRow(2)).toBe '}'

        editor.setText '  void main() '
        editor.insertText '{'
        expect(buffer.lineForRow(0)).toBe '  void main() {}'
        editor.insertNewline()
        expect(editor.getCursorBufferPosition()).toEqual [1, 4]
        expect(buffer.lineForRow(1)).toBe '    '
        expect(buffer.lineForRow(2)).toBe '  }'

      describe "when undo is triggered", ->
        it "removes both newlines", ->
          editor.insertText 'void main() '
          editor.insertText '{'
          editor.insertNewline()
          editor.undo()
          expect(buffer.lineForRow(0)).toBe 'void main() {}'

  describe "matching bracket deletion", ->
    it "deletes the end bracket when it directly proceeds a begin bracket that is being backspaced", ->
      buffer.setText("")
      editor.setCursorBufferPosition([0, 0])
      editor.insertText '{'
      expect(buffer.lineForRow(0)).toBe "{}"
      editor.backspace()
      expect(buffer.lineForRow(0)).toBe ""
