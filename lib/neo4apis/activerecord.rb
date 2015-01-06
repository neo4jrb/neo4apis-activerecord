require 'neo4apis'
require 'ostruct'

module Neo4Apis
  class ActiveRecord < Base
    prefix nil

    batch_size 1000

    def self.model_importer(model_class)
      self.uuid model_class.name.to_sym, model_class.primary_key

      self.importer model_class.name.to_sym do |object|
        node = add_node model_class.name.to_sym, object, model_class.column_names

        model_class.reflect_on_all_associations.each do |association_reflection|
          case association_reflection.macro
          when :belongs_to, :has_one
            if options[:"import_#{association_reflection.macro}"]
              referenced_object = object.send(association_reflection.name)
              referenced_class = referenced_object.class
              referenced_node = add_node referenced_class.name.to_sym, referenced_object, referenced_class.column_names

              add_relationship association_reflection.name, node, referenced_node
            end
          when :has_many
            if options[:import_has_many]
              object.send(association_reflection.name).each do |referenced_object|
                referenced_class = referenced_object.class
                referenced_node = add_node referenced_class.name.to_sym, referenced_object, referenced_class.column_names

                add_relationship association_reflection.name, node, referenced_node
              end
            end
          end
        end
      end

    end

  end

end

