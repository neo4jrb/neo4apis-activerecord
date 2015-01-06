require 'neo4apis-activerecord'

module Helpers
  def clear_neo4j(neo4j_connection, neo4j_url)
    neo4j_connection.query('MATCH (n) OPTIONAL MATCH (n)-[r]-() DELETE n,r')

    # Clear constraints / indexes
    conn = Faraday.new(url: neo4j_url)
    response = conn.get('/db/data/schema/constraint/')
    JSON.parse(response.body).each do |constraint|
      Neo4j::Session.query("DROP CONSTRAINT ON (label:`#{constraint['label']}`) ASSERT label.#{constraint['property_keys'].first} IS UNIQUE")
    end 

    JSON.parse(conn.get('/db/data/schema/index/').body).each do |index|
      Neo4j::Session.query("DROP INDEX ON :`#{index['label']}`(#{index['property_keys'].first})")
    end
  end
end

RSpec.configure do |c|
  c.include Helpers

  ActiveRecord::Migration.verbose = false
end

