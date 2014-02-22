Controller = require '../controller'
passport = require '../passport'

module.exports = class SessionController extends Controller
  @before 'requireNotLoggedIn'

  constructor: ->
    super
    @data[k] = null for k, v of @data when v is ""

  login: (done) ->
    return done() unless @req.method is 'POST'
    handle = (err, user, info) =>
      return done err if err
      return done() unless user
      user.hasActiveRole 1, (approved) =>
        if approved
          @req.login user, (err) =>
            return done err if err
            # XXX: check for and handle ?next
            @redirectTo "/", status: 303
        else
          @template = 'unapproved'
          done()
    passport.authenticate('local', handle)(@req, @res, @next)

  requireNotLoggedIn: ->
    @redirectTo "/" if @req.user?