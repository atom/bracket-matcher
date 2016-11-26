BracketMatcherView = null
BracketMatcher = null

module.exports =
  activate: ->
    @editorsSubscription = atom.workspace.observeTextEditors (editor) ->
      editorElement = atom.views.getView(editor)

      BracketMatcherView ?= require './bracket-matcher-view'
      new BracketMatcherView(editor, editorElement)

      BracketMatcher ?= require './bracket-matcher'
      new BracketMatcher(editor, editorElement)

  deactivate: ->
    @editorsSubscription.dispose()
