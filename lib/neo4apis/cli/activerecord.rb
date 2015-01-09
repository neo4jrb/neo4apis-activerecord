require 'active_record'
require 'active_support/inflector'
require 'thor'
require 'colorize'
require 'neo4apis/table_resolver'
require 'neo4apis/cli/base'

module Neo4Apis
  module CLI
    class ActiveRecord < CLI::Base
      include TableResolver

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
            include_list = model_class.reflect_on_all_associations.map do |association_reflection|
              association_reflection.name if import_association?(association_reflection.macro)
            end.compact
            query = query.includes(*include_list.map(&:to_sym)) if include_list.present?

            query.find_each do |object|
              neo4apis_client.import model_class.name.to_sym, object
            end
          end
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
        @neo4apis_client ||= NEO4APIS_CLIENT_CLASS.new(Neo4j::Session.open(:server_db, parent_options[:neo4j_url]),
                                                       import_belongs_to: import_association?(:belongs_to),
                                                       import_has_one: import_association?(:has_one),
                                                       import_has_many: import_association?(:has_many))
      end

      def import_association?(type)
        options[:"import_#{type}"].nil? ? options[:import_all_associations] : options[:"import_#{type}"]
      end


      def get_model(model_or_table_name)
        get_model_class(model_or_table_name).tap do |model_class|
          if options[:identify_model]
            apply_identified_table_name!(model_class)
            apply_identified_primary_key!(model_class)
            apply_identified_model_associations!(model_class)
          end
        end
      end

      def get_model_class(model_or_table_name)
        return model_or_table_name if model_or_table_name.is_a?(Class) && model_or_table_name.ancestors.include?(::ActiveRecord::Base)

        model_class = model_or_table_name.gsub(/\s+/, '_')
        model_class = model_or_table_name.classify unless model_or_table_name.match(/^[A-Z]/)
        model_class.constantize
      rescue NameError
        Object.const_set(model_class, Class.new(::ActiveRecord::Base))
      end

      def apply_identified_model_associations!(model_class)
        model_class.columns.each do |column|
          match = column.name.match(/^(.*)(_id|Id)$/)
          next if not match

          begin
            base = match[1].gsub(/ +/, '_').tableize

            if identify_table_name(tables, base.classify) && model_class.name != base.classify
              model_class.belongs_to base.singularize.to_sym, foreign_key: column.name, class_name: base.classify
            end
          rescue UnfoundTableError
            nil
          end
        end
      end

      def apply_identified_table_name!(model_class)
        identity = identify_table_name(tables, model_class.name)
        model_class.table_name = identity if identity
      end

      def apply_identified_primary_key!(model_class)
        identity = ::ActiveRecord::Base.connection.primary_key(model_class.table_name)
        identity ||= identify_primary_key(model_class.column_names, model_class.name)
        model_class.primary_key = identity if identity
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
