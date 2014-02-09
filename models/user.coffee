bcrypt = require 'bcrypt'

disallowedUsernameRegexps = [
  /master$/i
  /^admin/i
  /admin$/i
  /^(southackton|soha|somakeit|smi)$/i
  /^trust/i
  /^director/i
  /^(root|daemon|bin|sys|sync|backup|games|man|lp|mail|news|proxy|www-data|apache|apache2|irc|nobody|syslog|sshd|ubuntu|mysql|logcheck|redis)$/i
  /^(admin|join|social|info|queries)$/i
]

module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'User',
    email:
      type: DataTypes.STRING
      allowNull: false
      unique: true
      validate:
        isEmail: true

    username:
      type: DataTypes.STRING
      allowNull: false
      unique: true
      validate:
        len: {args: [3,14], msg: "must be between 3 and 14 characters"}
        isAlphanumeric: (value) -> throw "must be alphanumeric" unless /^[a-z0-9]*$/i.test value
        startsWithLetter: (value) -> throw "must start with a letter" unless /^[a-z]/i.test value
        isDisallowed: (value) -> throw "disallowed username." for regexp in disallowedUsernameRegexps when regexp.test value

    password:
      type: DataTypes.STRING
      allowNull: false
      validate:
        len: [6, 9999]

    paidUntil:
      type: DataTypes.DATE
      allowNull: true

    fullname:
      type: DataTypes.STRING
      allowNull: true
      validate:
        isName: (value) -> throw "invalid name" unless /^.+ .+$/.test value

    address:
      type: DataTypes.TEXT
      allowNull: true
      validate:
        len: [8, 999]
        hasMultipleLines: (value) -> throw "must have multiple lines" unless /(\n|,)/.test(value)
        hasPostcode: (value) -> throw "must have valid postcode" unless /(GIR 0AA)|((([A-Z][0-9][0-9]?)|(([A-Z][A-Z][0-9][0-9]?)|(([A-Z][0-9][A-HJKSTUW])|([A-Z][A-Z][0-9][ABEHMNPRVWXY])))) ?[0-9][A-Z]{2})/i.test(value)

    approved:
      type: DataTypes.DATE
      allowNull: true

    meta:
      type: DataTypes.TEXT
      allowNull: false
  ,
    validate:
      addressRequired: -> # XXX: if they've a role that requires address, don't allow address to be null, etc.
