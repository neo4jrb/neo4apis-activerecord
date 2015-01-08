require 'active_record'
require 'active_support/inflector'
require 'thor'
require 'colorize'

module Neo4Apis
  module CLI
    class ActiveRecord < Thor
      class_option :config_path, type: :string,  default: 'config/database.yml'

      class_option :import_associations, type: :boolean, default: false
      class_option :import_belongs_to, type: :boolean, default: nil
      class_option :import_has_one, type: :boolean, default: nil
      class_option :import_has_many, type: :boolean, default: nil

      class_option :guess_model, type: :boolean, default: false

      class_option :active_record_config_path, type: :string, default: './config/database.yml'
      class_option :active_record_environment, type: :string, default: 'development'

      desc 'tables MODELS_OR_TABLE_NAMES', 'Import SQL specified tables'
      def tables(*models_or_table_names)
        setup

        model_classes = models_or_table_names.map(&method(:get_model))

        puts "Importing tables: " + model_classes.map(&:table_name).join(', ')

        model_classes.each do |model_class|
          ::Neo4Apis::ActiveRecord.model_importer(model_class)
        end

        neo4apis_client.batch do
          model_classes.each do |model_class|
            model_class.find_each do |object|
              neo4apis_client.import model_class.name.to_sym, object
            end
          end
        end
      end

      desc 'all_tables', 'Import all SQL tables'
      def all_tables
        setup

        models(*::ActiveRecord::Base.connection.tables)
      end

      private

      def setup
        if File.exist?('config/environment.rb')
          # Rails
          require './config/environment'
        else
          ::ActiveRecord::Base.establish_connection(active_record_config)
        end
      end

      NEO4APIS_CLIENT_CLASS = ::Neo4Apis::ActiveRecord

      def neo4apis_client
        @neo4apis_client ||= NEO4APIS_CLIENT_CLASS.new(Neo4j::Session.open(:server_db, parent_options[:neo4j_url]),
                                                       import_belongs_to: import_association?(:belongs_to),
                                                       import_has_one: import_association?(:has_one),
                                                       import_has_many: import_association?(:has_many))
      end

      def import_association?(type)
        options[:"import_#{type}"].nil? ? options[:import_associations] : options[:"import_#{type}"]
      end


      def get_model(model_or_table_name)
        get_model_class(model_or_table_name).tap do |model_class|
          if options[:guess_model]
            apply_guessed_table_name!(model_class)
            apply_guessed_primary_key!(model_class)
            apply_guessed_model_associations!(model_class)
          end
        end
      end

      def get_model_class(model_or_table_name)
        model_class = model_or_table_name
        model_class = model_or_table_name.classify unless model_or_table_name.match(/^[A-Z]/)
        model_class.constantize
      rescue NameError
        Object.const_set(model_class, Class.new(::ActiveRecord::Base))
      end

      def apply_guessed_model_associations!(model_class)
        model_class.columns.each do |column|
          match = column.name.match(/^(.*)(_id|Id)$/)
          next if not match

          begin
            base = match[1].tableize

            model_class.belongs_to base.singularize.to_sym, foreign_key: column.name, class_name: base.classify if guessed_table_name(base.classify)
          rescue NameError
          end
        end
      end

      def apply_guessed_table_name!(model_class)
        guess = guessed_table_name(model_class.name)
        model_class.table_name = guess if guess
      end

      def apply_guessed_primary_key!(model_class)
        name = model_class.name
        guess = (model_class.column_names & ['id', name.foreign_key, name.foreign_key.classify, 'uuid']).first
        model_class.primary_key = guess if guess
      end


      def active_record_config
        require 'yaml'
        YAML.load(File.read(options[:active_record_config_path]))[options[:active_record_environment]]
      end

      private

      def guessed_table_name(model_name)
        (::ActiveRecord::Base.connection.tables & [model_name.tableize, model_name.classify, model_name.tableize.singularize, model_name.classify.pluralize]).first
      end
    end

    class Base < Thor
      desc 'activerecord SUBCOMMAND ...ARGS', 'methods of importing data automagically from Twitter'
      subcommand 'activerecord', CLI::ActiveRecord
    end
  end
end
