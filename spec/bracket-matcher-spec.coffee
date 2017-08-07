describe "bracket matching", ->
  [editorElement, editor, buffer] = []

  beforeEach ->
    atom.config.set 'bracket-matcher.autocompleteBrackets', true

    waitsForPromise ->
      atom.packages.activatePackage('bracket-matcher')

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('language-xml')

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      editor = atom.workspace.getActiveTextEditor()
      editorElement = atom.views.getView(editor)
      buffer = editor.getBuffer()

  describe "matching bracket highlighting", ->
    expectNoHighlights = ->
      decorations = editor.getHighlightDecorations().filter (decoration) -> decoration.properties.class is 'bracket-matcher'
      expect(decorations.length).toBe 0

    expectHighlights = (startBufferPosition, endBufferPosition) ->
      decorations = editor.getHighlightDecorations().filter (decoration) -> decoration.properties.class is 'bracket-matcher'
      expect(decorations.length).toBe 2

      expect(decorations[0].marker.getStartBufferPosition()).toEqual startBufferPosition
      expect(decorations[1].marker.getStartBufferPosition()).toEqual endBufferPosition

    describe "when the cursor is before a starting pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveToEndOfLine()
        editor.moveLeft()
        expectHighlights([0, 28], [12, 0])

    describe "when the cursor is after a starting pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveToEndOfLine()
        expectHighlights([0, 28], [12, 0])

    describe "when the cursor is before an ending pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveToBottom()
        editor.moveLeft()
        editor.moveLeft()
        expectHighlights([12, 0], [0, 28])

    describe "when closing multiple pairs", ->
      it "always highlights the inner pair", ->
        editor.setCursorBufferPosition([8, 53])
        expectHighlights([8, 53], [8, 47])
        editor.moveRight()
        expectHighlights([8, 53], [8, 47])
        editor.moveRight()
        expectHighlights([8, 54], [8, 42])

    describe "when opening multiple pairs", ->
      it "always highlights the inner pair", ->
        editor.setText '((1 + 1) * 2)'
        editor.setCursorBufferPosition([0, 0])
        expectHighlights([0, 0], [0, 12])
        editor.moveRight()
        expectHighlights([0, 1], [0, 7])
        editor.moveRight()
        expectHighlights([0, 1], [0, 7])

    describe "when the cursor is after an ending pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveToBottom()
        editor.moveLeft()
        expectHighlights([12, 0], [0, 28])

    describe "when there are unpaired brackets", ->
      it "highlights the correct start/end pairs", ->
        editor.setText '(()'
        editor.setCursorBufferPosition([0, 0])
        expectNoHighlights()

        editor.setCursorBufferPosition([0, 1])
        expectHighlights([0, 1], [0, 2])

        editor.setCursorBufferPosition([0, 2])
        expectHighlights([0, 1], [0, 2])

        editor.setText ('())')
        editor.setCursorBufferPosition([0, 0])
        expectHighlights([0, 0], [0, 1])

        editor.setCursorBufferPosition([0, 1])
        expectHighlights([0, 0], [0, 1])

        editor.setCursorBufferPosition([0, 2])
        expectHighlights([0, 1], [0, 0])

        editor.setCursorBufferPosition([0, 3])
        expectNoHighlights()

    describe "when there are commented brackets", ->
      it "highlights the correct start/end pairs", ->
        editor.setText '(//)'
        editor.setCursorBufferPosition([0, 0])
        expectNoHighlights()

        editor.setCursorBufferPosition([0, 2])
        expectNoHighlights()

        editor.setCursorBufferPosition([0, 3])
        expectNoHighlights()

        editor.setText '{/*}*/'
        editor.setCursorBufferPosition([0, 0])
        expectNoHighlights()

        editor.setCursorBufferPosition([0, 2])
        expectNoHighlights()

        editor.setCursorBufferPosition([0, 3])
        expectNoHighlights()

        editor.setText '[/*]*/]'
        editor.setCursorBufferPosition([0, 0])
        expectHighlights([0, 0], [0, 6])

        editor.setCursorBufferPosition([0, 6])
        expectHighlights([0, 6], [0, 0])

        editor.setCursorBufferPosition([0, 2])
        expectNoHighlights()

    describe "when there are quoted brackets", ->
      it "highlights the correct start/end pairs", ->
        editor.setText "(')')"
        editor.setCursorBufferPosition([0, 0])
        expectHighlights([0, 0], [0, 4])

        editor.setCursorBufferPosition([0, 5])
        expectHighlights([0, 4], [0, 0])

        editor.setCursorBufferPosition([0, 2])
        expectNoHighlights()

        editor.setText '["]"]'
        editor.setCursorBufferPosition([0, 0])
        expectHighlights([0, 0], [0, 4])

        editor.setCursorBufferPosition([0, 5])
        expectHighlights([0, 4], [0, 0])

        editor.setCursorBufferPosition([0, 2])
        expectNoHighlights()

    describe "when there are brackets inside code embedded in a string", ->
      it "highlights the correct start/end pairs", ->
        editor.setText "(`${(1+1)}`)"
        editor.setCursorBufferPosition([0, 0])
        expectHighlights([0, 0], [0, 11])

        editor.setCursorBufferPosition([0, 12])
        expectHighlights([0, 11], [0, 0])

        editor.setCursorBufferPosition([0, 4])
        expectHighlights([0, 4], [0, 8])

    describe "when there are brackets inside a string inside code embedded in a string", ->
      it "highlights the correct start/end pairs", ->
        editor.setText "(`${('(1+1)')}`)"
        editor.setCursorBufferPosition([0, 0])
        expectHighlights([0, 0], [0, 15])

        editor.setCursorBufferPosition([0, 16])
        expectHighlights([0, 15], [0, 0])

        editor.setCursorBufferPosition([0, 6])
        expectNoHighlights()

    describe "when there are brackets in regular expressions", ->
      it "highlights the correct start/end pairs", ->
        editor.setText "(/[)]/)"
        editor.setCursorBufferPosition([0, 0])
        expectHighlights([0, 0], [0, 6])

        editor.setCursorBufferPosition([0, 7])
        expectHighlights([0, 6], [0, 0])

        editor.setCursorBufferPosition([0, 3])
        expectNoHighlights()

    describe "when the start character and end character of the pair are equivalent", ->
      it "does not attempt to highlight pairs", ->
        editor.setText "'hello'"
        editor.setCursorBufferPosition([0, 0])
        expectNoHighlights()

    describe "when the cursor is moved off a pair", ->
      it "removes the starting pair and ending pair highlights", ->
        editor.moveToEndOfLine()
        expectHighlights([0, 28], [12, 0])

        editor.moveToBeginningOfLine()
        expectNoHighlights()

    describe "when the pair moves", ->
      it "repositions the highlights", ->
        editor.moveToEndOfLine()
        editor.moveLeft()
        expectHighlights([0, 28], [12, 0])

        editor.deleteToBeginningOfLine()
        expectHighlights([0, 0], [12, 0])

    describe "pair balancing", ->
      describe "when a second starting pair preceeds the first ending pair", ->
        it "advances to the second ending pair", ->
          editor.setCursorBufferPosition([8, 42])
          expectHighlights([8, 42], [8, 54])

    describe "when a cursor is added or destroyed", ->
      it "updates the highlights to use the new cursor", ->
        editor.setCursorBufferPosition([9, 0])
        expectNoHighlights()

        editor.addCursorAtBufferPosition([0, 29])
        expectHighlights([0, 28], [12, 0])

        editor.addCursorAtBufferPosition([0, 4])
        expectNoHighlights()

        editor.getLastCursor().destroy()
        expectHighlights([0, 28], [12, 0])

    describe "when the cursor moves off (clears) a selection next to a starting or ending pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveToEndOfLine()
        editor.selectLeft()
        editor.getLastCursor().clearSelection()
        expectHighlights([0, 28], [12, 0])

    describe "HTML/XML tag matching", ->
      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('sample.xml')

        runs ->
          editor = atom.workspace.getActiveTextEditor()
          editorElement = atom.views.getView(editor)
          {buffer} = editor

      describe "when on an opening tag", ->
        it "highlight the opening and closing tag", ->
          buffer.setText """
            <test>
              <test>text</test>
              <!-- </test> -->
            </test>
          """

          editor.setCursorBufferPosition([0, 0])
          expectHighlights([0, 1], [3, 2])

          editor.setCursorBufferPosition([0, 1])
          expectHighlights([0, 1], [3, 2])

      describe "when on a closing tag", ->
        it "highlight the opening and closing tag", ->
          buffer.setText """
            <test>
              <!-- <test> -->
              <test>text</test>
            </test>
          """

          editor.setCursorBufferPosition([3, 0])
          expectHighlights([3, 2], [0, 1])

          editor.setCursorBufferPosition([3, 2])
          expectHighlights([3, 2], [0, 1])

          buffer.setText """
            <test>
              <test>text</test>
              <test>text</test>
            </test>
          """

          editor.setCursorBufferPosition([1, Infinity])
          expectHighlights([1, 14], [1, 3])

          editor.setCursorBufferPosition([2, Infinity])
          expectHighlights([2, 14], [2, 3])


      describe "when the tag spans multiple lines", ->
        it "highlights the opening and closing tag", ->
          buffer.setText """
            <test
              a="test">
              text
            </test>
          """

          editor.setCursorBufferPosition([3, 2])
          expectHighlights([3, 2], [0, 1])

          editor.setCursorBufferPosition([0, 1])
          expectHighlights([0, 1], [3, 2])

      describe "when the tag has attributes", ->
        it "highlights the opening and closing tags", ->
          buffer.setText """
            <test a="test">
              text
            </test>
          """

          editor.setCursorBufferPosition([2, 2])
          expectHighlights([2, 2], [0, 1])

          editor.setCursorBufferPosition([0, 7])
          expectHighlights([0, 1], [2, 2])

      describe "when the opening and closing tags are on the same line", ->
        it "highlight the opening and closing tags", ->
          buffer.setText "<test>text</test>"

          editor.setCursorBufferPosition([0, 2])
          expectHighlights([0, 1], [0, 12])

          editor.setCursorBufferPosition([0, 12])
          expectHighlights([0, 12], [0, 1])

  describe "when bracket-matcher:go-to-matching-bracket is triggered", ->
    describe "when the cursor is before the starting pair", ->
      it "moves the cursor to after the ending pair", ->
        editor.moveToEndOfLine()
        editor.moveLeft()
        atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
        expect(editor.getCursorBufferPosition()).toEqual [12, 1]

    describe "when the cursor is after the starting pair", ->
      it "moves the cursor to before the ending pair", ->
        editor.moveToEndOfLine()
        atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
        expect(editor.getCursorBufferPosition()).toEqual [12, 0]

    describe "when the cursor is before the ending pair", ->
      it "moves the cursor to after the starting pair", ->
        editor.setCursorBufferPosition([12, 0])
        atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
        expect(editor.getCursorBufferPosition()).toEqual [0, 29]

    describe "when the cursor is after the ending pair", ->
      it "moves the cursor to before the starting pair", ->
        editor.setCursorBufferPosition([12, 1])
        atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
        expect(editor.getCursorBufferPosition()).toEqual [0, 28]

    describe "when the cursor is not adjacent to a pair", ->
      describe "when within a `{}` pair", ->
        it "moves the cursor to before the enclosing brace", ->
          editor.setCursorBufferPosition([11, 2])
          atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
          expect(editor.getCursorBufferPosition()).toEqual [0, 28]

      describe "when within a `()` pair", ->
        it "moves the cursor to before the enclosing brace", ->
          editor.setCursorBufferPosition([2, 14])
          atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
          expect(editor.getCursorBufferPosition()).toEqual [2, 7]

      describe 'in HTML/XML files', ->
        beforeEach ->
          waitsForPromise ->
            atom.workspace.open('sample.xml')

          runs ->
            editor = atom.workspace.getActiveTextEditor()
            editorElement = atom.views.getView(editor)
            {buffer} = editor

        describe 'when within a <tag></tag> pair', ->
          it "moves the cursor to the starting tag", ->
            editor.setCursorBufferPosition([5, 10])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [4, 9]

        describe 'when on a starting <tag>', ->
          it 'moves the cursor to the end </tag>', ->
            editor.setCursorBufferPosition([1, 2])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 2]

            editor.setCursorBufferPosition([1, 3])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 4]

            editor.setCursorBufferPosition([1, 4])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 5]

            editor.setCursorBufferPosition([1, 5])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 6]

            editor.setCursorBufferPosition([1, 6])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 7]

            editor.setCursorBufferPosition([1, 7])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 8]

            editor.setCursorBufferPosition([1, 8])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 8]

            editor.setCursorBufferPosition([1, 9])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 8]

            editor.setCursorBufferPosition([1, 10])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 8]

            editor.setCursorBufferPosition([1, 16])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [15, 8]

        describe 'when on an ending </tag>', ->
          it 'moves the cursor to the start <tag>', ->
            editor.setCursorBufferPosition([15, 2])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [1, 2]

            editor.setCursorBufferPosition([15, 3])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [1, 3]

            editor.setCursorBufferPosition([15, 4])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [1, 3]

            editor.setCursorBufferPosition([15, 5])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [1, 4]

            editor.setCursorBufferPosition([15, 6])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [1, 5]

            editor.setCursorBufferPosition([15, 7])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [1, 6]

            editor.setCursorBufferPosition([15, 8])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [1, 7]

            editor.setCursorBufferPosition([15, 9])
            atom.commands.dispatch(editorElement, "bracket-matcher:go-to-matching-bracket")
            expect(editor.getCursorBufferPosition()).toEqual [1, 7]

  describe "when bracket-matcher:go-to-enclosing-bracket is triggered", ->
    describe "when within a `{}` pair", ->
      it "moves the cursor to before the enclosing brace", ->
        editor.setCursorBufferPosition([11, 2])
        atom.commands.dispatch(editorElement, "bracket-matcher:go-to-enclosing-bracket")
        expect(editor.getCursorBufferPosition()).toEqual [0, 28]

    describe "when within a `()` pair", ->
      it "moves the cursor to before the enclosing brace", ->
        editor.setCursorBufferPosition([2, 14])
        atom.commands.dispatch(editorElement, "bracket-matcher:go-to-enclosing-bracket")
        expect(editor.getCursorBufferPosition()).toEqual [2, 7]

  describe "when bracket-match:select-inside-brackets is triggered", ->
    describe "when the cursor on the left side of a bracket", ->
      it "selects the text inside the brackets", ->
        editor.setCursorBufferPosition([0, 28])
        atom.commands.dispatch(editorElement, "bracket-matcher:select-inside-brackets")
        expect(editor.getSelectedBufferRange()).toEqual [[0, 29], [12, 0]]

    describe "when the cursor on the right side of a bracket", ->
      it "selects the text inside the brackets", ->
        editor.setCursorBufferPosition([1, 30])
        atom.commands.dispatch(editorElement, "bracket-matcher:select-inside-brackets")
        expect(editor.getSelectedBufferRange()).toEqual [[1, 30], [9, 2]]

    describe "when the cursor is inside the brackets", ->
      it "selects the text for the closest outer brackets", ->
        editor.setCursorBufferPosition([6, 6])
        atom.commands.dispatch(editorElement, "bracket-matcher:select-inside-brackets")
        expect(editor.getSelectedBufferRange()).toEqual [[4, 29], [7, 4]]

    describe 'HTML/XML text', ->
      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('sample.xml')

        runs ->
          editor = atom.workspace.getActiveTextEditor()
          editorElement = atom.views.getView(editor)
          {buffer} = editor

      describe 'when the cursor is on a starting tag', ->
        it 'selects the text inside the starting/closing tag', ->
          editor.setCursorBufferPosition([4, 9])
          atom.commands.dispatch(editorElement, "bracket-matcher:select-inside-brackets")
          expect(editor.getSelectedBufferRange()).toEqual [[4, 13], [6, 8]]

      describe 'when the cursor is on an ending tag', ->
        it 'selects the text inside the starting/closing tag', ->
          editor.setCursorBufferPosition([15, 8])
          atom.commands.dispatch(editorElement, "bracket-matcher:select-inside-brackets")
          expect(editor.getSelectedBufferRange()).toEqual [[1, 8], [15, 2]]

      describe 'when the cursor is inside a tag', ->
        it 'selects the text inside the starting/closing tag', ->
          editor.setCursorBufferPosition([12, 8])
          atom.commands.dispatch(editorElement, "bracket-matcher:select-inside-brackets")
          expect(editor.getSelectedBufferRange()).toEqual [[11, 11], [13, 6]]

  describe "when bracket-matcher:remove-matching-brackets is triggered", ->
    describe "when the cursor is not in front of any pair", ->
      it "performs a regular backspace action", ->
        editor.setCursorBufferPosition([0, 1])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(0)).toEqual('ar quicksort = function () {')
        expect(editor.getCursorBufferPosition()).toEqual([0, 0])

    describe "when the cursor is at the beginning of a line", ->
      it "performs a regular backspace action", ->
        editor.setCursorBufferPosition([12, 0])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(11)).toEqual('  return sort(Array.apply(this, arguments));};')
        expect(editor.getCursorBufferPosition()).toEqual([11, 44])

    describe "when the cursor is on the left side of a starting pair", ->
      it "performs a regular backspace action", ->
        editor.setCursorBufferPosition([0, 28])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(0)).toEqual('var quicksort = function (){')
        expect(editor.getCursorBufferPosition()).toEqual([0, 27])

    describe "when the cursor is on the left side of an ending pair", ->
      it "performs a regular backspace action", ->
        editor.setCursorBufferPosition([7, 4])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(7)).toEqual('  }')
        expect(editor.getCursorBufferPosition()).toEqual([7, 2])

    describe "when the cursor is on the right side of a starting pair, the ending pair on another line", ->
      it "removes both pairs", ->
        editor.setCursorBufferPosition([0, 29])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(0)).toEqual('var quicksort = function () ')
        expect(editor.lineTextForBufferRow(12)).toEqual(';')
        expect(editor.getCursorBufferPosition()).toEqual([0, 28])

    describe "when the cursor is on the right side of an ending pair, the starting pair on another line", ->
      it "removes both pairs", ->
        editor.setCursorBufferPosition([7, 5])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(4)).toEqual('    while(items.length > 0) ')
        expect(editor.lineTextForBufferRow(7)).toEqual('    ')
        expect(editor.getCursorBufferPosition()).toEqual([7, 4])

    describe "when the cursor is on the right side of a starting pair, the ending pair on the same line", ->
      it "removes both pairs", ->
        editor.setCursorBufferPosition([11, 14])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(11)).toEqual('  return sortArray.apply(this, arguments);')
        expect(editor.getCursorBufferPosition()).toEqual([11, 13])

    describe "when the cursor is on the right side of an ending pair, the starting pair on the same line", ->
      it "removes both pairs", ->
        editor.setCursorBufferPosition([11, 43])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(11)).toEqual('  return sortArray.apply(this, arguments);')
        expect(editor.getCursorBufferPosition()).toEqual([11, 41])

    describe "when a starting pair is selected", ->
      it "removes both pairs", ->
        editor.setSelectedBufferRange([[11, 13], [11, 14]])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(11)).toEqual('  return sortArray.apply(this, arguments);')
        expect(editor.getCursorBufferPosition()).toEqual([11, 13])

    describe "when an ending pair is selected", ->
      it "removes both pairs", ->
        editor.setSelectedBufferRange([[11, 42], [11, 43]])
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-matching-brackets")
        expect(editor.lineTextForBufferRow(11)).toEqual('  return sortArray.apply(this, arguments);')
        expect(editor.getCursorBufferPosition()).toEqual([11, 41])

  describe "matching bracket deletion", ->
    beforeEach ->
      editor.buffer.setText("")

    describe "when selection is not a matching pair of brackets", ->
      it "does not change the text", ->
        editor.insertText("\"woah(")
        editor.selectAll()
        atom.commands.dispatch(editorElement, "bracket-matcher:remove-brackets-from-selection")
        expect(editor.buffer.getText()).toBe "\"woah("

    describe "when selecting a matching pair of brackets", ->
      describe "on the same line", ->
        beforeEach ->
          editor.buffer.setText("it \"does something\", :meta => true")
          editor.setSelectedBufferRange([[0, 3], [0, 19]])
          atom.commands.dispatch(editorElement, "bracket-matcher:remove-brackets-from-selection")

        it "removes the brackets", ->
          expect(editor.buffer.getText()).toBe "it does something, :meta => true"

        it "selects the newly unbracketed text", ->
          expect(editor.getSelectedText()).toBe "does something"

      describe "on separate lines", ->
        beforeEach ->
          editor.buffer.setText("it (\"does something\" do\nend)")
          editor.setSelectedBufferRange([[0, 3], [1, 4]])
          atom.commands.dispatch(editorElement, "bracket-matcher:remove-brackets-from-selection")

        it "removes the brackets", ->
          expect(editor.buffer.getText()).toBe "it \"does something\" do\nend"

        it "selects the newly unbracketed text", ->
          expect(editor.getSelectedText()).toBe "\"does something\" do\nend"

  describe "matching bracket insertion", ->
    beforeEach ->
      editor.buffer.setText("")
      atom.config.set('editor.autoIndent', true)

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

    describe "when autocompleteBrackets configuration is disabled globally", ->
      it "does not insert a matching bracket", ->
        atom.config.set 'bracket-matcher.autocompleteBrackets', false
        editor.buffer.setText("}")
        editor.setCursorBufferPosition([0, 0])
        editor.insertText '{'
        expect(buffer.lineForRow(0)).toBe "{}"
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    describe "when autocompleteBrackets configuration is disabled in scope", ->
      it "does not insert a matching bracket", ->
        atom.config.set 'bracket-matcher.autocompleteBrackets', true
        atom.config.set 'bracket-matcher.autocompleteBrackets', false, scopeSelector: '.source.js'
        editor.buffer.setText("}")
        editor.setCursorBufferPosition([0, 0])
        editor.insertText '{'
        expect(buffer.lineForRow(0)).toBe "{}"
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    describe "when autocompleteCharacters configuration is set globally", ->
      it "inserts a matching angle bracket", ->
        atom.config.set 'bracket-matcher.autocompleteCharacters', ['<>']
        editor.setCursorBufferPosition([0, 0])
        editor.insertText '<'
        expect(buffer.lineForRow(0)).toBe "<>"
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    describe "when autocompleteCharacters configuration is set in scope", ->
      it "inserts a matching angle bracket", ->
        atom.config.set 'bracket-matcher.autocompleteCharacters', ['<>'], scopeSelector: '.source.js'
        editor.setCursorBufferPosition([0, 0])
        editor.insertText '<'
        expect(buffer.lineForRow(0)).toBe "<>"
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

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
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    describe "when the cursor is at the end of the line", ->
      it "inserts a closing bracket after an opening bracket is inserted", ->
        editor.buffer.setText("")
        editor.insertText '{'
        expect(buffer.lineForRow(0)).toBe "{}"
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

        editor.buffer.setText("")
        editor.insertText '('
        expect(buffer.lineForRow(0)).toBe "()"
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

        editor.buffer.setText("")
        editor.insertText '['
        expect(buffer.lineForRow(0)).toBe "[]"
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

        editor.buffer.setText("")
        editor.insertText '"'
        expect(buffer.lineForRow(0)).toBe '""'
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

        editor.buffer.setText("")
        editor.insertText "'"
        expect(buffer.lineForRow(0)).toBe "''"
        expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    describe "when the cursor follows an escape character", ->
      it "doesn't insert a quote to match the escaped quote and overwrites the end quote", ->
        editor.buffer.setText('')
        editor.insertText '"'
        editor.insertText '\\'
        editor.insertText '"'
        editor.insertText '"'
        expect(buffer.lineForRow(0)).toBe '"\\""'

    describe "when the cursor follows an escape sequence", ->
      it "inserts a matching quote and overwrites it", ->
        editor.buffer.setText('')
        editor.insertText '"'
        editor.insertText '\\'
        editor.insertText '\\'
        editor.insertText '"'
        expect(buffer.lineForRow(0)).toBe '"\\\\"'

    describe "when the cursor follows a combination of escape characters", ->
      it "correctly decides whether to match the quote or not", ->
        editor.buffer.setText('')
        editor.insertText '"'
        editor.insertText '\\'
        editor.insertText '\\'
        editor.insertText '\\'
        editor.insertText '"'
        expect(buffer.lineForRow(0)).toBe '"\\\\\\""'

        editor.buffer.setText('')
        editor.insertText '"'
        editor.insertText '\\'
        editor.insertText '\\'
        editor.insertText '\\'
        editor.insertText '\\'
        editor.insertText '"'
        expect(buffer.lineForRow(0)).toBe '"\\\\\\\\"'

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
        editor.moveToBottom()
        editor.selectToTop()
        editor.selectAll()
        editor.insertText '('
        expect(buffer.getText()).toBe '(text)'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 5]]
        expect(editor.getLastSelection().isReversed()).toBeTruthy()

      describe "when the bracket-matcher.wrapSelectionsInBrackets is falsy globally", ->
        it "does not wrap the selection in brackets", ->
          atom.config.set('bracket-matcher.wrapSelectionsInBrackets', false)
          editor.setText 'text'
          editor.moveToBottom()
          editor.selectToTop()
          editor.selectAll()
          editor.insertText '('
          expect(buffer.getText()).toBe '('
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

      describe "when the bracket-matcher.wrapSelectionsInBrackets is falsy in scope", ->
        it "does not wrap the selection in brackets", ->
          atom.config.set('bracket-matcher.wrapSelectionsInBrackets', true)
          atom.config.set('bracket-matcher.wrapSelectionsInBrackets', false, scopeSelector: '.source.js')
          editor.setText 'text'
          editor.moveToBottom()
          editor.selectToTop()
          editor.selectAll()
          editor.insertText '('
          expect(buffer.getText()).toBe '('
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

    describe "when there is text selected on multiple lines", ->
      it "wraps the selection with brackets", ->
        editor.insertText 'text\nabcd'
        editor.moveToBottom()
        editor.selectToTop()
        editor.selectAll()
        editor.insertText '('
        expect('(text\nabcd)').toBe buffer.getText()
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [1, 4]]
        expect(editor.getLastSelection().isReversed()).toBeTruthy()

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
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe 'abc"'

          editor.buffer.setText("abc")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "abc'"

      describe "when an escape character is before the cursor", ->
        it "does not automatically insert the closing quote", ->
          editor.buffer.setText("\\")
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe '\\"'

          editor.buffer.setText("\\")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "\\'"

          editor.buffer.setText('"\\"')
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe '"\\""'

          editor.buffer.setText("\"\\'")
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe "\"\\'\""

          editor.buffer.setText("'\\\"")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "'\\\"'"

          editor.buffer.setText("'\\'")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "'\\''"

      describe "when an escape sequence is before the cursor", ->
        it "does not create a new quote pair", ->
          editor.buffer.setText('"\\\\"')
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe '"\\\\""'

          editor.buffer.setText("'\\\\'")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "'\\\\''"

      describe "when a combination of escape characters is before the cursor", ->
        it "correctly determines whether it is an escape character or sequence", ->
          editor.buffer.setText("\\\\\\")
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe '\\\\\\"'

          editor.buffer.setText("\\\\\\")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "\\\\\\'"

          editor.buffer.setText('"\\\\\\"')
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe '"\\\\\\""'

          editor.buffer.setText("\"\\\\\\'")
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe "\"\\\\\\'\""

          editor.buffer.setText("'\\\\\\\"")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "'\\\\\\\"'"

          editor.buffer.setText("'\\\\\\'")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "'\\\\\\''"

      describe "when a quote is before the cursor", ->
        it "does not automatically insert the closing quote", ->
          editor.buffer.setText("''")
          editor.moveToEndOfLine()
          editor.insertText "'"
          expect(editor.getText()).toBe "'''"

          editor.buffer.setText('""')
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe '"""'

          editor.buffer.setText('``')
          editor.moveToEndOfLine()
          editor.insertText '`'
          expect(editor.getText()).toBe '```'

          editor.buffer.setText("''")
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe "''\"\""

      describe "when a non word character is before the cursor", ->
        it "automatically inserts the closing quote", ->
          editor.buffer.setText("ab@")
          editor.moveToEndOfLine()
          editor.insertText '"'
          expect(editor.getText()).toBe 'ab@""'
          expect(editor.getCursorBufferPosition()).toEqual [0, 4]

      describe "when the cursor is on an empty line", ->
        it "automatically inserts the closing quote", ->
          editor.buffer.setText("")
          editor.insertText '"'
          expect(editor.getText()).toBe '""'
          expect(editor.getCursorBufferPosition()).toEqual [0, 1]

      describe "when the select option to Editor::insertText is true", ->
        it "does not automatically insert the closing quote", ->
          editor.buffer.setText("")
          editor.insertText '"', select: true
          expect(editor.getText()).toBe '"'
          expect(editor.getCursorBufferPosition()).toEqual [0, 1]

      describe "when the undo option to Editor::insertText is 'skip'", ->
        it "does not automatically insert the closing quote", ->
          editor.buffer.setText("")
          editor.insertText '"', undo: 'skip'
          expect(editor.getText()).toBe '"'
          expect(editor.getCursorBufferPosition()).toEqual [0, 1]

    describe "when return is pressed inside a matching pair", ->
      it "puts the cursor on the indented empty line", ->
        editor.insertText 'void main() '
        editor.insertText '{'
        expect(editor.getText()).toBe 'void main() {}'
        editor.insertNewline()
        expect(editor.getCursorBufferPosition()).toEqual [1, 2]
        expect(buffer.lineForRow(1)).toBe '  '
        expect(buffer.lineForRow(2)).toBe '}'

        editor.setText '  void main() '
        editor.insertText '{'
        expect(editor.getText()).toBe '  void main() {}'
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
          expect(editor.getText()).toBe 'void main() {}'

      describe 'when editor.autoIndent is disabled', ->
        beforeEach ->
          atom.config.set('editor.autoIndent', false)

        it 'does not auto-indent the empty line and closing bracket', ->
          editor.insertText '  void main() '
          editor.insertText '{'
          expect(editor.getText()).toBe '  void main() {}'
          editor.insertNewline()
          expect(editor.getCursorBufferPosition()).toEqual [1, 0]
          expect(buffer.lineForRow(1)).toBe ''
          expect(buffer.lineForRow(2)).toBe '}'

    describe "when in language specific scope", ->
      describe "string interpolation", ->
        beforeEach ->
          waitsForPromise ->
            atom.packages.activatePackage("language-ruby")

          runs ->
            buffer.setPath('foo.rb')

        it "should insert curly braces inside doubly quoted string", ->
          editor.insertText "foo = "
          editor.insertText '"'
          editor.insertText "#"
          expect(editor.getText()).toBe 'foo = "#{}"'
          editor.undo()
          expect(editor.getText()).toBe 'foo = ""'

        it "should not insert curly braces inside singly quoted string", ->
          editor.insertText "foo = "
          editor.insertText "'"
          editor.insertText "#"
          expect(editor.getText()).toBe "foo = '#'"

        it "should insert curly braces inside % string", ->
          editor.insertText "foo = %"
          editor.insertText '('
          editor.insertText "#"
          expect(editor.getText()).toBe 'foo = %(#{})'

        it "should not insert curly braces inside non-interpolated % string", ->
          editor.insertText "foo = %q"
          editor.insertText "("
          editor.insertText "#"
          expect(editor.getText()).toBe "foo = %q(#)"

        it "should insert curly braces inside interpolated symbol", ->
          editor.insertText "foo = :"
          editor.insertText '"'
          editor.insertText "#"
          expect(editor.getText()).toBe 'foo = :"#{}"'

        it 'wraps the selection in the interpolation brackets when the selection is a single line', ->
          editor.setText 'foo = "a bar"'
          editor.setSelectedBufferRange([[0, 9], [0, 12]])

          editor.insertText '#'
          # coffeelint: disable=no_interpolation_in_single_quotes
          expect(editor.getText()).toBe 'foo = "a #{bar}"'
          # coffeelint: enable=no_interpolation_in_single_quotes
          expect(editor.getSelectedBufferRange()).toEqual [[0, 11], [0, 14]]

          editor.undo()
          expect(editor.getText()).toBe 'foo = "a bar"'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 9], [0, 12]]

        it 'does not wrap the selection in the interpolation brackets when the selection is mutli-line', ->
          editor.setText 'foo = "a bar"\nfoo = "a bar"'
          editor.setSelectedBufferRange([[0, 9], [1, 12]])

          editor.insertText '#'
          expect(editor.getText()).toBe 'foo = "a #{}"'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 11], [0, 11]]

          editor.undo()
          expect(editor.getText()).toBe 'foo = "a bar"\nfoo = "a bar"'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 9], [1, 12]]

  describe "matching bracket deletion", ->
    it "deletes the end bracket when it directly precedes a begin bracket that is being backspaced", ->
      buffer.setText("")
      editor.setCursorBufferPosition([0, 0])
      editor.insertText '{'
      expect(buffer.lineForRow(0)).toBe "{}"
      editor.backspace()
      expect(buffer.lineForRow(0)).toBe ""

    it "does not delete end bracket even if it directly precedes a begin bracket if autocomplete is turned off globally", ->
      atom.config.set 'bracket-matcher.autocompleteBrackets', false
      buffer.setText("")
      editor.setCursorBufferPosition([0, 0])
      editor.insertText "{"
      expect(buffer.lineForRow(0)).toBe "{"
      editor.insertText "}"
      expect(buffer.lineForRow(0)).toBe "{}"
      editor.setCursorBufferPosition([0, 1])
      editor.backspace()
      expect(buffer.lineForRow(0)).toBe "}"

    it "does not delete end bracket even if it directly precedes a begin bracket if autocomplete is turned off in scope", ->
      atom.config.set 'bracket-matcher.autocompleteBrackets', true
      atom.config.set 'bracket-matcher.autocompleteBrackets', false, scopeSelector: '.source.js'
      buffer.setText("")
      editor.setCursorBufferPosition([0, 0])
      editor.insertText "{"
      expect(buffer.lineForRow(0)).toBe "{"
      editor.insertText "}"
      expect(buffer.lineForRow(0)).toBe "{}"
      editor.setCursorBufferPosition([0, 1])
      editor.backspace()
      expect(buffer.lineForRow(0)).toBe "}"

  describe 'bracket-matcher:close-tag', ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.html')

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editorElement = atom.views.getView(editor)
        {buffer} = editor

    it 'closes the first unclosed tag', ->
      editor.setCursorBufferPosition([5, 14])
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

      expect(editor.getCursorBufferPosition()).toEqual [5, 18]
      expect(editor.getTextInRange([[5, 14], [5, 18]])).toEqual '</a>'

    it 'closes the following unclosed tags if called repeatedly', ->
      editor.setCursorBufferPosition([5, 14])
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

      expect(editor.getCursorBufferPosition()).toEqual [5, 22]
      expect(editor.getTextInRange([[5, 18], [5, 22]])).toEqual '</p>'

    it 'does not close any tag if no unclosed tag can be found at the insertion point', ->
      editor.setCursorBufferPosition([5, 14])
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

      #closing all currently open tags
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')
      editor.setCursorBufferPosition([13, 11])
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')
      editor.setCursorBufferPosition([15, 0])
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

      # positioning on an already closed tag
      editor.setCursorBufferPosition([11, 9])
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')
      expect(editor.getCursorBufferPosition()).toEqual [11, 9]

    it 'does not get confused in case of nested identical tags -- tag not closing', ->
      editor.setCursorBufferPosition([13, 11])
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

      expect(editor.getCursorBufferPosition()).toEqual [13, 16]

    it 'does not get confused in case of nested identical tags -- tag closing', ->
      editor.setCursorBufferPosition([13, 11])
      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

      expect(editor.getCursorBufferPosition()).toEqual [13, 16]
      expect(editor.getTextInRange([[13, 10], [13, 16]])).toEqual '</div>'

      atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

      expect(editor.getCursorBufferPosition()).toEqual [13, 16]

    it 'does not get confused in case of nested self closing tags', ->
      waitsForPromise ->
        atom.workspace.open('sample.xml')

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editorElement = atom.views.getView(editor)

        editor.setText """
          <bar name="test">
            <foo value="15"/>

        """

        editor.setCursorBufferPosition([2, 0])
        atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

        expect(editor.getCursorBufferPosition().row).toEqual 2
        expect(editor.getCursorBufferPosition().column).toEqual 6
        expect(editor.getTextInRange([[2, 0], [2, 6]])).toEqual '</bar>'


    it 'does not get confused in case of self closing tags after the cursor', ->
      waitsForPromise ->
        atom.workspace.open('sample.xml')

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editorElement = atom.views.getView(editor)

        editor.setText """
          <bar>

            <bar>
              <bar value="foo"/>
            </bar>
          </bar>
        """

        editor.setCursorBufferPosition([1, 0])
        atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

        expect(editor.getCursorBufferPosition().row).toEqual 1
        expect(editor.getCursorBufferPosition().column).toEqual 0
        expect(editor.getTextInRange([[1, 0], [1, Infinity]])).toEqual ''

    it 'does not get confused in case of nested self closing tags with `>` in their attributes', ->
      waitsForPromise ->
        atom.workspace.open('sample.xml')

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editorElement = atom.views.getView(editor)

        editor.setText """
          <bar name="test">
            <foo bar="test>1" baz="<>" value="15"/>

        """

        editor.setCursorBufferPosition([2, 0])
        atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

        expect(editor.getCursorBufferPosition().row).toEqual 2
        expect(editor.getCursorBufferPosition().column).toEqual 6
        expect(editor.getTextInRange([[2, 0], [2, 6]])).toEqual '</bar>'

        editor.setText """
          <foo value="/>">

        """

        editor.setCursorBufferPosition([1, 0])
        atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

        expect(editor.getCursorBufferPosition().row).toEqual 1
        expect(editor.getCursorBufferPosition().column).toEqual 6
        expect(editor.getTextInRange([[1, 0], [1, 6]])).toEqual '</foo>'

    it 'does not get confused in case of self closing tags with `>` in their attributes after the cursor', ->
      waitsForPromise ->
        atom.workspace.open('sample.xml')

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editorElement = atom.views.getView(editor)

        editor.setText """
          <bar>

            <bar>
              <bar value="b>z"/>
            </bar>
          </bar>
        """

        editor.setCursorBufferPosition([1, 0])
        atom.commands.dispatch(editorElement, 'bracket-matcher:close-tag')

        expect(editor.getCursorBufferPosition().row).toEqual 1
        expect(editor.getCursorBufferPosition().column).toEqual 0
        expect(editor.getTextInRange([[1, 0], [1, Infinity]])).toEqual ''
