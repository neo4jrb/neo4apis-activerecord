require 'neo4apis'
require 'ostruct'

module Neo4Apis
  class ActiveRecord < Base
    prefix nil

    batch_size 1000

    def self.model_importer(model_class)
      self.uuid model_class.name.to_sym, model_class.primary_key

      self.importer model_class.name.to_sym do |object|
        node = add_model_node model_class, object

        model_class.reflect_on_all_associations.each do |association_reflection|
          case association_reflection.macro
          when :belongs_to, :has_one
            if options[:"import_#{association_reflection.macro}"]
              referenced_object = object.send(association_reflection.name)
              referenced_class = referenced_object.class
              referenced_node = add_model_node referenced_class, referenced_object

              add_relationship association_reflection.name, node, referenced_node
            end
          when :has_many
            if options[:import_has_many]
              object.send(association_reflection.name).each do |referenced_object|
                referenced_class = referenced_object.class
                referenced_node = add_model_node referenced_class, referenced_object

                add_relationship association_reflection.name, node, referenced_node
              end
            end
          end
        end
      end

    end

    def add_model_node(model_class, object)
      object_data = OpenStruct.new

      object.attributes.each do |column, value|
        v = if coder = model_class.serialized_attributes[column]
              coder.dump(value)
            else
              value
            end
        object_data.send("#{column}=", v)
      end

      add_node model_class.name.to_sym, object_data, model_class.column_names
    end


  end

end

