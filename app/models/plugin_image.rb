class PluginImage < ActiveRecord::Base
  acts_as_opal_plugin

  belongs_to :plugin
  belongs_to :item
  belongs_to :user
  
  validates_uniqueness_of :url, :scope => :item_id
  validate :validate_source
  validates :remote_file, :uri => { :format => /(^$)|(^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$)/ix }, :if => lambda{|o|o.local_file.blank?} 
  before_create :generate_image
  before_destroy :delete_files
 
  attr_accessor :local_file, :remote_file, :effects, :source 
   

  def validate_source # check if files have beeen selected and if they're in proper format, etc.
    if local_file.blank? # local file not specified
      if remote_file.blank?
        errors.add(:source, :blank) 
      end
    end 
  end
  
  def generate_image
      require "RMagick"     
      valid_extensions = ".png, .jpg, .jpeg, .gif, .bmp, .tiff, .PNG, .JPG, .JPEG, .GIF, .BMP, .TIFF"
      temp_file = Uploader.file_from_url_or_local(:local => local_file, :url => remote_file)
      temp_filename = File.basename(temp_file.path)
      logger.info temp_filename
      if Uploader.check_file_extension(:filename => temp_filename, :extensions => valid_extensions)
        # Generate Paths & Urls 
        self.url = File.join("/", "images", "item_images", item_id.to_s, "normal", temp_filename)
        self.thumb_url = File.join("/", "images", "item_images", item_id.to_s, "thumbnails", temp_filename)
        
        # generate image, apply special effects, save image to filesystem         
        image = Magick::Image.from_blob(File.open(temp_file.path).read)[0] # read in image binary, from_blob returns an array of images, grab first item
        Uploader.generate_image(
          :image => image,
          :path => File.join(Rails.root.to_s, "public", url),
          :thumbnail_path => File.join(Rails.root.to_s, "public", thumb_url),
          :effects => self.effects
        ) 
      else # format failed
        errors.add(:source, I18n.t("activerecord.errors.messages.invalid_file_extension", :valid_extensions => valid_extensions))
        return false
      end              
  end  
  
  def delete_files
    image_path = "#{Rails.root.to_s}/public" + "#{self.url}"
    thumb_path = "#{Rails.root.to_s}/public" + "#{self.thumb_url}"

    if File.exists?(image_path) # does the file exist?
     FileUtils.rm(image_path) # delete the file
    else # file doesn't exist
     self.errors.add('error', "System couldn't delete the normal file: #{image_path}! Continuing...")
    end

    if File.exists?(thumb_path) # does the file exist?
     FileUtils.rm(thumb_path) # delete the file
    else # file doesn't exist
     self.errors.add('error',  "System couldn't find the thumbnail file: #{thumb_path}! Continuing...")
    end
 end


  def filename # get filename from url 
    return File.basename(self.url)
  end
end
