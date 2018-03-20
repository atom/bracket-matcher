MatchManager = require './match-manager'
BracketMatcherView = require './bracket-matcher-view'
BracketMatcher = require './bracket-matcher'

module.exports =
  activate: ->
    watchedEditors = new WeakSet()

    atom.workspace.observeTextEditors (editor) ->
      return if watchedEditors.has(editor)

      editorElement = atom.views.getView(editor)
      matchManager = new MatchManager(editor, editorElement)
      new BracketMatcherView(editor, editorElement, matchManager)
      new BracketMatcher(editor, editorElement, matchManager)
      watchedEditors.add(editor)
      editor.onDidDestroy -> watchedEditors.delete(editor)
