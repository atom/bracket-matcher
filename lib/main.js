const CompositeDisposable = require('atom')

const MatchManager = require('./match-manager')
const BracketMatcherView = require('./bracket-matcher-view')
const BracketMatcher = require('./bracket-matcher')

module.exports = {
  activate () {
    this.watchedEditors = new WeakMap()

    atom.workspace.observeTextEditors(editor => {
      if (this.watchedEditors.has(editor)) return

      const editorElement = atom.views.getView(editor)
      const matchManager = new MatchManager(editor)
      const bracketMatcherView = new BracketMatcherView(editor, editorElement, matchManager)
      const bracketMatcher = new BracketMatcher(editor, editorElement, matchManager)
      const subscriptions = new CompositeDisposable([matchManager, bracketMatcherView, bracketMatcher])
      this.watchedEditors.add(editor, subscriptions)
      editor.onDidDestroy(() => {
        this.watchedEditors.get(editor).dispose()
        this.watchedEditors.delete(editor)
      })
    })
  },

  deactivate () {
    for (const editor of atom.workspace.getTextEditors()) {
      this.watchedEditors.get(editor).dispose()
      this.watchedEditors.delete(editor)
    }
  }
}
