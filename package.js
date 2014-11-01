Package.describe({
  name: "nd:minimongoid",
  summary: "NestedData's model class based on minimongoid",
  version: "0.0.1",
  git: "https://github.com/nesteddata/minimongoid.git"
});

Package.onUse(function (api) {
  api.versionsFrom("METEOR@0.9.0");
  var both = ['client', 'server'];
  var dependencies = [
    'underscore',
    'mrt:underscore-string-latest@2.3.3',
    'coffeescript'
  ];
  api.use(dependencies, both);
  var files = [
    'lib/relation.coffee',
    'lib/has_many_relation.coffee',
    'lib/has_and_belongs_to_many_relation.coffee',
    'lib/minimongoid.coffee'
  ];
  api.addFiles(files, both);
});

Package.onTest(function (api) {
  var both = ['client', 'server'];
  api.use(['nd:minimongoid', 'tinytest', 'coffeescript'], both);
  api.addFiles('tests/models.coffee', both);
  api.addFiles('tests/server_tests.coffee', ['server']);
  api.addFiles('tests/model_tests.coffee', both);
});
