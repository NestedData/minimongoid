# From http://book.cakephp.org/2.0/en/models/associations-linking-models-together.html#hasandbelongstomany-habtm
# The main difference between hasMany and HABTM is that a link between models in HABTM 
# is not exclusive. For example, we’re about to join up our Recipe model with an 
# Ingredient model using HABTM. Using tomatoes as an Ingredient for my grandma’s spaghetti 
# recipe doesn’t “use up” the ingredient. I can also use it for a salad Recipe.
class @HasAndBelongsToManyRelation extends @Relation
  constructor: (instance, klass, identifier, inverse_identifier, id, args...) ->
    @instance = instance
    @inverse_identifier = inverse_identifier
    @link = {}
    @link[identifier] = [id]
    super klass, args...

  @new: (instance, klass, identifier, inverse_identifier, id, args...) ->
    new @(instance, klass, identifier, inverse_identifier, id, args...)

  @fromRelation: (relation, instance, identifier, inverse_identifier, id) ->
    new @(instance, relation.relationClass(), identifier, inverse_identifier, id, relation.toArray()...)

  create: (attr) ->
    obj = super _.extend(attr, @link)
    attr = {}
    if @instance[@inverse_identifier].length == 0
      attr[@inverse_identifier] = [obj.id]
      @instance.update attr
    else
      @instance.push(attr)
    obj
    
