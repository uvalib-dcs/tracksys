ActiveAdmin.register AvailabilityPolicy do
  config.sort_order = 'name_asc'
  menu :parent => "Miscellaneous"

  # strong paramters handling
  permit_params :name, :repository_url, :pid

  config.clear_action_items!
  action_item :new, :only => :index do
     raw("<a href='/admin/availability_policies/new'>New</a>") if !current_user.viewer?
  end
  action_item :edit, only: :show do
     link_to "Edit", edit_resource_path  if !current_user.viewer?
  end

  config.batch_actions = false
  config.filters = false

  index do
    column :name
    column :pid
    column("Bibls") do |availability_policy|
      link_to availability_policy.bibls_count, admin_bibls_path(:q => {:availability_policy_id_eq => availability_policy.id})
    end
    column("XML Metadata") do |availability_policy|
      link_to availability_policy.xml_metadata.count, admin_xml_metadata_path(:q => {:availability_policy_id_eq => availability_policy.id})
    end
    column("") do |availability_policy|
      div do
        link_to "Details", resource_path(availability_policy), :class => "member_link view_link"
      end
      if !current_user.viewer?
         div do
           link_to I18n.t('active_admin.edit'), edit_resource_path(availability_policy), :class => "member_link edit_link"
         end
      end
    end
  end

  show do
    panel "General Information" do
      attributes_table_for availability_policy do
        row :name
        row :pid
        row :created_at
        row :updated_at
      end
    end
  end

  sidebar "Related Information", :only => [:show] do
    attributes_table_for availability_policy do
      row("Bibls") do |availability_policy|
        link_to availability_policy.bibls_count.to_s, admin_bibls_path(:q => {:availability_policy_id_eq => availability_policy.id})
     end
    end
  end
end
