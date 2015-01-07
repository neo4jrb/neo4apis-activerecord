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

      class_option :guess_associations, type: :boolean, default: false

      class_option :active_record_config_path, type: :string, default: './config/database.yml'
      class_option :active_record_environment, type: :string, default: 'development'

      desc 'models MODELS_OR_TABLE_NAMES', 'Import SQL tables via ActiveRecord models'
      def models(*models_or_table_names)
        setup

        puts 'models_or_table_names', models_or_table_names.inspect
        model_classes = models_or_table_names.map(&method(:get_model))

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

      private

      def setup
        if File.exist?('config/environment.rb')
          # Rails
          require './config/environment'
        else
          puts 'active_record_config', active_record_config.inspect
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
        model_class = model_or_table_name
        model_class = model_or_table_name.classify unless model_or_table_name.match(/^[A-Z]/)
        model_class.constantize
      rescue NameError
        Object.const_set(model_class, Class.new(::ActiveRecord::Base)).tap do |model_class|
          apply_guessed_model_associations!(model_class) if options[:guess_associations]
        end
      end

      def apply_guessed_model_associations!(model_class)
        model_class.columns.each do |column|
          next if not column.name.match(/_id$/)

          begin
            base = column.name.humanize.tableize.split(' ').join('_')

            model_class.belongs_to base.singularize.to_sym
          rescue NameError
          end
        end
      end

      def active_record_config
        require 'yaml'
        YAML.load(File.read(options[:active_record_config_path]))[options[:active_record_environment]]
      end
    end

    class Base < Thor
      desc 'activerecord SUBCOMMAND ...ARGS', 'methods of importing data automagically from Twitter'
      subcommand 'activerecord', CLI::ActiveRecord
    end
  end
end
