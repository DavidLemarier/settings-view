SettingsView = null
settingsView = null

statusView = null

PackageManager = require './package-manager'
packageManager = null

SnippetsProvider =
  getSnippets: -> soldat.config.scopedSettingsStore.propertySets

configUri = 'soldat://config'
uriRegex = /config\/([a-z]+)\/?([a-zA-Z0-9_-]+)?/i

openPanel = (settingsView, panelName, uri) ->
  match = uriRegex.exec(uri)

  panel = match?[1]
  detail = match?[2]
  options = uri: uri
  if panel is "packages" and detail?
    panelName = detail
    options.pack = name: detail
    options.back = 'Packages' if soldat.packages.getLoadedPackage(detail)

  settingsView.showPanel(panelName, options)

module.exports =
  activate: ->
    soldat.workspace.addOpener (uri) =>
      if uri.startsWith(configUri)
        if not settingsView? or settingsView.destroyed
          settingsView = @createSettingsView({uri})
        if match = uriRegex.exec(uri)
          panelName = match[1]
          panelName = panelName[0].toUpperCase() + panelName.slice(1)
          openPanel(settingsView, panelName, uri)
        settingsView

    soldat.commands.add 'soldat-workspace',
      'settings-view:open': -> soldat.workspace.open(configUri)
      'settings-view:core': -> soldat.workspace.open("#{configUri}/core")
      'settings-view:editor': -> soldat.workspace.open("#{configUri}/editor")
      'settings-view:show-keybindings': -> soldat.workspace.open("#{configUri}/keybindings")
      'settings-view:change-themes': -> soldat.workspace.open("#{configUri}/themes")
      'settings-view:install-packages-and-themes': -> soldat.workspace.open("#{configUri}/install")
      'settings-view:view-installed-themes': -> soldat.workspace.open("#{configUri}/themes")
      'settings-view:uninstall-themes': -> soldat.workspace.open("#{configUri}/themes")
      'settings-view:view-installed-packages': -> soldat.workspace.open("#{configUri}/packages")
      'settings-view:uninstall-packages': -> soldat.workspace.open("#{configUri}/packages")
      'settings-view:check-for-package-updates': -> soldat.workspace.open("#{configUri}/updates")

    if process.platform is 'win32' and require('soldat').WinShell?
      soldat.commands.add 'soldat-workspace', 'settings-view:system': -> soldat.workspace.open("#{configUri}/system")

    unless localStorage.getItem('hasSeenDeprecatedNotification')
      packageManager ?= new PackageManager()
      packageManager.getInstalled().then (packages) =>
        @showDeprecatedNotification(packages) if packages.user?.length

  deactivate: ->
    settingsView?.destroy()
    statusView?.destroy()
    settingsView = null
    packageManager = null
    statusView = null

  consumeStatusBar: (statusBar) ->
    packageManager ?= new PackageManager()
    packageManager.getOutdated().then (updates) ->
      if packageManager?
        PackageUpdatesStatusView = require './package-updates-status-view'
        statusView = new PackageUpdatesStatusView()
        statusView.initialize(statusBar, packageManager, updates)

  consumeSnippets: (snippets) ->
    if typeof snippets.getUnparsedSnippets is "function"
      SnippetsProvider.getSnippets = snippets.getUnparsedSnippets.bind(snippets)

  createSettingsView: (params) ->
    SettingsView ?= require './settings-view'
    packageManager ?= new PackageManager()
    params.packageManager = packageManager
    params.snippetsProvider = SnippetsProvider
    settingsView = new SettingsView(params)

  showDeprecatedNotification: (packages) ->
    localStorage.setItem('hasSeenDeprecatedNotification', true)

    deprecatedPackages = packages.user.filter ({name, version}) ->
      soldat.packages.isDeprecatedPackage(name, version)
    return unless deprecatedPackages.length

    were = 'were'
    have = 'have'
    packageText = 'packages'
    if packages.length is 1
      packageText = 'package'
      were = 'was'
      have = 'has'
    notification = soldat.notifications.addWarning "#{deprecatedPackages.length} #{packageText} #{have} deprecations and #{were} not loaded.",
      description: 'This message will show only one time. Deprecated packages can be viewed in the settings view.'
      detail: (pack.name for pack in deprecatedPackages).join(', ')
      dismissable: true
      buttons: [{
        text: 'View Deprecated Packages',
        onDidClick: ->
          soldat.commands.dispatch(soldat.views.getView(soldat.workspace), 'settings-view:view-installed-packages')
          notification.dismiss()
      }]
