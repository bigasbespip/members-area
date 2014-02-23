{expect, catchErrors} = require '../test_helper'

describe "User", ->
  describe 'validations', ->
    beforeEach ->
      @data =
        email: "me@example.com"
        username: "Freddy"
      @password = "sekrit1!"

      @getErrors = (callback) =>
        user = new @_models.User @data
        user.password = @password
        user.validate (err, errors) =>
          expect(err).to.not.exist
          errors = @_models.User.groupErrors(errors)
          callback errors

      @expectSuccess = (done) =>
        @getErrors (errors) ->
          expect(errors).to.not.exist
          done()

      @expectErrors = (field, regexps..., done) =>
        @getErrors (errors) ->
          expect(errors).to.exist
          expect(errors[field]).to.be.an 'array'
          expect(errors[field].length).to.be.gte 1
          longErrorString = errors[field].join("\n")
          for regexp in regexps
            expect(longErrorString).to.match regexp
          done()

    it 'should validate sensible data', (done) ->
      @expectSuccess done

    describe 'username', ->

      it 'too short', (done) ->
        @data.username = "a"
        @expectErrors 'username', /must be between/i, done

      it 'start with letter', (done) ->
        @data.username = "$$$$$"
        @expectErrors 'username', /start with/i, done

      it 'dodgy characters', (done) ->
        @data.username = "A$$$$"
        @expectErrors 'username', /alphanumeric/i, done

    describe 'address', ->
      it 'accepts valid', (done) ->
        @data.address = "1 Street Road, Townington, Shireshire, So16 1AU"
        @expectSuccess done

      it 'requires postcode', (done) ->
        @data.address = "1 Street Road, Townington, Shireshire"
        @expectErrors 'address', /postcode/i, done

  describe 'bcrypt\'s password', ->
    it 'bcrypts on save', (done) ->
      user = new @_models.User
        username: "BcryptTest"
        fullname: "Bcrypt Test"
        email: "bcrypt@example.com"
      user.password = "MyPassword"
      expect(user.password).to.eq "MyPassword"
      expect(user.hashed_password).to.not.exist
      user.save catchErrors done, (err) ->
        expect(err).to.not.exist
        expect(user.password).to.not.exist
        expect(user.hashed_password).to.exist
        user.checkPassword "MyPassword", (err, correct) ->
          expect(err).to.not.exist
          expect(correct).to.eq true
          done()
