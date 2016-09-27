MatchManager = null
BracketMatcherView = null
BracketMatcher = null

module.exports =
  activate: ->
    atom.workspace.observeTextEditors (editor) ->
      editorElement = atom.views.getView(editor)

      MatchManager ?= require './match-manager'
      matchManager = new MatchManager(editor, editorElement)

      BracketMatcherView ?= require './bracket-matcher-view'
      new BracketMatcherView(editor, editorElement, matchManager)

      BracketMatcher ?= require './bracket-matcher'
      new BracketMatcher(editor, editorElement, matchManager)
