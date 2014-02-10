module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'Role',
    name:
      type: DataTypes.STRING
      allowNull: false
      unique: true
      validate:
        isAlphanumeric: true

    meta: sequelize.membersMeta
