ActiveAdmin.register Customer do
  # menu :priority => 3
  menu :parent => "Miscellaneous"
  config.batch_actions = false

  # strong paramters handling
  permit_params :first_name, :last_name, :email, :academic_status_id, :department_id,
     primary_address_attributes: [:address_1, :address_2, :city, :state, :post_code, :country, :phone, :organization],
     billable_address_attributes: [:first_name, :last_name, :address_1, :address_2, :city, :state, :post_code, :country, :phone, :organization]

  config.clear_action_items!
  action_item :new, only: :index do
     raw("<a href='/admin/customers/new'>New</a>") if current_user.admin?
  end
  action_item :edit, only: :show do
     link_to "Edit", edit_resource_path  if current_user.admin?
  end

  scope :all, :default => true
  scope :has_unpaid_invoices

  filter :last_name_or_first_name_starts_with, label: "Name"
  filter :email_starts_with, label: "Email"
  filter :agencies, :as => :select, collection: Agency.pluck(:name, :id)
  filter :department, :as => :select, collection: Department.pluck(:name, :id)
  filter :primary_address_organization_or_billable_address_organization_starts_with, :label => "Organization"
  filter :academic_status, :as => :select, collection: AcademicStatus.pluck(:name, :id)

  index :as => :table do
    selectable_column
    column("Name", :sortable => false) do |customer|
      customer.full_name
    end
    column :requests do |customer|
       link_to customer.requests.to_a.size, admin_orders_path(:q => {:customer_id_eq => customer.id}, :scope => 'awaiting_approval')
    end
    column :orders do |customer|
      link_to customer.orders_count.to_s, admin_orders_path(:q => {:customer_id_eq => customer.id})
    end
    column :units do |customer|
      link_to customer.units.to_a.size, admin_units_path(:q => {:customer_id_eq => customer.id})
    end
    column :master_files do |customer|
      link_to customer.master_files_count.to_s, admin_master_files_path(:q => {:customer_id_eq => customer.id})
    end
    column :department, :sortable => false
    column :academic_status, :sortable => false
    column("Links") do |customer|
      div do
        link_to "Details", resource_path(customer), :class => "member_link view_link"
      end
      if current_user.admin?
         div do
           link_to I18n.t('active_admin.edit'), edit_resource_path(customer), :class => "member_link edit_link"
         end
      end
    end
  end

  show do
    div :class => 'three-column' do
      panel "Details", :id => 'customers' do
        attributes_table_for customer do
          row :full_name
          row :email do |customer|
            format_email_in_sidebar(customer.email).gsub(/\s/, "")
          end
          row :academic_status
          row :department
        end
      end
    end

    div :class => 'three-column' do
      panel "Primary Address", :id => 'customers' do
        if customer.primary_address
          attributes_table_for customer.primary_address do
            row :address_1
            row :address_2
            row :city
            row :state
            row :country
            row :post_code
            row :phone
            row :organization
          end
        else
          "No address available."
        end
      end
    end

    div :class => 'three-column' do
      panel "Billing Address", :id => 'customers' do
        if customer.billable_address
          attributes_table_for customer.billable_address do
            row :first_name
            row :last_name
            row :address_1
            row :address_2
            row :city
            row :state
            row :country
            row :post_code
            row :phone
            row :organization
          end
        else
          "No address available."
        end
      end
    end
  end

  form do |f|
    f.object.build_primary_address unless customer.primary_address
    f.object.build_billable_address unless customer.billable_address
    f.inputs "Details", :class => 'inputs three-column' do
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :academic_status, :as => :select
      f.input :department, :as => :select, :collection => Department.order(:name)
    end

    f.inputs "Primary Address (Required)", :class => 'inputs three-column' do
      f.semantic_fields_for :primary_address do |p|
        p.inputs do
          p.input :address_1
          p.input :address_2
          p.input :city
          p.input :state
          p.input :country, as: :select, collection: ActionView::Helpers::FormOptionsHelper::COUNTRIES, :input_html => {:class => 'chosen-select',  :style => 'width: 225px'}
          p.input :post_code
          p.input :phone
          p.input :organization
        end
      end
    end

    f.inputs "Billable Address (Optional)", :class => 'inputs three-column' do
      f.semantic_fields_for :billable_address do |b|
        b.inputs do
          b.input :first_name
          b.input :last_name
          b.input :address_1
          b.input :address_2
          b.input :city
          b.input :state
          b.input :country, as: :select, collection: ActionView::Helpers::FormOptionsHelper::COUNTRIES, :input_html => {:class => 'chosen-select',  :style => 'width: 225px'}
          b.input :post_code
          b.input :phone
          b.input :organization
        end
      end
    end

    f.inputs :class => 'columns-none customer-edit-actions' do
      f.actions
    end
  end

  sidebar "Related Information", :only => [:show] do
    attributes_table_for customer do
      row :requests do |customer|
         link_to customer.requests.count, admin_orders_path(:q => {:customer_id_eq => customer.id}, :scope => 'awaiting_approval')
      end
      row :orders do |customer|
        link_to customer.orders_count.to_s, admin_orders_path(:q => {:customer_id_eq => customer.id})
      end
      row :units do |customer|
        link_to customer.units.count, admin_units_path(:q => {:customer_id_eq => customer.id})
      end
      row :master_files do |customer|
        link_to customer.master_files_count.to_s, admin_master_files_path(:q => {:customer_id_eq => customer.id})
      end
      row "On Behalf of Agencies" do |customer|
         raw(customer.agency_links)
      end
      row :date_of_first_order do |customer|
        format_date(customer.date_of_first_order)
      end
    end
  end
end
