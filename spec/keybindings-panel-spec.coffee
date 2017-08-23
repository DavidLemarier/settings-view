path = require 'path'
KeybindingsPanel = require '../lib/keybindings-panel'

describe "KeybindingsPanel", ->
  [keyBindings, panel] = []

  beforeEach ->
    expect(soldat.keymaps).toBeDefined()
    keyBindings = [
      {
        source: "#{soldat.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-a'
        command: 'core:select-all'
        selector: '.editor, .platform-test'
      }
      {
        source: "#{soldat.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-u'
        command: 'core:undo'
        selector: ".platform-test"
      }
      {
        source: "#{soldat.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-u'
        command: 'core:undo'
        selector: ".platform-a, .platform-b"
      }
      {
        source: "#{soldat.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'shift-\\ \\'
        command: 'core:undo'
        selector: '.editor'
      }
    ]
    spyOn(soldat.keymaps, 'getKeyBindings').andReturn(keyBindings)
    panel = new KeybindingsPanel

  it "loads and displays core key bindings", ->
    expect(panel.refs.keybindingRows.children.length).toBe 2

    row = panel.refs.keybindingRows.children[0]
    expect(row.querySelector('.keystroke').textContent).toBe 'ctrl-a'
    expect(row.querySelector('.command').textContent).toBe 'core:select-all'
    expect(row.querySelector('.source').textContent).toBe 'Core'
    expect(row.querySelector('.selector').textContent).toBe '.editor, .platform-test'

  describe "when a keybinding is copied", ->
    describe "when the keybinding file ends in .cson", ->
      it "writes a CSON snippet to the clipboard", ->
        spyOn(soldat.keymaps, 'getUserKeymapPath').andReturn 'keymap.cson'
        panel.element.querySelector('.copy-icon').click()
        expect(soldat.clipboard.read()).toBe """
          '.editor, .platform-test':
            'ctrl-a': 'core:select-all'
        """

    describe "when the keybinding file ends in .json", ->
      it "writes a JSON snippet to the clipboard", ->
        spyOn(soldat.keymaps, 'getUserKeymapPath').andReturn 'keymap.json'
        panel.element.querySelector('.copy-icon').click()
        expect(soldat.clipboard.read()).toBe """
          ".editor, .platform-test": {
            "ctrl-a": "core:select-all"
          }
        """

    describe "when the keybinding contains backslashes", ->
      it "escapes the backslashes before copying", ->
        spyOn(soldat.keymaps, 'getUserKeymapPath').andReturn 'keymap.cson'
        panel.element.querySelectorAll('.copy-icon')[1].click()
        expect(soldat.clipboard.read()).toBe """
          '.editor':
            'shift-\\\\ \\\\': 'core:undo'
        """

  describe "when the key bindings change", ->
    it "reloads the key bindings", ->
      keyBindings.push
        source: soldat.keymaps.getUserKeymapPath(), keystrokes: 'ctrl-b', command: 'core:undo', selector: '.editor'
      soldat.keymaps.emitter.emit 'did-reload-keymap'

      waitsFor "the new keybinding to show up in the keybinding panel", ->
        panel.refs.keybindingRows.children.length is 3

      runs ->
        row = panel.refs.keybindingRows.children[1]
        expect(row.querySelector('.keystroke').textContent).toBe 'ctrl-b'
        expect(row.querySelector('.command').textContent).toBe 'core:undo'
        expect(row.querySelector('.source').textContent).toBe 'User'
        expect(row.querySelector('.selector').textContent).toBe '.editor'

  describe "when searching key bindings", ->
    it "find case-insensitive results", ->
      keyBindings.push
        source: "#{soldat.getLoadSettings().resourcePath}#{path.sep}keymaps", keystrokes: 'F11', command: 'window:toggle-full-screen', selector: 'body'
      soldat.keymaps.emitter.emit 'did-reload-keymap'

      panel.filterKeyBindings keyBindings, 'f11'

      expect(panel.refs.keybindingRows.children.length).toBe 1

      row = panel.refs.keybindingRows.children[0]
      expect(row.querySelector('.keystroke').textContent).toBe 'F11'
      expect(row.querySelector('.command').textContent).toBe 'window:toggle-full-screen'
      expect(row.querySelector('.source').textContent).toBe 'Core'
      expect(row.querySelector('.selector').textContent).toBe 'body'

    it "perform a fuzzy match for each keyword", ->
      panel.filterKeyBindings keyBindings, 'core ctrl-a'

      expect(panel.refs.keybindingRows.children.length).toBe 1

      row = panel.refs.keybindingRows.children[0]
      expect(row.querySelector('.keystroke').textContent).toBe 'ctrl-a'
      expect(row.querySelector('.command').textContent).toBe 'core:select-all'
      expect(row.querySelector('.source').textContent).toBe 'Core'
      expect(row.querySelector('.selector').textContent).toBe '.editor, .platform-test'
