ActiveAdmin.register StaffMember do
  config.sort_order = 'last_name_dsc'
  config.per_page = [30, 50, 100, 250]

  menu :parent => "Miscellaneous"

  # strong paramters handling
  permit_params :computing_id, :last_name, :first_name, :is_active, :role, :email, :notes

  config.clear_action_items!
  action_item :new, :only => :index do
     raw("<a href='/admin/staff_members/new'>New</a>") if current_user.admin?
  end
  action_item :edit, only: :show do
     link_to "Edit", edit_resource_path  if current_user.admin?
  end

  filter :last_name_starts_with, label: "last name"
  filter :computing_id_starts_with, label: "computing Id"
  filter :role, :as => :select, :collection => StaffMember.roles

  config.batch_actions = false

  index do
    selectable_column
    column :full_name
    column :computing_id
    column :email
    column :role
    column("Active?") do |staff_member|
      format_boolean_as_yes_no(staff_member.is_active)
    end
    column("") do |staff_member|
      div do
        link_to "Details", resource_path(staff_member), :class => "member_link view_link"
      end
      if current_user.admin?
         div do
           link_to I18n.t('active_admin.edit'), edit_resource_path(staff_member), :class => "member_link edit_link"
         end
      end
    end
  end

  show :title => proc { |staff| staff.full_name } do
    panel "Detailed Information" do
      attributes_table_for staff_member do
        row :full_name
        row :computing_id
        row :email
        row :role
        row :notes
        row :is_active
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :computing_id
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :role, :as => :select
      f.input :is_active, :as => :radio
      f.input :notes, :as => :text, :input_html => {:rows => 5}
    end

    f.actions
  end
end
