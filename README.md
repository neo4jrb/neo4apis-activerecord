# neo4apis-activerecord

**The easiest and quickest way to copy data from PostgreSQL / mySQL / sqlite to Neo4j**

## How to run:

Without existing ActiveRecord application:

    neo4apis activerecord all_tables --identify-model --import-all-associations

or

    neo4apis activerecord tables posts comments --identify-model --import-all-associations

With existing ActiveRecord application:

    neo4apis activerecord all_models --import-all-associations

or

    neo4apis activerecord models Post Comment --import-all-associations

## Installation

Using rubygems:

    gem install neo4apis-activerecord

## How it works

[ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html) is a [ORM](http://en.wikipedia.org/wiki/Object-relational_mapping) for ruby.  `neo4apis-activerecord` uses ActiveRecord models which are either found in an existing ruby app or generated from table structures.  The models are then introspected to create nodes (from tables) and relationships (from associations) in neo4j.  The neo4apis library is used to load data efficiently in batches.

## Options

For a list of all options run:

    neo4apis activerecord --help

Some options of particular interest:

### `--identify-model`

The `--identify-model` option looks for tables' names/primay keys/foreign keys automatically.  Potential options are generated and the database is examined to find out which fits.

As an example: for a table of posts the following possibilities would checked:

 * Names: Looks for names like `posts`, `post`, `Posts`, or `Post`
 * Primary keys: Table schema is examined first.  If no primary key is specified it will look for columns like `id`, `post_id`, `PostId`, or `uuid`
 * Foreign keys: `author_id` or `AuthorId` will be assumed to go to a table of authors (with a name identified as above)

### `--import-belongs-to`
### `--import-has-many`
### `--import-has-one`
### `--import-all-associations`

Either specify that a certain class of associations be imported from ActiveRecord models or specify all with `--import-all-associations`

## Using `neo4apis-activerecord` from ruby

If you'd like to do custom importing, you can use `neo4apis-activerecord` in the following way:

    Neo4Apis::ActiveRecord.model_importer(SomeModel)

    neo4apis_activerecord = Neo4Apis::ActiveRecord.new(Neo4j::Session.open, import_all_associations: true)

    neo4apis_activerecord.batch do
      SomeModel.where(condition: 'value').find_each do |object|
        neo4apis_activerecord.import object
      end
    end

