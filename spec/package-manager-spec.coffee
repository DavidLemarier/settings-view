path = require 'path'
process = require 'process'
PackageManager = require '../lib/package-manager'

describe "PackageManager", ->
  [packageManager] = []

  beforeEach ->
    spyOn(soldat.packages, 'getApmPath').andReturn('/an/invalid/apm/command/to/run')
    packageManager = new PackageManager()

  it "handle errors spawning apm", ->
    noSuchCommandError = if process.platform is 'win32' then ' cannot find the path ' else 'ENOENT'
    waitsForPromise shouldReject: true, -> packageManager.search('test')
    waitsForPromise shouldReject: true, -> packageManager.getInstalled()
    waitsForPromise shouldReject: true, -> packageManager.getOutdated()
    waitsForPromise shouldReject: true, -> packageManager.getFeatured()
    waitsForPromise shouldReject: true, -> packageManager.getPackage('foo')

    installCallback = jasmine.createSpy('installCallback')
    uninstallCallback = jasmine.createSpy('uninstallCallback')
    updateCallback = jasmine.createSpy('updateCallback')

    runs ->
      packageManager.install {name: 'foo', version: '1.0.0'}, installCallback

    waitsFor ->
      installCallback.callCount is 1

    runs ->
      installArg = installCallback.argsForCall[0][0]
      expect(installArg.message).toBe "Installing \u201Cfoo@1.0.0\u201D failed."
      expect(installArg.packageInstallError).toBe true
      expect(installArg.stderr).toContain noSuchCommandError

      packageManager.uninstall {name: 'foo'}, uninstallCallback

    waitsFor ->
      uninstallCallback.callCount is 1

    runs ->
      uninstallArg = uninstallCallback.argsForCall[0][0]
      expect(uninstallArg.message).toBe "Uninstalling \u201Cfoo\u201D failed."
      expect(uninstallArg.stderr).toContain noSuchCommandError

      packageManager.update {name: 'foo'}, '1.0.0', updateCallback

    waitsFor ->
      updateCallback.callCount is 1

    runs ->
      updateArg = updateCallback.argsForCall[0][0]
      expect(updateArg.message).toBe "Updating to \u201Cfoo@1.0.0\u201D failed."
      expect(updateArg.packageInstallError).toBe true
      expect(updateArg.stderr).toContain noSuchCommandError

  describe "::isPackageInstalled()", ->
    it "returns false a package is not installed", ->
      expect(packageManager.isPackageInstalled('some-package')).toBe false

    it "returns true when a package is loaded", ->
      spyOn(soldat.packages, 'isPackageLoaded').andReturn true
      expect(packageManager.isPackageInstalled('some-package')).toBe true

    it "returns true when a package is disabled", ->
      spyOn(soldat.packages, 'getAvailablePackageNames').andReturn ['some-package']
      expect(packageManager.isPackageInstalled('some-package')).toBe true

  describe "::install()", ->
    [runArgs, runCallback] = []

    beforeEach ->
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        runArgs = args
        runCallback = callback
        onWillThrowError: ->

    it "installs the latest version when a package version is not specified", ->
      packageManager.install {name: 'something'}, ->
      expect(packageManager.runCommand).toHaveBeenCalled()
      expect(runArgs).toEqual ['install', 'something', '--json']

    it "installs the package@version when a version is specified", ->
      packageManager.install {name: 'something', version: '0.2.3'}, ->
      expect(packageManager.runCommand).toHaveBeenCalled()
      expect(runArgs).toEqual ['install', 'something@0.2.3', '--json']

    describe "git url installation", ->
      it 'installs https:// urls', ->
        url = "https://github.com/user/repo.git"
        packageManager.install {name: url}
        expect(packageManager.runCommand).toHaveBeenCalled()
        expect(runArgs).toEqual ['install', 'https://github.com/user/repo.git', '--json']

      it 'installs git@ urls', ->
        url = "git@github.com:user/repo.git"
        packageManager.install {name: url}
        expect(packageManager.runCommand).toHaveBeenCalled()
        expect(runArgs).toEqual ['install', 'git@github.com:user/repo.git', '--json']

      it 'installs user/repo url shortcuts', ->
        url = "user/repo"
        packageManager.install {name: url}
        expect(packageManager.runCommand).toHaveBeenCalled()
        expect(runArgs).toEqual ['install', 'user/repo', '--json']

      it 'installs and activates git pacakges with names different from the repo name', ->
        spyOn(soldat.packages, 'activatePackage')
        packageManager.install(name: 'git-repo-name')
        json =
          metadata:
            name: 'real-package-name'
        runCallback(0, JSON.stringify([json]), '')
        expect(soldat.packages.activatePackage).toHaveBeenCalledWith json.metadata.name

      it 'emits an installed event with a copy of the pack including the full package metadata', ->
        spyOn(packageManager, 'emitPackageEvent')
        originalPackObject = name: 'git-repo-name', otherData: {will: 'beCopied'}
        packageManager.install(originalPackObject)
        json =
          metadata:
            name: 'real-package-name'
            moreInfo: 'yep'
        runCallback(0, JSON.stringify([json]), '')

        installEmittedCount = 0
        for call in packageManager.emitPackageEvent.calls
          if call.args[0] is "installed"
            expect(call.args[1]).not.toEqual originalPackObject
            expect(call.args[1].moreInfo).toEqual "yep"
            expect(call.args[1].otherData).toBe originalPackObject.otherData
            installEmittedCount++
        expect(installEmittedCount).toBe 1

  describe "::uninstall()", ->
    [runCallback] = []

    beforeEach ->
      spyOn(packageManager, 'unload')
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        runCallback = callback
        onWillThrowError: ->

    it "removes the package from the core.disabledPackages list", ->
      soldat.config.set('core.disabledPackages', ['something'])

      packageManager.uninstall {name: 'something'}, ->

      expect(soldat.config.get('core.disabledPackages')).toContain('something')
      runCallback(0, '', '')
      expect(soldat.config.get('core.disabledPackages')).not.toContain('something')

  describe "::installAlternative", ->
    beforeEach ->
      spyOn(soldat.packages, 'activatePackage')
      spyOn(packageManager, 'runCommand').andCallFake ->
        onWillThrowError: ->
      soldat.packages.loadPackage(path.join(__dirname, 'fixtures', 'language-test'))
      waitsFor ->
        soldat.packages.isPackageLoaded('language-test') is true

    it "installs the latest version when a package version is not specified", ->
      installedCallback = jasmine.createSpy()
      installingEvent = jasmine.createSpy()
      installedEvent = jasmine.createSpy()

      eventArg =
        alternative: 'a-new-package'
        pack:
          name: 'language-test'

      packageManager.on 'package-installing-alternative', installingEvent
      packageManager.on 'package-installed-alternative', installedEvent

      packageManager.installAlternative({name: 'language-test'}, 'a-new-package', installedCallback)
      expect(packageManager.runCommand).toHaveBeenCalled()
      expect(packageManager.runCommand.calls[0].args[0]).toEqual(['uninstall', '--hard', 'language-test'])
      expect(packageManager.runCommand.calls[1].args[0]).toEqual(['install', 'a-new-package', '--json'])
      expect(soldat.packages.isPackageLoaded('language-test')).toBe true

      expect(installedEvent).not.toHaveBeenCalled()
      expect(installingEvent).toHaveBeenCalled()
      expect(installingEvent.mostRecentCall.args[0]).toEqual eventArg

      packageManager.runCommand.calls[0].args[1](0, '', '')

      waits 1
      runs ->
        expect(soldat.packages.activatePackage).not.toHaveBeenCalled()
        expect(soldat.packages.isPackageLoaded('language-test')).toBe false

        packageManager.runCommand.calls[1].args[1](0, '', '')

      waits 1
      runs ->
        expect(soldat.packages.activatePackage).toHaveBeenCalledWith 'a-new-package'
        expect(soldat.packages.isPackageLoaded('language-test')).toBe false

        expect(installedEvent).toHaveBeenCalled()
        expect(installedEvent.mostRecentCall.args[0]).toEqual eventArg

        expect(installedCallback).toHaveBeenCalled()
        expect(installedCallback.mostRecentCall.args[0]).toEqual null
        expect(installedCallback.mostRecentCall.args[1]).toEqual eventArg

  describe "::packageHasSettings", ->
    it "returns true when the pacakge has config", ->
      soldat.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))
      expect(packageManager.packageHasSettings('package-with-config')).toBe true

    it "returns false when the pacakge does not have config and doesn't define language grammars", ->
      expect(packageManager.packageHasSettings('random-package')).toBe false

    it "returns true when the pacakge does not have config, but does define language grammars", ->
      packageName = 'language-test'

      waitsForPromise ->
        soldat.packages.activatePackage(path.join(__dirname, 'fixtures', packageName))

      runs ->
        expect(packageManager.packageHasSettings(packageName)).toBe true

  describe "::loadOutdated", ->
    it "caches results", ->
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        callback(0, '[{"name": "boop"}]', '')
        onWillThrowError: ->

      packageManager.loadOutdated false, ->
      expect(packageManager.apmCache.loadOutdated.value).toMatch([{"name": "boop"}])

      packageManager.loadOutdated false, ->
      expect(packageManager.runCommand.calls.length).toBe(1)

    it "expires results after a timeout", ->
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        callback(0, '[{"name": "boop"}]', '')
        onWillThrowError: ->

      packageManager.loadOutdated false, ->
      now = Date.now()
      spyOn(Date, 'now') unless Date.now.andReturn
      Date.now.andReturn((-> now + packageManager.CACHE_EXPIRY + 1)())
      packageManager.loadOutdated false, ->

      expect(packageManager.runCommand.calls.length).toBe(2)

    it "expires results after a package updated/installed", ->
      packageManager.apmCache.loadOutdated =
        value: ['hi']
        expiry: Date.now() + 999999999

      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        callback(0, '[{"name": "boop"}]', '')
        onWillThrowError: ->

      # Just prevent this stuff from calling through, it doesn't matter for this test
      spyOn(soldat.packages, 'deactivatePackage').andReturn(true)
      spyOn(soldat.packages, 'activatePackage').andReturn(true)
      spyOn(soldat.packages, 'unloadPackage').andReturn(true)
      spyOn(soldat.packages, 'loadPackage').andReturn(true)

      packageManager.loadOutdated false, ->
      expect(packageManager.runCommand.calls.length).toBe(0)

      packageManager.update {}, {}, -> # +1 runCommand call to update the package
      packageManager.loadOutdated false, -> # +1 runCommand call to load outdated because the cache should be wiped
      expect(packageManager.runCommand.calls.length).toBe(2)

      packageManager.install {}, -> # +1 runCommand call to install the package
      packageManager.loadOutdated false, -> # +1 runCommand call to load outdated because the cache should be wiped
      expect(packageManager.runCommand.calls.length).toBe(4)

      packageManager.loadOutdated false, -> # +0 runCommand call, should be cached
      expect(packageManager.runCommand.calls.length).toBe(4)

    it "expires results if it is called with clearCache set to true", ->
      packageManager.apmCache.loadOutdated =
        value: ['hi']
        expiry: Date.now() + 999999999

      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        callback(0, '[{"name": "boop"}]', '')
        onWillThrowError: ->

      packageManager.loadOutdated true, ->
      expect(packageManager.runCommand.calls.length).toBe(1)
      expect(packageManager.apmCache.loadOutdated.value).toEqual [{"name": "boop"}]

    describe "when there is a version pinned package", ->
      beforeEach ->
        soldat.config.set('core.versionPinnedPackages', ['beep'])

      it "caches results", ->
        spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
          callback(0, '[{"name": "boop"}, {"name": "beep"}]', '')
          onWillThrowError: ->

        packageManager.loadOutdated false, ->
        expect(packageManager.apmCache.loadOutdated.value).toMatch([{"name": "boop"}])

        packageManager.loadOutdated false, ->
        expect(packageManager.runCommand.calls.length).toBe(1)

      it "expires results after a timeout", ->
        spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
          callback(0, '[{"name": "boop"}, {"name": "beep"}]', '')
          onWillThrowError: ->

        packageManager.loadOutdated false, ->
        now = Date.now()
        spyOn(Date, 'now') unless Date.now.andReturn
        Date.now.andReturn((-> now + packageManager.CACHE_EXPIRY + 1)())
        packageManager.loadOutdated false, ->

        expect(packageManager.runCommand.calls.length).toBe(2)

      it "expires results after a package updated/installed", ->
        packageManager.apmCache.loadOutdated =
          value: ['hi']
          expiry: Date.now() + 999999999

        spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
          callback(0, '[{"name": "boop"}, {"name": "beep"}]', '')
          onWillThrowError: ->

        # Just prevent this stuff from calling through, it doesn't matter for this test
        spyOn(soldat.packages, 'deactivatePackage').andReturn(true)
        spyOn(soldat.packages, 'activatePackage').andReturn(true)
        spyOn(soldat.packages, 'unloadPackage').andReturn(true)
        spyOn(soldat.packages, 'loadPackage').andReturn(true)

        packageManager.loadOutdated false, ->
        expect(packageManager.runCommand.calls.length).toBe(0)

        packageManager.update {}, {}, -> # +1 runCommand call to update the package
        packageManager.loadOutdated false, -> # +1 runCommand call to load outdated because the cache should be wiped
        expect(packageManager.runCommand.calls.length).toBe(2)

        packageManager.install {}, -> # +1 runCommand call to install the package
        packageManager.loadOutdated false, -> # +1 runCommand call to load outdated because the cache should be wiped
        expect(packageManager.runCommand.calls.length).toBe(4)

        packageManager.loadOutdated false, -> # +0 runCommand call, should be cached
        expect(packageManager.runCommand.calls.length).toBe(4)

      it "expires results if it is called with clearCache set to true", ->
        packageManager.apmCache.loadOutdated =
          value: ['hi']
          expiry: Date.now() + 999999999

        spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
          callback(0, '[{"name": "boop"}, {"name": "beep"}]', '')
          onWillThrowError: ->

        packageManager.loadOutdated true, ->
        expect(packageManager.runCommand.calls.length).toBe(1)
        expect(packageManager.apmCache.loadOutdated.value).toEqual [{"name": "boop"}]
