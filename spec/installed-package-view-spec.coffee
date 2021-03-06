path = require 'path'
PackageDetailView = require '../lib/package-detail-view'
PackageManager = require '../lib/package-manager'
SettingsView = require '../lib/settings-view'
PackageKeymapView = require '../lib/package-keymap-view'
_ = require 'underscore-plus'
SnippetsProvider =
  getSnippets: -> soldat.config.scopedSettingsStore.propertySets

describe "InstalledPackageView", ->
  beforeEach ->
    spyOn(PackageManager.prototype, 'loadCompatiblePackageVersion').andCallFake ->

  it "displays the grammars registered by the package", ->
    settingsPanels = null

    waitsForPromise ->
      soldat.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = soldat.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), SnippetsProvider)
      settingsPanels = view.element.querySelectorAll('.package-grammars .settings-panel')

      waitsFor ->
        children = Array.from(settingsPanels).map((s) -> s.children.length)
        childrenCount = children.reduce(((a, b) -> a + b), 0)
        childrenCount is 2

      expect(settingsPanels[0].querySelector('.grammar-scope').textContent).toBe 'Scope: source.a'
      expect(settingsPanels[0].querySelector('.grammar-filetypes').textContent).toBe 'File Types: .a, .aa, a'

      expect(settingsPanels[1].querySelector('.grammar-scope').textContent).toBe 'Scope: source.b'
      expect(settingsPanels[1].querySelector('.grammar-filetypes').textContent).toBe 'File Types: '

      expect(settingsPanels[2]).toBeUndefined()

  it "displays the snippets registered by the package", ->
    snippetsTable = null
    snippetsModule = null

    waitsForPromise ->
      soldat.packages.activatePackage('snippets').then (p) ->
        snippetsModule = p.mainModule
        return unless snippetsModule.provideSnippets().getUnparsedSnippets?

        SnippetsProvider =
          getSnippets: -> snippetsModule.provideSnippets().getUnparsedSnippets()

    waitsForPromise ->
      soldat.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    waitsFor 'snippets to load', (done) ->
      snippetsModule.onDidLoadSnippets(done)

    runs ->
      pack = soldat.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), SnippetsProvider)
      snippetsTable = view.element.querySelector('.package-snippets-table tbody')

    waitsFor 'snippets table children to contain 2 items', ->
      snippetsTable.children.length >= 2

    runs ->
      expect(snippetsTable.querySelector('tr:nth-child(1) td:nth-child(1)').textContent).toBe 'b'
      expect(snippetsTable.querySelector('tr:nth-child(1) td:nth-child(2)').textContent).toBe 'BAR'
      expect(snippetsTable.querySelector('tr:nth-child(1) td:nth-child(3)').textContent).toBe 'bar?'

      expect(snippetsTable.querySelector('tr:nth-child(2) td:nth-child(1)').textContent).toBe 'f'
      expect(snippetsTable.querySelector('tr:nth-child(2) td:nth-child(2)').textContent).toBe 'FOO'
      expect(snippetsTable.querySelector('tr:nth-child(2) td:nth-child(3)').textContent).toBe 'foo!'

  it "does not display keybindings from other platforms", ->
    keybindingsTable = null

    waitsForPromise ->
      soldat.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = soldat.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), SnippetsProvider)
      keybindingsTable = view.element.querySelector('.package-keymap-table tbody')
      expect(keybindingsTable.children.length).toBe 1

  describe "when the keybindings toggle is clicked", ->
    it "sets the packagesWithKeymapsDisabled config to include the package name", ->
      waitsForPromise ->
        soldat.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

      runs ->
        pack = soldat.packages.getActivePackage('language-test')
        card = new PackageKeymapView(pack)
        jasmine.attachToDOM(card.element)

        card.refs.keybindingToggle.click()
        expect(card.refs.keybindingToggle.checked).toBe false
        expect(_.include(soldat.config.get('core.packagesWithKeymapsDisabled') ? [], 'language-test')).toBe true

        if soldat.keymaps.build?
          keybindingRows = card.element.querySelectorAll('.package-keymap-table tbody.text-subtle tr')
          expect(keybindingRows.length).toBe 1

        card.refs.keybindingToggle.click()
        expect(card.refs.keybindingToggle.checked).toBe true
        expect(_.include(soldat.config.get('core.packagesWithKeymapsDisabled') ? [], 'language-test')).toBe false

        if soldat.keymaps.build?
          keybindingRows = card.element.querySelectorAll('.package-keymap-table tbody tr')
          expect(keybindingRows.length).toBe 1

  describe "when a keybinding is copied", ->
    [pack, card] = []

    beforeEach ->
      waitsForPromise ->
        soldat.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

      runs ->
        pack = soldat.packages.getActivePackage('language-test')
        card = new PackageKeymapView(pack)

    describe "when the keybinding file ends in .cson", ->
      it "writes a CSON snippet to the clipboard", ->
        spyOn(soldat.keymaps, 'getUserKeymapPath').andReturn 'keymap.cson'
        card.element.querySelector('.copy-icon').click()
        expect(soldat.clipboard.read()).toBe """
          'test':
            'cmd-g': 'language-test:run'
        """

    describe "when the keybinding file ends in .json", ->
      it "writes a JSON snippet to the clipboard", ->
        spyOn(soldat.keymaps, 'getUserKeymapPath').andReturn 'keymap.json'
        card.element.querySelector('.copy-icon').click()
        expect(soldat.clipboard.read()).toBe """
          "test": {
            "cmd-g": "language-test:run"
          }
        """

  describe "when the package is active", ->
    it "displays the correct enablement state", ->
      packageCard = null

      waitsForPromise ->
        soldat.packages.activatePackage('status-bar')

      runs ->
        expect(soldat.packages.isPackageActive('status-bar')).toBe(true)
        pack = soldat.packages.getLoadedPackage('status-bar')
        view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), SnippetsProvider)
        packageCard = view.element.querySelector('.package-card')

      runs ->
        # Trigger observeDisabledPackages() here
        # because it is not default in specs
        soldat.packages.observeDisabledPackages()
        soldat.packages.disablePackage('status-bar')
        expect(soldat.packages.isPackageDisabled('status-bar')).toBe(true)
        expect(packageCard.classList.contains('disabled')).toBe(true)

  describe "when the package is not active", ->
    it "displays the correct enablement state", ->
      soldat.packages.loadPackage('status-bar')
      expect(soldat.packages.isPackageActive('status-bar')).toBe(false)
      pack = soldat.packages.getLoadedPackage('status-bar')
      view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), SnippetsProvider)
      packageCard = view.element.querySelector('.package-card')

      # Trigger observeDisabledPackages() here
      # because it is not default in specs
      soldat.packages.observeDisabledPackages()
      soldat.packages.disablePackage('status-bar')
      expect(soldat.packages.isPackageDisabled('status-bar')).toBe(true)
      expect(packageCard.classList.contains('disabled')).toBe(true)

    it "still loads the config schema for the package", ->
      soldat.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))

      waitsFor ->
        soldat.packages.isPackageLoaded('package-with-config') is true

      runs ->
        expect(soldat.config.get('package-with-config.setting')).toBe undefined

        pack = soldat.packages.getLoadedPackage('package-with-config')
        new PackageDetailView(pack, new SettingsView(), new PackageManager(), SnippetsProvider)

        expect(soldat.config.get('package-with-config.setting')).toBe 'something'

  describe "when the package was not installed from atom.io", ->
    normalizePackageDataReadmeError = 'ERROR: No README data found!'

    it "still displays the Readme", ->
      soldat.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-readme'))

      waitsFor ->
        soldat.packages.isPackageLoaded('package-with-readme') is true

      runs ->
        pack = soldat.packages.getLoadedPackage('package-with-readme')
        expect(pack.metadata.readme).toBe normalizePackageDataReadmeError

        view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), SnippetsProvider)
        expect(view.refs.sections.querySelector('.package-readme').textContent).not.toBe normalizePackageDataReadmeError
        expect(view.refs.sections.querySelector('.package-readme').textContent.trim()).toContain 'I am a Readme!'
