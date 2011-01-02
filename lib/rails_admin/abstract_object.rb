 module RailsAdmin
  class AbstractObject
    instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$)/ }
      
    attr_accessor :object
    attr_accessor :associations
    attr_accessor :history_message
    
    def initialize(object)
      self.object = object
    end
    
    def attributes=(attributes)
      object.send :attributes=, attributes, false
    end
      
    def method_missing(name, *args, &block)
      self.object.send name, *args, &block
    end
    
    def save(options = { :validate => true })
      prepare_history_message
      
      object.save(options) and update_all_associations and save_history
    end
    
    protected
    
    
    def prepare_history_message
      action = object.new_record? ? "Created" : "Updated"
      label = model_config.bind(:object, object).list.object_label
      self.history_message = "#{action} #{label}"
    end
    
    def save_history
      date = Time.now
      
      History.create(
        :message => history_message,
        :item => object.id,
        :table => model.pretty_name,
        :username => "",
        :month => date.month,
        :year => date.year
      )
    end
    
    def model
      @model ||= AbstractModel.new(object.class.name)
    end
    
    def model_config
      @model_config ||= RailsAdmin.config(model)
    end
    
    def update_all_associations
      return true if associations.nil?
      
      model.associations.each do |association|
        if associations.has_key?(association[:name])
          ids = (associations || {}).delete(association[:name])
          case association[:type]
          when :has_one
            update_association(association, ids)
          when :has_many, :has_and_belongs_to_many
            update_associations(association, ids.to_a)
          end
        end
      end
    end
    
    def update_associations(association, ids = [])
      associated_model = RailsAdmin::AbstractModel.new(association[:child_model])
      object.send "#{association[:name]}=", ids.collect{|id| associated_model.get(id)}.compact
      object.save
    end
    
    def update_association(association, id = nil)
      associated_model = RailsAdmin::AbstractModel.new(association[:child_model])
      if associated = associated_model.get(id)
        associated.update_attributes(association[:child_key].first => object.id)
      end
    end
  end
end