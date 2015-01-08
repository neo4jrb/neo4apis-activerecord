# neo4apis-activerecord

**The easiest and quickest way to copy data from PostgreSQL / mySQL / sqlite to Neo4j**

## How to run:

Without existing ActiveRecord application:

    neo4apis activerecord all_tables --import-all-associations --identify-model

or

    neo4apis activerecord tables posts comments --import-all-associations --identify-model

With existing ActiveRecord application:

    neo4apis activerecord all_models --import-all-associations

or

    neo4apis activerecord models Post Comment --import-all-associations

## Installation

Using rubygems:

    gem install neo4apis-activerecord

## How it works

ActiveRecord models are either found or generated from table structures.  The models are then introspected to create nodes (from tables) and relationships (from associations) in neo4j.  The neo4apis library is used to load data efficiently in batches.

## Options

For a list of all options run:

    neo4apis activerecord --help

### `--identify-model`

The `--identify-model` option looks for tables' names/primay keys/foreign keys automatically.  Potential options are generated and the database is examined to find out which fits.

For a table of blog posts, the following possibilities are used:

 * Names: `posts`, `post`, `Posts`, or `Post`
 * Primary keys: (e.g. `id`, `post_id`, `PostId`, or `uuid`
 * Foreign keys: `author_id` or `AuthorId` will be assumed to go to a table of authors (with a name identified as specified above)

### `--import-belongs-to` / `--import-has-many` / `--import-has-one` / `--import-all-associations`

Either specify that a certain class of associations should be imported from ActiveRecord models, or specify all with `--import-all-associations`

