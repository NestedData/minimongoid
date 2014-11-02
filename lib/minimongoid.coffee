# Assumes that all related objects are also models
# transformed using Minimongoid

# TODO: onChange hooks
#   ie -  onChange 'title', (value, doc) ->
#           slug = NDUtils.slugify(value)
#           unless doc.slug == slug
#             @update({slug:slug})
global = @

class @Minimongoid
  # --- instance vars
  id: undefined
  errors: false
  # attr: {}

  # --- instance methods 
  # given a document from the database (or from any source really) create an instance of the model
  constructor: (attr = {}, parent=null) ->
    if attr._id
      if @constructor._object_id
        @id = attr._id._str
      else
        @id = attr._id
      @_id = @id
    # set up errors var

    # initialize relation arrays to be an empty array, if they don't exist.
    # only initialize relations if the object has been persisted before
    if @id
      @initializeRelations(attr, parent) 

  initializeRelations: (attr = {}, parent=null) ->
    for habtm in @constructor.has_and_belongs_to_many
      # e.g. matchup.game_ids = []
      identifier = "#{_.singularize(habtm.name)}_ids"
      @[identifier] ||= []
    # initialize relation arrays to be an empty array, if they don't exist 
    for embeds_many in @constructor.embeds_many
      @[embeds_many.name] ||= []

    if @constructor.embedded_in and parent
      @[@constructor.embedded_in] = parent


    # load in all the passed attrs 
    for name, value of attr
      continue if name.match(/^_id/)
      if name.match(/_id$/) and (value instanceof Mongo.ObjectID)
        @[name] = value._str
      else if (embeds_many = _.findWhere(@constructor.embeds_many, {name: name}))
        # initialize a model with the appropriate attributes 
        # also pass "self" along as the parent model
        class_name = embeds_many.class_name || _.classify(_.singularize(name))
        @[name] = global[class_name].modelize(value, @)
      else
        @[name] = value

    # load in defaults
    for attr, val of @constructor.defaults
      @[attr] = val if typeof @[attr] is 'undefined'


    self = @

    # set up belongs_to methods, e.g. recipe.user()
    for belongs_to in @constructor.belongs_to
      relation = belongs_to.name
      identifier = belongs_to.identifier || "#{relation}_id"
      # set up default class name, e.g. "belongs_to: user" ==> 'User'
      class_name = belongs_to.class_name || _.titleize(relation)

      @[relation] = do(relation, identifier, class_name) ->
        (options = {}) ->
          # if we have a relation_id 
          if global[class_name] and self[identifier]
            return global[class_name].find self[identifier], options
          else
            return false


    # set up has_many methods, e.g. user.recipes()
    for has_many in @constructor.has_many
      relation = has_many.name
      selector = {}
      unless foreign_key = has_many.foreign_key
        # can't use @constructor.name in production because it's been minified to "n"
        foreign_key = "#{_.singularize(@constructor.to_s().toLowerCase())}_id"
      if @constructor._object_id
        selector[foreign_key] = new Meteor.Collection.ObjectID @id
      else
        selector[foreign_key] = @id
      # set up default class name, e.g. "has_many: users" ==> 'User'
      class_name = has_many.class_name || _.titleize(_.singularize(relation))
      @[relation] = do(relation, selector, class_name) ->
        (mod_selector = {}, options = {}) ->
          # first consider any passed in selector options
          mod_selector = _.extend mod_selector, selector
          # e.g. where {user_id: @id}
          if global[class_name]
            HasManyRelation.fromRelation(global[class_name].where(mod_selector, options), foreign_key, @id)


    # set up HABTM methods, e.g. user.friends()
    for habtm in @constructor.has_and_belongs_to_many
      relation = habtm.name
      identifier = "#{_.singularize(relation)}_ids"
      # set up default class name, e.g. "habtm: users" ==> 'User'
      class_name = habtm.class_name || _.titleize(_.singularize(relation))
      @[relation] = do(relation, identifier, class_name) ->
        (mod_selector = {}, options = {}) ->
          selector =  {_id: {$in: self[identifier]}}
          # first consider any passed in selector options
          mod_selector = _.extend mod_selector, selector
          instance = global[class_name].init()
          filter = (r) ->
            name = r.class_name || _.titleize(_.singularize(r.name))
            global[name] == this.constructor
          inverse = _.find instance.constructor.has_and_belongs_to_many, filter, @
          inverse_identifier = "#{_.singularize(inverse.name)}_ids"
          if global[class_name] and self[identifier] and self[identifier].length
            relation = global[class_name].where mod_selector, options
            return HasAndBelongsToManyRelation.fromRelation(relation, @, inverse_identifier, identifier, @id)
          else
            return HasAndBelongsToManyRelation.new(@, global[class_name], inverse_identifier, identifier, @id)

  # Sets an error on the object. Used inside of custom validate methods.
  error: (field, message) ->
    # add an error. 
    # TODO: should this be a private method?
    @errors ||= []
    obj = {}
    obj[field] = message
    @errors.push obj

  # returns true if there are no errors created by a call to validate.
  isValid: (attr = {}) -> 
    @validate()
    not @errors

  # nothing by default. intended to be overwritten
  validate: ->
    # if blah then @errors.blah = 'no, bad!' else @errors = false
    true

  save: (attr = {}) ->
    # reset errors before running isValid()
    @errors = false

    # TODO: before_save hooks. for each fn in the array of registered hooks call _.extend(attr, fn_return_val)
    # bail if invalid

    # mirror the updates locally
    for k,v of attr
      @[k] = v

    return @ if not @isValid()

    # always store the current _type if it's set. Not sure what this is for
    attr['_type'] = @constructor._type if @constructor._type?
    
    # if the id isn't set it's because it hasn't been stored the first time yet.
    if @id?
      @constructor._collection.update @id, { $set: attr }
    else
      @id = @_id = @constructor._collection.insert attr
    
    # TODO: 
    if @constructor.after_save
      @constructor.after_save(@)

    return @

  update: (attr) ->
    @save(attr)

  # push to mongo array field
  push: (attr) -> 
    # TODO: should maybe do something like this; but it should know if we're pushing an embedded model and instantiate it...
    # for name, value of attr 
    #   # update locally 
    #   @[name].push value

    # addToSet to ensure uniqueness -- can't think of if/when we WOULDN'T want that??
    @constructor._collection.update @id, {$addToSet: attr}

  # pull from mongo array field
  pull: (attr) ->
    if attr
      @constructor._collection.update @id, {$pull: attr}

  # unset a field from the object and persist the change
  del: (field) ->
    unset = {}
    unset[field] = ""
    @constructor._collection.update @id, {$unset: unset}

  # if the object has been persisted then remove it from the database.
  # Sets the local id and _id to null to indicate the lack of persistence.
  # Leaves the reset of the object intact in memory.
  destroy: ->
    if @id?
      @constructor._collection.remove @id
      @id = @_id = null

  # grab the object from the database and return a refreshed object
  reload: ->
    if @id?
      @constructor.find(@id)

  # --- class variables
  @_object_id: false
  @_collection: undefined
  @_type: undefined
  @_debug: false

  @defaults: {}

  @belongs_to: []
  @has_many: []
  @has_and_belongs_to_many: []

  @embedded_in: null
  @embeds_many: []

  # TODO: arrays of hooks vs fn that calls more fns
  # @after_save: null
  # @before_save: []
  # @before_create: null
  # @after_create: null


  # --- class methods
  @init: (attr, parent=null) ->
    new @(attr, parent)

  @to_s: ->
    if @_collection then @_collection._name else "embedded"

  @create: (attr={}) ->
    attr.createdAt ||= new Date()
    attr = @before_create(attr) if @before_create
    doc = @init(attr)
    doc = doc.save(attr)
    doc.initializeRelations(attr)
    if doc and @after_create
      @after_create(doc)
    else
      doc

  # find + modelize
  @where: (selector = {}, options = {}) ->
    if @_debug
      console.info " --- WHERE ---"
      console.info "  #{_.singularize _.classify @to_s()}.where(#{JSON.stringify selector}#{if not _.isEmpty options then ','+JSON.stringify options else ''})"
    result = @modelize @find(selector, options)
    result.setQuery selector
    console.info "  > found #{result.length}" if @_debug and result
    result

  @first: (selector = {}, options = {}) ->
    if @_debug
      console.info " --- FIRST ---"
      console.info "  #{_.singularize _.classify @to_s()}.first(#{JSON.stringify selector}#{if not _.isEmpty options then ','+JSON.stringify options else ''})"
    if doc = @_collection.findOne(selector, options)
      @init doc

  # kind of a silly method, just does a findOne with reverse sort on createdAt
  @last: (selector = {}, options = {}) ->
    options.sort = createdAt: -1
    if doc = @_collection.findOne(selector, options)
      @init doc

  @all: (options) ->
    @where({}, options)

  # this doesn't perform a fetch, just generates a collection cursor
  @find: (selector = {}, options = {}) ->
    # unless you just pass an id, in which case it *does* fetch the first
    unless typeof selector == 'object'
      if @_object_id
        selector = new Meteor.Collection.ObjectID selector
      @first {_id: selector}, options
    else if selector instanceof Meteor.Collection.ObjectID
      @first {_id: selector}, options
    else
      # handle objectIDs -- these would come from an external database entry e.g. Rails
      if @_object_id
        if selector and selector._id
          if typeof selector._id is 'string'
            selector._id = new Meteor.Collection.ObjectID selector._id
          else if selector._id['$in']
            # _.map(game_ids, function(x) { return new Meteor.Collection.ObjectID(x) })
            selector._id['$in'] = _.map_object_id selector._id['$in']
        if selector and selector._ids 
          selector._ids = _.map(selector._ids, (id) -> new Meteor.Collection.ObjectID id)

      @_collection.find selector, options


  @count: (selector = {}, options = {}) ->
    @find(selector, options).count()

  @destroyAll: (selector = {}) ->
    @_collection.remove(selector)

  # run a model init on all items in the collection 
  @modelize: (cursor, parent=null) ->
    self = @
    models = cursor.map (i) -> self.init(i, parent)
    Relation.new self, models...


# for some reason underscore.inflection stopped working with Meteor 0.6.5. 
# so for now we just use this simple singularize method instead of including the library
_.singularize = (s) ->
  s = s.replace /s$/, ""