class PluginTagsController < ApplicationController
 # before_filter :authenticate_user # check if user is logged in and not a public user  
 before_filter :find_item # look up item 
 before_filter :find_plugin # find plugin
 before_filter :get_my_group_plugin_permissions # get permissions for this plugin  
 before_filter :check_item_edit_permissions, :only => [:change_approval] # list of actions that don't require that the item is editable by the user
 

 
 
  def create
   if @my_group_plugin_permissions.can_create? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # check permissions                   
     @tag = PluginTag.new
     @tag.name = params[:tag_name]
     @tag.user_id = @logged_in_user.id
     @tag.item_id = @item.id
     @tag.is_approved = "1" if !@my_group_plugin_permissions.requires_approval? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # approve if not required or owner or admin 
     
     if @tag.save
      Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "new", :log => t("log.item_create", :item => @plugin.human_name, :name => @tag.name))                                              
      flash[:success] = t("notice.item_create_success", :item => @plugin.human_name)
      flash[:notice] += "<br>" + t("notice.item_needs_approval", :item => @plugin.human_name) if !@tag.is_approved?
             
     else # fail saved 
      flash[:failure] = t("notice.item_create_failure", :item => @plugin.human_name)
     end
   else # Improper Permissions  
        flash[:failure] = t("notice.invalid_permissions")            
   end       
   redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
  end
  
  def delete
   if @my_group_plugin_permissions.can_delete? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # check permissions                   
     @tag = PluginTag.find(params[:tag_id])
     if @tag.destroy
      Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "delete", :log => t("log.item_delete", :item => @plugin.human_name, :name => @tag.name))                                                     
      flash[:success] = t("notice.item_delete_success", :item => @plugin.human_name)
     else # fail saved 
       flash[:failure] = t("notice.item_delete_failure", :item => @plugin.human_name)
     end
   else # Improper Permissions  
        flash[:failure] = t("notice.invalid_permissions")            
   end       
   redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
 end

 
 def change_approval
    @tag = PluginTag.find(params[:tag_id])    
    if  @tag.is_approved?
      approval = "0" # set to unapproved if approved already    
      log_msg = t("log.item_unapprove", :item => @plugin.human_name, :name => @tag.name)
    else
      approval = "1" # set to approved if unapproved already    
      log_msg = t("log.item_approve", :item => @plugin.human_name, :name => @tag.name)
    end
    
    if @tag.update_attribute(:is_approved, approval)
      Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "update", :log => log_msg)      
      flash[:success] = t("notice.item_approve_success", :item => @plugin.human_name) 
    else
      flash[:failure] =  t("notice.item_save_failure", :item => @plugin.human_name) 
    end
    redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
  end 
end
