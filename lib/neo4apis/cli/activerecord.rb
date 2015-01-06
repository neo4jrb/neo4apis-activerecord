require 'active_record'
require 'active_support/inflector'
require 'thor'
require 'colorize'

module Neo4Apis
  module CLI
    class ActiveRecord < Thor
      class_option :config_path, type: :string,  default: 'config/database.yml'

      class_option :import_belongs_to, type: :boolean, default: false
      class_option :import_has_one, type: :boolean, default: false
      class_option :import_has_many, type: :boolean, default: false


      desc "table TABLE_NAME_OR_MODEL", "Import SQL table from ActiveRecord model"
      def table(table_name_or_model)
        setup

        model_class = table_name_or_model.classify.constantize

        ::Neo4Apis::ActiveRecord.model_importer(model_class)

        neo4apis_client.batch do
          model_class.find_each do |object|
            neo4apis_client.import model_class.name.to_sym, object
          end
        end
      end

      private

      def setup
        require './config/environment'
      end

      NEO4APIS_CLIENT_CLASS = ::Neo4Apis::ActiveRecord

      def neo4apis_client
        @neo4apis_client ||= NEO4APIS_CLIENT_CLASS.new(Neo4j::Session.open(:server_db, parent_options[:neo4j_url]),
                                                       import_belongs_to: options[:import_belongs_to],
                                                       import_has_one: options[:import_has_one],
                                                       import_has_many: options[:import_has_many])
      end

    end

    class Base < Thor
      desc "activerecord SUBCOMMAND ...ARGS", "methods of importing data automagically from Twitter"
      subcommand "activerecord", CLI::ActiveRecord
    end
  end
end

