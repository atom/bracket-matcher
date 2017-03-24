MatchManager = require './match-manager'
BracketMatcherView = require './bracket-matcher-view'
BracketMatcher = require './bracket-matcher'

module.exports =
  activate: ->
    atom.workspace.observeTextEditors (editor) ->
      editorElement = atom.views.getView(editor)
      matchManager = new MatchManager(editor, editorElement)
      new BracketMatcherView(editor, editorElement, matchManager)
      new BracketMatcher(editor, editorElement, matchManager)
