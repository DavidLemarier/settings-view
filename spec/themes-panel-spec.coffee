path = require 'path'
fs = require 'fs'

CSON = require 'season'

PackageManager = require '../lib/package-manager'
ThemesPanel = require '../lib/themes-panel'

describe "ThemesPanel", ->
  [panel, packageManager, reloadedHandler] = []
  settingsView = null

  beforeEach ->
    soldat.packages.loadPackage('soldat-light-ui')
    soldat.packages.loadPackage('soldat-dark-ui')
    soldat.packages.loadPackage('soldat-light-syntax')
    soldat.packages.loadPackage('soldat-dark-syntax')
    soldat.packages.packageDirPaths.push(path.join(__dirname, 'fixtures'))
    soldat.config.set('core.themes', ['soldat-dark-ui', 'soldat-dark-syntax'])
    reloadedHandler = jasmine.createSpy('reloadedHandler')
    soldat.themes.onDidChangeActiveThemes(reloadedHandler)
    soldat.themes.activatePackages()

    waitsFor "themes to be reloaded", ->
      reloadedHandler.callCount is 1

    runs ->
      packageManager = new PackageManager
      themeMetadata = CSON.readFileSync(path.join(__dirname, 'fixtures', 'a-theme', 'package.json'))
      spyOn(packageManager, 'getFeatured').andCallFake (callback) ->
        Promise.resolve([themeMetadata])
      panel = new ThemesPanel(settingsView, packageManager)

      # Make updates synchronous
      spyOn(panel, 'scheduleUpdateThemeConfig').andCallFake -> @updateThemeConfig()

  afterEach ->
    soldat.packages.unloadPackage('a-theme') if soldat.packages.isPackageLoaded('a-theme')
    soldat.themes.deactivateThemes()

  it "selects the active syntax and UI themes", ->
    expect(panel.refs.uiMenu.value).toBe 'soldat-dark-ui'
    expect(panel.refs.syntaxMenu.value).toBe 'soldat-dark-syntax'

  describe "when a UI theme is selected", ->
    it "updates the 'core.themes' config key with the selected UI theme", ->
      for child in panel.refs.uiMenu.children
        child.selected = child.value is 'soldat-light-ui'
        child.dispatchEvent(new Event('change', {bubbles: true}))
      expect(soldat.config.get('core.themes')).toEqual ['soldat-light-ui', 'soldat-dark-syntax']

  describe "when a syntax theme is selected", ->
    it "updates the 'core.themes' config key with the selected syntax theme", ->
      for child in panel.refs.syntaxMenu.children
        child.selected = child.value is 'soldat-light-syntax'
        child.dispatchEvent(new Event('change', {bubbles: true}))
      expect(soldat.config.get('core.themes')).toEqual ['soldat-dark-ui', 'soldat-light-syntax']

  describe "when the 'core.config' key changes", ->
    it "refreshes the theme menus", ->
      reloadedHandler.reset()
      soldat.config.set('core.themes', ['soldat-light-ui', 'soldat-light-syntax'])

      waitsFor ->
        reloadedHandler.callCount is 1

      runs ->
        expect(panel.refs.uiMenu.value).toBe 'soldat-light-ui'
        expect(panel.refs.syntaxMenu.value).toBe 'soldat-light-syntax'

  xdescribe "when the themes panel is navigated to", ->
    xit "focuses the search filter", ->
      settingsView.showPanel('Themes')
      expect(panel.refs.filterEditor.element).toHaveFocus()

  describe "theme lists", ->
    [installed] = []
    beforeEach ->
      installed = JSON.parse fs.readFileSync(path.join(__dirname, 'fixtures', 'installed.json'))
      spyOn(packageManager, 'loadCompatiblePackageVersion').andCallFake ->
      spyOn(packageManager, 'getInstalled').andReturn Promise.resolve(installed)
      panel = new ThemesPanel(settingsView, packageManager)

      waitsFor ->
        packageManager.getInstalled.callCount is 1 and panel.refs.communityCount.textContent.indexOf('…') < 0

    it 'shows the themes', ->
      expect(panel.refs.communityCount.textContent.trim()).toBe '1'
      expect(panel.refs.communityPackages.querySelectorAll('.package-card:not(.hidden)').length).toBe 1

      expect(panel.refs.coreCount.textContent.trim()).toBe '1'
      expect(panel.refs.corePackages.querySelectorAll('.package-card:not(.hidden)').length).toBe 1

      expect(panel.refs.devCount.textContent.trim()).toBe '1'
      expect(panel.refs.devPackages.querySelectorAll('.package-card:not(.hidden)').length).toBe 1

    it 'filters themes by name', ->
      panel.refs.filterEditor.setText('user-')
      window.advanceClock(panel.refs.filterEditor.getBuffer().stoppedChangingDelay)
      expect(panel.refs.communityCount.textContent.trim()).toBe '1/1'
      expect(panel.refs.communityPackages.querySelectorAll('.package-card:not(.hidden)').length).toBe 1

      expect(panel.refs.coreCount.textContent.trim()).toBe '0/1'
      expect(panel.refs.corePackages.querySelectorAll('.package-card:not(.hidden)').length).toBe 0

      expect(panel.refs.devCount.textContent.trim()).toBe '0/1'
      expect(panel.refs.devPackages.querySelectorAll('.package-card:not(.hidden)').length).toBe 0

    it 'adds newly installed themes to the list', ->
      [installCallback] = []
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        installCallback = callback
        onWillThrowError: ->
      spyOn(soldat.packages, 'loadPackage').andCallFake (name) ->
        installed.user.push {name, theme: 'ui'}

      expect(panel.refs.communityCount.textContent.trim()).toBe '1'
      expect(panel.refs.communityPackages.querySelectorAll('.package-card:not(.hidden)').length).toBe 1

      packageManager.install({name: 'another-user-theme', theme: 'ui'})
      installCallback(0, '', '')

      advanceClock ThemesPanel.loadPackagesDelay()
      waits 1
      runs ->
        expect(panel.refs.communityCount.textContent.trim()).toBe '2'
        expect(panel.refs.communityPackages.querySelectorAll('.package-card:not(.hidden)').length).toBe 2

    it 'collapses/expands a sub-section if its header is clicked', ->
      expect(panel.element.querySelectorAll('.sub-section-heading.has-items').length).toBe 3
      panel.element.querySelector('.sub-section.installed-packages .sub-section-heading.has-items').click()
      expect(panel.element.querySelector('.sub-section.installed-packages')).toHaveClass 'collapsed'

      expect(panel.element.querySelector('.sub-section.core-packages')).not.toHaveClass 'collapsed'
      expect(panel.element.querySelector('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

      panel.element.querySelector('.sub-section.installed-packages .sub-section-heading.has-items').click()
      expect(panel.element.querySelector('.sub-section.installed-packages')).not.toHaveClass 'collapsed'

    it 'can collapse and expand any of the sub-sections', ->
      expect(panel.element.querySelectorAll('.sub-section-heading.has-items').length).toBe 3

      for heading in panel.element.querySelectorAll('.sub-section-heading.has-items')
        heading.click()
      expect(panel.element.querySelector('.sub-section.installed-packages')).toHaveClass 'collapsed'
      expect(panel.element.querySelector('.sub-section.core-packages')).toHaveClass 'collapsed'
      expect(panel.element.querySelector('.sub-section.dev-packages')).toHaveClass 'collapsed'

      for heading in panel.element.querySelectorAll('.sub-section-heading.has-items')
        heading.click()
      expect(panel.element.querySelector('.sub-section.installed-packages')).not.toHaveClass 'collapsed'
      expect(panel.element.querySelector('.sub-section.core-packages')).not.toHaveClass 'collapsed'
      expect(panel.element.querySelector('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

    it 'can collapse sub-sections when filtering', ->
      panel.refs.filterEditor.setText('user-')
      window.advanceClock(panel.refs.filterEditor.getBuffer().stoppedChangingDelay)

      hasItems = panel.element.querySelectorAll('.sub-section-heading.has-items')
      expect(hasItems.length).toBe 1
      expect(hasItems[0].textContent).toMatch /^Community Themes/

  describe 'when there are no themes', ->
    beforeEach ->
      installed =
        dev: []
        user: []
        core: []

      spyOn(packageManager, 'loadCompatiblePackageVersion').andCallFake ->
      spyOn(packageManager, 'getInstalled').andReturn Promise.resolve(installed)
      panel = new ThemesPanel(settingsView, packageManager)

      waitsFor ->
        packageManager.getInstalled.callCount is 1 and panel.refs.communityCount.textContent.indexOf('…') < 0

    afterEach ->
      soldat.themes.deactivateThemes()

    it 'has a count of zero in all headings', ->
      for heading in panel.element.querySelector('.section-heading-count')
        expect(heading.textContent).toMatch /^0+$/
      expect(panel.element.querySelectorAll('.sub-section .icon-paintcan').length).toBe 4
      expect(panel.element.querySelectorAll('.sub-section .icon-paintcan.has-items').length).toBe 0

    it 'can collapse and expand any of the sub-sections', ->
      for heading in panel.element.querySelectorAll('.sub-section-heading')
        heading.click()
      expect(panel.element.querySelector('.sub-section.installed-packages')).not.toHaveClass 'collapsed'
      expect(panel.element.querySelector('.sub-section.core-packages')).not.toHaveClass 'collapsed'
      expect(panel.element.querySelector('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

    it 'does not allow collapsing on any section when filtering', ->
      panel.refs.filterEditor.setText('user-')
      window.advanceClock(panel.refs.filterEditor.getBuffer().stoppedChangingDelay)

      for heading in panel.element.querySelector('.section-heading-count')
        expect(heading.textContent).toMatch /^(0\/0)+$/
      expect(panel.element.querySelectorAll('.sub-section .icon-paintcan').length).toBe 4
      expect(panel.element.querySelectorAll('.sub-section .icon-paintcan.has-items').length).toBe 0
