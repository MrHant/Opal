class Item < ActiveRecord::Base
  has_one :item_statistic
  belongs_to :user
  belongs_to :category
  
  has_many :plugin_images
  has_many :plugin_descriptions
  has_many :plugin_feature_values
  has_many :plugin_comments
  has_many :plugin_reviews
  has_many :plugin_links
  has_many :plugin_tags
  has_many :plugin_files
  has_one :item_statistic
  has_many :logs
  
  validates_presence_of :name
  
  after_create :create_everything
  after_destroy :destroy_everything
  after_save :save_tags
  
  attr_accessor :tags 
  attr_protected :user_id, :is_approved, :featured

  
  def to_param # make custom parameter generator for seo urls, to use: pass actual object(not id) into id ie: :id => object
    # this is also backwards compatible with regular integer id lookups, since .to_i gets only contiguous numbers, ie: "4-some-string-here".to_i # => 4    
    "#{id}-#{name.parameterize}" 
  end
  
  def create_everything
    # Create Item Statistic Record
    ItemStatistic.create(:item_id => self.id)
    
    
    # Make Images Folder
    images_path = "#{RAILS_ROOT}/public/images/item_images/#{self.id}"
    FileUtils.mkdir_p(images_path) if !File.exist?(images_path) # create the folder if it doesn't exist

    # Make Images Folder
    files_path = "#{RAILS_ROOT}/files/item_files/#{self.id}"
    FileUtils.mkdir_p(files_path) if !File.exist?(files_path) # create the folder if it doesn't exist
  end

  def destroy_everything
    # Destroy Statistics
    for stat in ItemStatistic.find(:all, :conditions => ["item_id = ?", self.id])
      stat.destroy
    end


    # Destroy Images
    plugins = PluginImage.find(:all, :conditions => ["item_id = ?", self.id])
    for item in plugins
      item.destroy
    end

    # Destroy Description
    plugins = PluginDescription.find(:all, :conditions => ["item_id = ?", self.id])
    for item in plugins
      item.destroy
    end
    
    # Destroy Feature Values
    plugins = PluginFeatureValue.find(:all, :conditions => ["item_id = ?", self.id])
    for item in plugins
      item.destroy
    end
    
    # Destroy Reviews
    plugins = PluginReview.find(:all, :conditions => ["item_id = ?", self.id])
    for item in plugins
      item.destroy
    end    
    
    # Destroy Comments
    plugins = PluginComment.find(:all, :conditions => ["item_id = ?", self.id])
    for item in plugins
      item.destroy
    end
    
    # Destroy Links
    plugins = PluginLink.find(:all, :conditions => ["item_id = ?", self.id])
    for item in plugins
      item.destroy
    end
    
    # Destroy Tags
    plugins = PluginTag.find(:all, :conditions => ["item_id = ?", self.id])
    for item in plugins
      item.destroy
    end
    
    # Destroy Files
    plugins = PluginFile.find(:all, :conditions => ["item_id = ?", self.id])
    for item in plugins
      item.destroy
    end

    # Destroy Discussions
    discussions = PluginDiscussion.find(:all, :conditions => ["item_id = ?", self.id])
    for item in discussions
      item.destroy
    end
    
    # Remove Images Folder
    images_path = "#{RAILS_ROOT}/public/images/item_images/#{self.id}"
    FileUtils.rm_rf(images_path) if File.exist?(images_path) # remove the folder if it exists 
    
    # Remove Files Folder
    files_path = "#{RAILS_ROOT}/files/item_files/#{self.id}"
    FileUtils.rm_rf(files_path) if File.exist?(files_path) # remove the folder if it exists 
    
    #require "#{RAILS_ROOT}/print_id.rb"
  end
  
  
  def features_never_used
    features = PluginFeature.find(:all)
    features_container = Array.new
    for feature in features
      # Check if a value has been set for this feature & item
      feature_value = PluginFeatureValue.find(:first, :conditions => ["item_id =? and plugin_feature_id = ?", self.id, feature.id])
      if !feature_value # if there is no value, add feature to container 
        features_container << feature
      end
    end
    return features_container
  end
  
  def is_viewable_for_user?(user) # Can the current user see this item?
    if user.is_admin == "1" || self.user_id == user.id # User is an admin, or the user that created the item. Item owners can always see their item, but no one else can, if not allowed.
      return true
    else # not an admin or user that created item.
        if self.is_public == "1" && self.is_approved == "1"
          return true
        elsif (self.is_public == "0" && self.is_approved == "1") # It's not public, but is approved 
          return false
        else # not public or viewable
          return false
        end
    end
  end
  
  def is_editable_for_user?(user) # can the user edit this item?
     if ((self.is_user_owner?(user) && !self.locked) || user.is_admin?)  # Yes, the item belongs to the user
       return true
     else # The item does not belong to the user.
       return false
     end
  end
  
  def is_deletable_for_user?(user) # can the user delete this item?
    if user.is_admin? # User is an admin
      return true
    else # not an admin    
      if (Setting.get_setting_bool("users_can_delete_items") && self.is_user_owner?(user) && !self.locked) # check if user that owns this item and users are allowed to delete items
        return true
      else # either not owner or users can't delete items
        return false
      end
    end
  end
  
  def is_approved?
     if self.is_approved == "1"
       return true
     else # The item is not approved
       return false
     end
  end

  def is_public?
     if self.is_public == "1"
       return true
     else # The item is not approved
       return false
     end
  end
 
  def is_user_owner?(user)
     if self.user_id == user.id # is this user the owner?
       return true
     else # not the owner
       return false
     end    
  end
  
  def self.popular_items # get the most popular items
    return Item.find(:all, :order => "views DESC", :limit => 10)
  end 

  def self.featured_items # get featured items
    return Item.find(:all, :conditions => ["featured = true and is_approved = '1' and is_public = '1'"], :order => "created_at DESC")
  end 
  
  def is_new? # has the item been recently added?
    max_hours = 72 # the item must be added within the last x hours to be considered new 
    return ((Time.now - self.created_at) / 3600) < max_hours # convert secs to hours 
  end

  def self.sort_conditions(options = {}) # get sanitized sort conditions for use in find
  end

  def self.sort_order(options = {}) # get sanitized sort order for use in find
    options[:by] ||= Item.human_attribute_name(:created_at)
    options[:direction] ||= "desc"     
    
    # translate to protect against injection 
    translation = Hash.new # create a hash that indexes items by possible user input, but the value of the item is the actual value we'll use.    
    translation[:by] = Hash.new 
    translation[:by][Item.human_attribute_name(:created_at)] = "created_at"
    translation[:by][Item.human_attribute_name(:name)] = "name"
    translation[:by][Item.human_attribute_name(:views)] = "views"
    
    translation[:direction] = Hash.new
    translation[:direction]["asc"] = "ASC"
    translation[:direction]["desc"] = "DESC"
    
    return translation[:by][options[:by]] + " " + translation[:direction][options[:direction]] 
  end
  
  def main_image # get the main image for this item
   return PluginImage.find(:first, :conditions => ["item_id = ?", self.id], :order => "created_at ASC")
 end


 def tag_list
     tag_array = Array.new
     for tag in self.plugin_tags
      tag_array << tag.name
     end   
     return tag_array.join(", ")     
 end

 def tags 
   @tags ||= self.tag_list
 end

 def save_tags # save new tags
   if @tags # if there are any tags...
     # get rid of old tags
     for tag in self.plugin_tags
       tag.destroy
     end
     
     for tag in self.tags.split(",") # separate tag by comma       
       tag = tag.strip # remove whitespace  
       if !tag.empty?
        tag = PluginTag.new(:item_id => self.id, :name => tag.strip)
        tag.is_approved = "1"
        tag.save
       end
    end
  end 
 end 
 
=begin
  # Create Dynamic Attributes from Features
  for feature in PluginFeature.find(:all)
     # Create Setter
     #self.class.class_eval do # remember, class_eval makes instance methods: def method {} end 
      define_method("#{feature.name}=".to_sym) do |value|
        instance_variable_set( "@" + feature.name, val) # instance_variable_set adds def [var] @var end
      end
      
      # Create Getter
      define_method(feature.name.to_sym) do 
        instance_variable_get( "@" + feature.name) # instance_variable_set adds def [var] @var end
      end      
     #end    
    
  end
  
  def method_missing(method_id, *arguments_you_tried_to_pass_in) # handle unknown method
    puts "No Method Found.\nYou tried to run: #{method_id}\nWith the arguments: #{arguments_you_tried_to_pass_in.inspect}" 
  end
=end
end
