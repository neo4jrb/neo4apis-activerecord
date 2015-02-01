require 'neo4apis/table_resolver'

module Neo4Apis
  module ModelResolver
    def self.included(base)
      base.include TableResolver
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
      identify_foreign_key_bases(model_class.column_names).each do |foreign_key_base|
        begin
          base = foreign_key_base.gsub(/ +/, '_').tableize

          if identify_table_name(tables, base.classify) && model_class.name != base.classify
            model_class.belongs_to base.singularize.to_sym, foreign_key: column.name, class_name: base.classify
          end
        rescue UnfoundTableError
          nil
        end
      end
    end

    def identify_foreign_key_bases(columns)
      columns.map do |column|
        match = column.match(/^(.+)_id$/i) || column.match(/^(.+)id$/i)

        match && match[1]
      end.compact
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
  end
end
