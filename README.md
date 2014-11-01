NestedData Model Class
===========

Based upon minimongoid, a Mongoid inspired model architecture for your Meteor apps.  The intension of this fork is to add documentation and hooks.  The API is not guaranteed to be backward compatible with Minimongoid.

# Usage
Like most things in life, it's always easier to demonstrate by example.  Note that it's probably a good idea to stick models somewhere like /lib so they get loaded first -- and yes, you can use these same models on both client and server!

```coffee
class @Recipe extends Minimongoid
  # indicate which collection to use
  @_collection: new Meteor.Collection('recipes')

  # model relations
  @belongs_to: [
    {name: 'user'}
  ]
  @embeds_many: [
    {name: 'ingredients'}
  ]

  # model defaults
  @defaults:
    name: ''
    cooking_time: '30 mins'

  # titleize the name before creation   
  @before_create: (attr) ->
    attr.name = _.titleize(attr.name)
    attr

  # class methods
  # Find me all recipes with an ingredient that starts with "zesty"
  @zesty: ->
    @where({'ingredients.name': /^zesty/i})

  # Add some validation parameters. As long as the @error() method is triggered, then validation will fail
  validate: ->
    unless @name and @name.length > 3
      @error('name', 'Recipe name is required and should be longer than 3 letters.')

  error_message: ->
    msg = ''
    for i in @errors
      for key,value of i
        msg += "<strong>#{key}:</strong> #{value}"
    msg

  # instance methods
  spicy: ->
    "That's a spicy #{@name}!"

  # is this one of my personal creations? T/F
  myRecipe: ->
    @user_id == Meteor.userId()
```

### Common pattern for attaching models to the database

```coffee
@Things = new Mongo.Collection 'things',
  transform: (doc) ->
    new Thing doc
```

or

```js
Things = new Mongo.Collection('things', {
  transform: function (doc) {
    new Thing(doc)
  }
});
```
## Class Methods

### _collection

*required*

Used to determine which collection backs the models.

### _object_id: `false`

Set to true if you need to use real object_ids instead of just strings

### _type: `undefined`

Set to tag each document with a type.

### defaults: `{}`

Map of property names to default values for that value.

### belongs_to: `[]`

### has_many: `[]`

### has_and_belongs_to_many: `[]`

### embedded_in: `null`

### embeds_many: `[]`

### create: `attr={}`

### where: `selector={}`, `options={}`

Returns an array of models from this collection matching `selector` and `options`

### first: `selector={}`, `options={}`

returns a modelized findOne matching `selector` and `options`

### last: `selector={}`, `options={}`

### all: `options={}`

returns `@where({}, options)`

### find: `selector={}`, `options={}`

### count: `selector={}`, `options={}`

Returns the number of documents matching `selector` and `options`

### destroyAll: `selector={}`

Remove all documents of the collection matching `selector`

### modelize: `cursor`, `parent=null`

### to_s

returns the collection name


## Instance API

### constructor: `attr={}`, `parent=null`

`attr` is the initial state of the object. usually it will be a document from the database.

### initializeRelations: `attr={}`, `parent=null`

`attr` is a set of attributes and values to load in using the included relations classes.

Note: If the attribute name starts with `_id` it is ignored.

Note: If the attribute name ends `_id` and it is an instance of `Mongo.ObjectID` then it's value is reassigned to the `_str` attribute of the ObjectID

### save: `attr={}`

`attr` is a set of attributes and values to be persisted to the db layer.

Each key/value pair is set locally first for latency compensation.

If the object was already persisted before this call to save then each `attr` will be persisted using `$set`. Otherwise it will be inserted.

Calls before_save hooks before the mongo operations and after_save hooks after the mongo operations.

Note: To persist the document the first time, use save(). create() will call save internally.

Note: Fails if isValid() returns false

### update: `attr={}`

Alias for save.

### push: `attr`

convience method to update using $addToSet for each k/v pair.

### pull: `attr`

convience method to update using $pull for each k/v pair.

### del: `field`

unsets the field from the object and persists the change

### destroy

if the object has been persisted then remove it from the database.

Sets the local id and _id to null to indicate the lack of persistence.  Leaves the reset of the object intact in memory.

### reload

Used to grab the object from the database and return a refreshed object.

Usage: `obj = obj.reload()`

### isValid

returns true if there are no errors created by a call to validate.

### error `field`, `message`

Sets an error on the object. Used inside of custom validate methods.

Calls validate on the object and returns true if there were no errors


## Model relations
Once you set up a relation that is *not* an embedded one (e.g. `belongs_to`, `has_many`, `has_one`), that relation will become a method on your model instance(s). For example if Recipe `belongs_to` User, then your recipe instance will have a function recipe.user() which will return the related user.


# Testing
There are some stupid simple tests that you can run:

    meteor test-packages ./

Then load up the meteor app in your browser `http://localhost:3000/`

-----
Created by Jake Gaylor of [NestedData](http://nesteddata.com). Derived from a work by Dave Kaplan of [Exygy](http://exygy.com), who originally derived the his work from Mario Uher's [minimongoid](https://github.com/haihappen/minimongoid).