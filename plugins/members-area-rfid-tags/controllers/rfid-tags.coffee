Controller = require 'members-area/app/controller'
_ = require 'underscore'
async = require 'async'

module.exports = class Rfidtags extends Controller
  @before 'ensureAdmin', only: ['settings']
  @before 'loadRoles', only: ['settings']
  @before 'loadEntries', only: ['settings']
  @before 'verifySecret', only: ['list']
  @before 'receive', only: ['list']

  verifySecret: (done) ->
    secret = @plugin.get('apiSecret')
    if !secret?.length or @req.cookies.SECRET != secret
      @rendered = true # We're handling rendering
      @res.json 401, {errorCode: 401, errorMessage: "Invalid or no auth"}
    return done()

  receive: (done) ->
    return done() unless @req.method in ['POST', 'PUT']
    error = (status, obj) =>
      @rendered = true # We're handling rendering
      @res.json status, obj
      return done()

    if !@req.body?.tags
      return error 400, {errorCode: 400, errorMessage: "Invalid POST data"}

    {tags} = @req.body
    tagUids = Object.keys(tags)

    req = @req
    receiveTag = (tagUid, done) =>
      req.models.Rfidtag.find()
        .where('uid = ?', [tagUid])
        .first (err, tag) =>
          error = (status, obj) =>
            @rendered = true # We're handling rendering
            @res.json status, obj
            return done(new Error("Failed on tag '#{tagUid}'"))
          return done err if err
          remoteTag = tags[tagUid]
          if !tag
            # Create it
            if remoteTag.assigned_user
              return error 403, {errorCode: 403, errorMessage: "You can't assign a new token!"}
            secrets = {}
            for k, v of remoteTag when k.match /^sector_/
              secrets[k] = v
            tag = new req.models.Rfidtag
              uid: tagUid
              count: remoteTag.count
              secrets: secrets
              meta: {}
            tag.save (err) ->
              if err
                console.dir err
                return error 400, {errorCode: 400, errorMessage: "Couldn't create tag"}
              return done()
          else
            async.series
              updateCount: (done) ->
                tag.count = remoteTag.count
                tag.save done
              addScans: (done) =>
                addScan = (scan, done) =>
                  location = String(scan.location ? "")
                  successful = (String(result ? "allowed") is "allowed")
                  whenEntered = new Date(parseInt(scan.date, 10) * 1000)

                  unless whenEntered.getFullYear() >= 2014
                    return done(new Error("Invalid date"))

                  entry =
                    user_id: tag.user_id
                    uid: tagUid
                    location: location
                    successful: successful
                    when: whenEntered
                    meta: {}

                  @req.models.Rfidentry.create [entry], done
                async.eachSeries remoteTag.scans, addScan, done
            , done

    async.eachSeries tagUids, receiveTag, done


  list: (done) ->
    @rendered = true # We're handling rendering
    secret = @plugin.get('apiSecret')
    if !secret?.length or @req.cookies.SECRET != secret
      @res.json 401, {errorCode: 401, errorMessage: "Invalid or no auth"}
      return done()
    else
      @req.models.Rfidtag.find().run (err, tags) =>
        @req.models.User.find().run (err2, users) =>
          err ||= err2
          if err
            @res.json 500, {errorCode: 500, errorMessage: err}
            console.error err.stack ? err
            return done(err)

          result =
            tags: {}
            users: {}

          padUserId = (id) ->
            return null unless id?
            targetLength = 6
            id = String(id)
            if id.length < targetLength
              id = new Array(targetLength - id.length + 1).join("0") + id
            return id

          for tag in tags
            result.tags[tag.uid] = _.extend {}, tag.secrets,
              assigned_user: padUserId(tag.user_id)
              count: tag.count

          for u in users
            users[padUserId(u.id)] =
              name: u.fullname
              roles: u.activeRoleIds
          @res.json result
          return done()

  settings: (done) ->
    @data.apiSecret ?= @plugin.get('apiSecret')

    if @req.method is 'POST'
      @plugin.set {apiSecret: @data.apiSecret}
    done()

  loadRoles: (done) ->
    @req.models.Role.find (err, @roles) =>
      done(err)

  loadEntries: (done) ->
    @req.models.Rfidentry.find().order('-id').limit(50).run (err, @entries) =>
      return done err if err
      userIds = []
      userIds.push entry.user_id for entry in @entries when entry.user_id > 0 and entry.user_id not in userIds
      if userIds.length
        @req.models.User.find().where("id in (#{userIds.join(", ")})").run (err, users) =>
          return done err if err
          userById = {}
          userById[user.id] = user for user in users
          for entry in @entries
            entry.user = userById[entry.user_id]
          done()
      else
        done()

  ensureAdmin: (done) ->
    return @redirectTo "/login?next=#{encodeURIComponent @req.path}" unless @req.user?
    return done new @req.HTTPError 403, "Permission denied" unless @req.user.can('admin')
    done()
