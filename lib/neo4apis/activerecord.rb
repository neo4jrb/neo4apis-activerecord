require 'neo4apis'
require 'ostruct'

module Neo4Apis
  class ActiveRecord < Base
    prefix nil

    batch_size 1000

    def self.model_importer(model_class)
      uuid model_class.name.to_sym, model_class.primary_key

      importer model_class.name.to_sym do |object|
        node = add_model_node model_class, object

        model_class.reflect_on_all_associations.each do |association_reflection|
          case association_reflection.macro
          when :belongs_to, :has_one
            if options[:"import_#{association_reflection.macro}"]
              referenced_object = object.send(association_reflection.name)
              add_model_relationship association_reflection.name, node, referenced_object if referenced_object
            end
          when :has_many
            if options[:import_has_many]
              object.send(association_reflection.name).each do |referenced_object|
                add_model_relationship association_reflection.name, node, referenced_object if referenced_object
              end
            end
          end
        end
      end
    end

    def add_model_relationship(relationship_name, node, referenced_object)
      referenced_class = referenced_object.class
      referenced_node = add_model_node referenced_class, referenced_object

      add_relationship relationship_name, node, referenced_node
    end

    def add_model_node(model_class, object)
      object_data = OpenStruct.new

      object.attributes.each do |column, value|
        v = object.attributes_for_coder[column] || value
        object_data.send("#{column}=", v)
      end

      add_node model_class.name.to_sym, object_data, model_class.column_names
    end
  end
end
