fs = require 'fs'
path = require 'path'

PackageDetailView = require '../lib/package-detail-view'
PackageManager = require '../lib/package-manager'
SettingsView = require '../lib/settings-view'
SoldatTvClient = require '../lib/soldat-tv-client'
SnippetsProvider =
  getSnippets: -> {}

describe "PackageDetailView", ->
  packageManager = null
  view = null

  createClientSpy = ->
    jasmine.createSpyObj('client', ['package', 'avatar'])

  beforeEach ->
    packageManager = new PackageManager
    view = null

  loadPackageFromRemote = (opts) ->
    opts ?= {}
    packageManager.client = createClientSpy()
    packageManager.client.package.andCallFake (name, cb) ->
      packageData = require(path.join(__dirname, 'fixtures', 'package-with-readme', 'package.json'))
      packageData.readme = fs.readFileSync(path.join(__dirname, 'fixtures', 'package-with-readme', 'README.md'), 'utf8')
      cb(null, packageData)
    view = new PackageDetailView({name: 'package-with-readme'}, new SettingsView(), packageManager, SnippetsProvider)
    view.beforeShow(opts)

  it "renders a package when provided in `initialize`", ->
    soldat.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))
    pack = soldat.packages.getLoadedPackage('package-with-config')
    view = new PackageDetailView(pack, new SettingsView(), packageManager, SnippetsProvider)

    # Perhaps there are more things to assert here.
    expect(view.refs.title.textContent).toBe('Package With Config')

  it "does not call the atom.io api for package metadata when present", ->
    packageManager.client = createClientSpy()
    view = new PackageDetailView({name: 'package-with-config'}, new SettingsView(), packageManager, SnippetsProvider)

    # PackageCard is a subview, and it calls SoldatTvClient::package once to load
    # metadata from the cache.
    expect(packageManager.client.package.callCount).toBe(1)

  it "shows a loading message and calls out to atom.io when package metadata is missing", ->
    loadPackageFromRemote()
    expect(view.refs.loadingMessage).not.toBe(null)
    expect(view.refs.loadingMessage.classList.contains('hidden')).not.toBe(true)
    expect(packageManager.client.package).toHaveBeenCalled()

  it "shows an error when package metadata cannot be loaded via the API", ->
    packageManager.client = createClientSpy()
    packageManager.client.package.andCallFake (name, cb) ->
      error = new Error('API error')
      cb(error, null)

    view = new PackageDetailView({name: 'nonexistent-package'}, new SettingsView(), packageManager, SnippetsProvider)

    expect(view.refs.errorMessage.classList.contains('hidden')).not.toBe(true)
    expect(view.refs.loadingMessage.classList.contains('hidden')).toBe(true)
    expect(view.element.querySelectorAll('.package-card').length).toBe(0)

  it "shows an error when package metadata cannot be loaded from the cache and the network is unavailable", ->
    spyOn(SoldatTvClient.prototype, 'online').andReturn(false)
    spyOn(SoldatTvClient.prototype, 'request').andCallThrough()
    spyOn(SoldatTvClient.prototype, 'fetchFromCache').andCallFake (path, opts, cb) ->
      # this is the special case which happens when the data is not in the cache
      # and there's no connectivity
      cb(null, {})

    view = new PackageDetailView({name: 'some-package'}, new SettingsView(), packageManager, SnippetsProvider)

    expect(SoldatTvClient.prototype.fetchFromCache).toHaveBeenCalled()
    expect(SoldatTvClient.prototype.request).not.toHaveBeenCalled()

    expect(view.refs.errorMessage.classList.contains('hidden')).not.toBe(true)
    expect(view.refs.loadingMessage.classList.contains('hidden')).toBe(true)
    expect(view.element.querySelectorAll('.package-card').length).toBe(0)

  it "renders the README successfully after a call to the atom.io api", ->
    loadPackageFromRemote()
    expect(view.packageCard).toBeDefined()
    expect(view.packageCard.refs.packageName.textContent).toBe('package-with-readme')
    expect(view.element.querySelectorAll('.package-readme').length).toBe(1)

  it "renders the README successfully with sanitized html", ->
    loadPackageFromRemote()
    expect(view.element.querySelectorAll('.package-readme script').length).toBe(0)
    expect(view.element.querySelectorAll('.package-readme input[type="checkbox"][disabled]').length).toBe(2)

  it "renders the README when the package path is undefined", ->
    soldat.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-readme'))
    pack = soldat.packages.getLoadedPackage('package-with-readme')
    delete pack.path
    view = new PackageDetailView(pack, new SettingsView(), packageManager, SnippetsProvider)

    expect(view.packageCard).toBeDefined()
    expect(view.packageCard.refs.packageName.textContent).toBe('package-with-readme')
    expect(view.element.querySelectorAll('.package-readme').length).toBe(1)

  it "should show 'Install' as the first breadcrumb by default", ->
    loadPackageFromRemote()
    expect(view.refs.breadcrumb.textContent).toBe('Install')
