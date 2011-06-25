# Support class & instance methods for Plugin Classes(Not the Actual Plugin Class) like PluginImage, PluginComment, etc.=
module Opal
  module ActsAsOpalPlugin       
    module ClassMethods              
      def item(item)
        where("item_id = ?", item.id)
      end
      
      def approved
         where("is_approved = ?", "1")
      end
      
      def plugin # get plugin record for this class
        Plugin.where("name = ?", system_name).first
      end
      
      def system_name # the plain, system name of the plugin, ie: Image
        name.gsub("Plugin", "")
      end  
      
      def get_setting(name)
        plugin.get_setting(name)
      end
      
      def get_setting_bool(name)
        plugin.get_setting_bool(name)
      end 
      
      def activate_has_many # create has_many relationship for this plugin
       
      end
    end
    
    module InstanceMethods
      def is_approved?
         self.is_approved == "1" if respond_to?(:is_approved) 
      end   
    end
    
    def self.included(base) # automatically called when included
      base.send(:extend, ClassMethods)
      base.send(:include, InstanceMethods)
      
      # Create has_many associations
      Item.send(:has_many,  base.name.underscore.pluralize.to_sym, :dependent => :destroy) # automatically create a has_many association for Item
    end
  end
end 