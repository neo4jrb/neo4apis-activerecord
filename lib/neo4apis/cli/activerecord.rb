require 'active_record'
require 'active_support/inflector'
require 'thor'
require 'colorize'
require 'neo4apis/model_resolver'
require 'neo4apis/cli/base'

module Neo4Apis
  module CLI
    class ActiveRecord < CLI::Base
      include ModelResolver

      class_option :debug, type: :boolean, default: false, desc: 'Output debugging information'

      class_option :import_all_associations, type: :boolean, default: false, desc: 'Shortcut for --import-belongs-to --import-has-many --import-has-one'
      class_option :import_belongs_to, type: :boolean, default: nil
      class_option :import_has_one, type: :boolean, default: nil
      class_option :import_has_many, type: :boolean, default: nil

      class_option :identify_model, type: :boolean, default: false, desc: 'Identify table name, primary key, and foreign keys automatically'

      class_option :startup_environment, type: :string, default: './config/environment.rb', desc: 'Script that will be run before import.  Needs to establish an ActiveRecord connection'

      class_option :active_record_config_path, type: :string, default: './config/database.yml'
      class_option :active_record_environment, type: :string, default: 'development'

      desc 'tables MODELS_OR_TABLE_NAMES', 'Import specified SQL tables'
      def tables(*models_or_table_names)
        setup

        import_models_or_tables(*models_or_table_names)
      end

      desc 'models MODELS_OR_TABLE_NAMES', 'Import specified ActiveRecord models'
      def models(*models_or_table_names)
        setup

        import_models_or_tables(*models_or_table_names)
      end

      desc 'all_tables', 'Import all SQL tables'
      def all_tables
        setup

        import_models_or_tables(*::ActiveRecord::Base.connection.tables)
      end

      desc 'all_models', 'Import SQL tables using defined models'
      def all_models
        setup

        Rails.application.eager_load!

        import_models_or_tables(*::ActiveRecord::Base.descendants)
      end

      private

      def debug_log(*messages)
        return unless options[:debug]

        puts(*messages)
      end

      def import_models_or_tables(*models_or_table_names)
        model_classes = models_or_table_names.map(&method(:get_model))

        puts 'Importing tables: ' + model_classes.map(&:table_name).join(', ')

        model_classes.each do |model_class|
          ::Neo4Apis::ActiveRecord.model_importer(model_class)
        end

        neo4apis_client.batch do
          model_classes.each do |model_class|
            query = model_class.all

            # Eager load association for faster import
            include_list = include_list_for_model(model_class)
            query = query.includes(*include_list) if include_list.present?

            query.find_each do |object|
              neo4apis_client.import model_class.name.to_sym, object
            end
          end
        end
      end

      def include_list_for_model(model_class)
        model_class.reflect_on_all_associations.map do |association_reflection|
          association_reflection.name.to_sym if import_association?(association_reflection.macro)
        end.compact.tap do |include_list|
          debug_log 'include_list', include_list.inspect
        end
      end

      def setup
        if File.exist?(options[:startup_environment])
          require options[:startup_environment]
        else
          ::ActiveRecord::Base.establish_connection(active_record_config)
        end
      end

      NEO4APIS_CLIENT_CLASS = ::Neo4Apis::ActiveRecord

      def neo4apis_client
        @neo4apis_client ||= NEO4APIS_CLIENT_CLASS.new(specified_neo4j_session,
                                                       import_belongs_to: import_association?(:belongs_to),
                                                       import_has_one: import_association?(:has_one),
                                                       import_has_many: import_association?(:has_many))
      end

      def import_association?(type)
        options[:"import_#{type}"].nil? ? options[:import_all_associations] : options[:"import_#{type}"]
      end


      def active_record_config
        require 'yaml'
        YAML.load(File.read(options[:active_record_config_path]))[options[:active_record_environment]]
      end

      def tables
        ::ActiveRecord::Base.connection.tables
      end
    end

    class Base < Thor
      desc 'activerecord SUBCOMMAND ...ARGS', 'methods of importing data automagically from Twitter'
      subcommand 'activerecord', CLI::ActiveRecord
    end
  end
end
