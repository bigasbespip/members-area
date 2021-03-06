Controller = require '../controller'
passport = require '../lib/passport'
crypto = require 'crypto'

module.exports = class SessionController extends Controller
  @before 'sendForgotEmail', only: 'forgot'

  constructor: ->
    super
    @data[k] = null for k, v of @data when v is ""

  login: (done) ->
    @redirectTo "/" if @req.user?
    return done() unless @req.method is 'POST'
    handle = (err, user, info) =>
      return done err if err
      unless user
        @errorText = 'Incorrect username or password.'
        return done()
      unless user.verified
        user.sendVerificationMail()
        @template = 'unverified'
        @email = user.email
        return done()
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

  logout: ->
    @req.logout()
    @redirectTo "/", status: 303

  recover: (done) ->
    id = parseInt(@req.query.id, 10)
    code = String(@req.query.code)
    unless id > 0
      @error = "Bad Link"
      return done()
    @req.models.User.get id, (err, user) =>
      if !user? or user.meta.resetPasswordCode != code
        @error = "Bad Reset Code"
        return done()
      if user.meta.resetPasswordExpires <= Date.now()
        @error = "Reset Link Expired"
        return done()
      return done() unless @req.method is 'POST' and @req.body.form is 'recover' and @req.body.password?.length > 5
      user.password = @req.body.password
      @done = true
      user.save done


  forgot: (done) ->
    return done()

  sendForgotEmail: (done) ->
    return done() unless @req.method is 'POST' and @req.body.form is 'reset' and @req.body.email?.length
    @req.models.User.find().where("LOWER(email) = ?", [@req.body.email.toLowerCase()]).first (err, user) =>
      if err || !user
        @errorText = "Email not found"
        return done()
      crypto.randomBytes 20, (err, buf) =>
        return done(err) if err
        code = buf.toString('hex')
        user.setMeta
          resetPasswordCode: code
          resetPasswordExpires: Date.now() + 12 * 60 * 60 * 1000
        user.save (err) =>
          return done(err) if err
          @sent = true
          resetURL = "#{process.env.SERVER_ADDRESS}/recover?id=#{user.id}&code=#{encodeURIComponent code}"
          locals =
            to: "#{user.safename} <#{user.email}>"
            subject: "Password Recovery"
            user: user
            email: user.email
            code: code
            resetURL: resetURL
            site: @app.siteSetting.meta.settings
          @app.sendEmail "recover", locals, done
