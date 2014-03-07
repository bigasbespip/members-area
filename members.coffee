async = require 'async'
crypto = require 'crypto'
fs = require 'fs'
{spawn} = child_process = require 'child_process'
_ = require 'underscore'

arg = process.argv[2]

usage = ->
  console.log """
    Usage:

      version    - what version are you running?
      quickstart - init && migrate && seed && plugins && run
      init       - set up a members are in the current folder
      setup      - migrate && seed && plugins
      migrate    - migrate the database
      seed       - seed the database
      plugins    - npm install plugins
      run        - run the server (do this in the root folder)
    """

cwd = process.cwd()

methods = new class
  help: =>
    usage()

  version: =>
    pkg = require "#{__dirname}/package.json"
    console.log "Members Area, v#{pkg.version}"

  run: =>
    proc = spawn "node", ["#{cwd}/node_modules/.bin/coffee", "index.coffee"],
      cwd: cwd
      stdio: 'inherit'
    proc.on 'close', process.exit
    process.on 'SIGINT', ->
      proc.kill 'SIGINT'
    process.on 'SIGTERM', ->
      proc.kill 'SIGTERM'

  plugins: (done = ->) =>
    pluginsJson = require "#{cwd}/config/plugins.json"
    install = ([name, version], next) ->
      proc = spawn "npm", ["install", "--save", "#{name}@#{version}"],
        cwd: process.cwd()
        stdio: 'inherit'
      proc.on 'close', -> next()
    async.eachSeries _.pairs(pluginsJson), install, done

  migrate: (done = ->) =>
    console.log "Migrating"
    proc = spawn "#{__dirname}/scripts/db/migrate", [],
      cwd: process.cwd()
      stdio: 'inherit'
    proc.on 'close', -> done()

  seed: (done = ->) =>
    console.log "Seeding"
    proc = spawn "#{__dirname}/scripts/db/seed", [],
      cwd: process.cwd()
      stdio: 'inherit'
    proc.on 'close', -> done()

  quickstart: (done = ->) =>
    async.series [
      @init
      @migrate
      @seed
      @plugins
      @run
    ], done

  setup: (done = ->) =>
    async.series [
      @migrate
      @seed
      @plugins
    ], done

  init: (done = ->) =>
    console.log "Initialising a members area in #{cwd}"
    files = fs.readdirSync cwd
    unless files.indexOf("package.json") >= 0
      console.error "Please run `npm init` first."
      process.exit 1
    for file in files
      unless file.match /^(\..*|package.json|node_modules)$/
        console.error "Folder is not empty: '#{file}' forbidden"
        process.exit 1
    pkg = require "#{cwd}/package.json"
    pkg.scripts ?= {}
    pkg.scripts.start ?= "./node_modules/.bin/coffee index.coffee"
    pkg.dependencies ?= {}
    pkg.dependencies["sqlite3"] ?= "~2.2.0"
    pkg.dependencies["coffee-script"] ?= ">1.6"
    pkg.dependencies["members-area"] ?= "*"
    fs.writeFileSync "package.json", JSON.stringify pkg, null, 2
    fs.writeFileSync ".gitignore", """
      *.sqlite
      config/
      log/
      node_modules/
      sessions/
      """
    fs.writeFileSync "index.coffee", """
      MembersArea = require 'members-area'

      # Make sure we're in the right folder.
      process.chdir __dirname

      MembersArea.start()
      """
    fs.mkdirSync "config"
    fs.mkdirSync "log"
    fs.mkdirSync "public"
    fs.mkdirSync "sessions"
    fs.writeFileSync "config/db.json", JSON.stringify
      development: "sqlite:///members.sqlite"
      test: "sqlite:///members-test.sqlite"
    fs.writeFileSync "config/plugins.json", JSON.stringify
      'members-area-passport': '*'
    async.series
      npmInstall: (next) ->
        proc = spawn "npm", ["install"],
          cwd: process.cwd()
          stdio: 'inherit'
        proc.on 'close', -> next()
      setSettings: (next) ->
        crypto.randomBytes 18, (err, bytes) ->
          fs.writeFileSync "config/development.json", JSON.stringify
            secret: bytes?.toString('base64') ? "PutSecureSecretHere"
            serverAddress: "http://localhost:1337"
          next()
    , done

arg = arg?.replace /[^a-z]/g, ""
fn = methods[arg]
if fn?
  fn()
else
  usage()
