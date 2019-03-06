const {CompositeDisposable} = require('atom')

const MatchManager = require('./match-manager')
const BracketMatcherView = require('./bracket-matcher-view')
const BracketMatcher = require('./bracket-matcher')

module.exports = {
  activate () {
    this.watchedEditors = new WeakMap()
    this.subscriptions = new CompositeDisposable()

    this.subscriptions.add(atom.workspace.observeTextEditors(editor => {
      const editorElement = atom.views.getView(editor)

      const matchManager = new MatchManager(editor)
      const bracketMatcherView = new BracketMatcherView(editor, editorElement, matchManager)
      const bracketMatcher = new BracketMatcher(editor, editorElement, matchManager)

      const subscriptions = new CompositeDisposable(matchManager, bracketMatcherView, bracketMatcher)
      this.watchedEditors.set(editor, subscriptions)

      this.subscriptions.add(editor.onDidDestroy(() => {
        this.watchedEditors.get(editor).dispose()
        this.watchedEditors.delete(editor)
      }))
    }))
  },

  deactivate () {
    this.subscriptions.dispose()
    for (const editor of atom.workspace.getTextEditors()) {
      this.watchedEditors.get(editor).dispose()
      this.watchedEditors.delete(editor)
    }
  }
}
