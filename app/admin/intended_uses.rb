ActiveAdmin.register IntendedUse do
   menu :parent => "Miscellaneous", if: proc{ current_user.admin? || current_user.supervisor? }
   config.sort_order = "description_asc"

   # strong paramters handling
   permit_params :description, :is_internal_use_only, :is_approved, :deliverable_format, :deliverable_resolution, :deliverable_resolution_unit

   config.clear_action_items!
   action_item :new, :only => :index do
      raw("<a href='/admin/intended_uses/new'>New</a>") if current_user.admin?
   end
   action_item :edit, only: :show do
      link_to "Edit", edit_resource_path  if current_user.admin?
   end

   config.batch_actions = false
   config.filters = false

   index do
      column :id
      column :description do |iu|
         iu.name
      end
      column :is_internal_use_only do |intended_use|
         format_boolean_as_yes_no(intended_use.is_internal_use_only)
      end
      column :is_approved do |intended_use|
         format_boolean_as_yes_no(intended_use.is_approved)
      end
      column("Links") do |intended_use|
         div {link_to "Details", resource_path(intended_use), :class => "member_link view_link"}
         if current_user.admin?
            div {link_to I18n.t('active_admin.edit'), edit_resource_path(intended_use), :class => "member_link edit_link"}
         end
      end
   end

   show :title => proc { |use| use.description } do
      panel "General Information" do
         attributes_table_for intended_use do
            row :description
            row :deliverable_format
            row :deliverable_resolution
            row :deliverable_resolution_unit
            row :is_internal_use_only do |intended_use|
               format_boolean_as_yes_no(intended_use.is_internal_use_only)
            end
            row :is_approved do |intended_use|
               format_boolean_as_yes_no(intended_use.is_approved)
            end
            row :created_at
            row :updated_at
         end
      end
   end

   form do |f|
      f.inputs "General Information", :class => 'columns-none panel' do
         f.input :description
         f.input :deliverable_format
         f.input :deliverable_resolution
         f.input :deliverable_resolution_unit
         f.input :is_internal_use_only, :as => :radio
         f.input :is_approved, :as => :radio
      end

      f.inputs :class => 'columns-none' do
         f.actions
      end
   end

   sidebar "Related Information", :only => [:show] do
      attributes_table_for intended_use do
         row :units_count do |intended_use|
            link_to "#{intended_use.units_count}", admin_units_path(:q => {:intended_use_id_eq => intended_use.id})
         end
      end
   end

end
