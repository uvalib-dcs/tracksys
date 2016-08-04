ActiveAdmin.register Bibl do
  menu :priority => 5

  # strong paramters handling
  permit_params :catalog_key, :barcode, :title, :creator_name, :call_number, :year, :year_type, :copy, :location,
      :cataloging_source, :citation, :description, :title_control, :series_title, :volume, :issue, :creator_name_type,
      :is_approved, :is_personal_item, :is_manuscript, :is_collection, :resource_type, :genre, :date_external_update,
      :exemplar, :discoverability, :dpla, :parent_bibl, :date_dl_ingest, :date_dl_update, :availability_policy_id,
      :collection_facet, :desc_metadata, :use_right_id, :indexing_scenario_id, :parent_bibl_id, :publication_place

  config.clear_action_items!

  action_item :new, :only => :index do
     raw("<a href='/admin/bibls/new'>New</a>") if !current_user.viewer?
  end

  action_item :edit, only: :show do
     link_to "Edit", edit_resource_path  if !current_user.viewer?
  end
  action_item :delete, only: :show do
     link_to "Delete", resource_path,
       data: {:confirm => "Are you sure you want to delete this BIBL?"}, :method => :delete  if current_user.admin?
  end

  scope :all, :default => true
  scope :approved
  scope :not_approved
  scope :in_digital_library
  scope :not_in_digital_library
  scope :dpla

  filter :id
  filter :title
  #filter :call_number
  filter :creator_name
  filter :catalog_key
  filter :barcode
  filter :pid
  #filter :publication_place, label: 'Place of Publication'
  filter :is_manuscript
  filter :dpla, :as => :select
  #filter :location
  filter :use_right, :as => :select, label: 'Right Statement'
  #filter :cataloging_source
  filter :resource_type, :as => :select, :collection => Bibl::RESOURCE_TYPES
  filter :availability_policy
  filter :customers_id, :as => :numeric
  filter :orders_id, :as => :numeric
  filter :agencies_id, :as => :numeric
  filter :collection_facet, :as => :string

  csv do
    column :id
    column :title
    column :creator_name
    column :call_number
    column :location
    column("# of Images") {|bibl| bibl.master_files.count}
    column("In digital library?") {|bibl| format_boolean_as_yes_no(bibl.in_dl?)}
  end

  index :id => 'bibls' do
    selectable_column
    column :title, :sortable => :title do |bibl|
      truncate_words(bibl.title, 25)
    end
    column :creator_name
   #  column :call_number
   #  column ("Source"), :class => 'sortable_short', :sortable => :cataloging_source do |bibl|
   #  	bibl.cataloging_source
   #  end
    column :catalog_key, :sortable => :catalog_key do |bibl|
      div do
        bibl.catalog_key
      end
      if bibl.in_catalog?
        div do
          link_to "VIRGO", bibl.physical_virgo_url, :target => "_blank"
        end
      end
    end
    column :barcode, :class => 'sortable_short'
    #column :location, :class => 'sortable_short'
    column ("Digital Library?") do |bibl|
      div do
        format_boolean_as_yes_no(bibl.in_dl?)
      end
      if bibl.in_dl?
        div do
          link_to "VIRGO", bibl.dl_virgo_url, :target => "_blank"
        end
      end
    end
    column ("DPLA?") do |bibl|
      format_boolean_as_yes_no(bibl.dpla)
    end
    column :units, :class => 'sortable_short', :sortable => :units_count do |bibl|
      link_to bibl.units.count, admin_units_path(:q => {:bibl_id_eq => bibl.id})
    end
    column("Master Files") do |bibl|
      link_to bibl.master_files.count, admin_master_files_path(:q => {:bibl_id_eq => bibl.id})
    end
    column("Links") do |bibl|
      div do
        link_to "Details", resource_path(bibl), :class => "member_link view_link"
      end
      if !current_user.viewer?
         div do
           link_to I18n.t('active_admin.edit'), edit_resource_path(bibl), :class => "member_link edit_link"
         end
      end
    end
  end

  show :title => proc { truncate(@virgo_meta[:title], :length => 60) } do
    div :class => 'three-column' do
      panel "Basic Information" do
        render 'virgo_meta'
      end
    end

    div :class => 'three-column' do
      panel "Detailed Bibliographic Information" do
        render 'virgo_detail'
      end
    end

    div :class => 'three-column' do
      panel "Administrative Information", :toggle => 'show' do
        attributes_table_for bibl do
          row :is_approved do |bibl|
            format_boolean_as_yes_no(bibl.is_approved)
          end
          row :is_personal_item do |bibl|
            format_boolean_as_yes_no(bibl.is_personal_item)
          end
          row :is_manuscript do |bibl|
            format_boolean_as_yes_no(bibl.is_manuscript)
          end
          row :is_collection do |bibl|
            format_boolean_as_yes_no(bibl.is_collection)
          end
          row :resource_type do |bibl|
            bibl.resource_type.to_s.titleize
          end
          row :genre do |bibl|
            bibl.genre.to_s.titleize
          end
          row ("Date Created") do |bibl|
            bibl.created_at
          end
          row ("Date Updated from VIRGO") do |bibl|
            bibl.date_external_update
          end
        end
      end
    end

    div :class => 'columns-none' do
      panel "Digital Library Information", :toggle => 'show' do
        attributes_table_for bibl do
          row ("In Digital Library?") do |bibl|
            format_boolean_as_yes_no(bibl.in_dl?)
          end
          row :pid
          row :date_dl_ingest
          row :date_dl_update
          row :exemplar do |bibl|
            link_to "#{bibl.exemplar}", admin_master_files_path(:q => {:filename_eq => bibl.exemplar})
          end
		    row :dpla
          row('Right Statement'){ |r| r.use_right.name }
          row :availability_policy
          row :indexing_scenario
          row ("Discoverable?") do |bibl|
            format_boolean_as_yes_no(bibl.discoverability)
          end
          row :collection_facet
          row :desc_metadata
        end
      end
    end
  end

  sidebar "Related Information", :only => [:show, :edit] do
    attributes_table_for bibl do
      row ("Catalog Record") do |bibl|
        if bibl.in_catalog?
          div do
            link_to "VIRGO (Physical Record)", bibl.physical_virgo_url, :target => "_blank"
          end
        end
        if bibl.in_dl?
          div do
            link_to "VIRGO (Digital Record)", bibl.dl_virgo_url, :target => "_blank"
          end
        end
      end
      row :master_files do |bibl|
        link_to "#{bibl.master_files.count}", admin_master_files_path(:q => {:bibl_id_eq => bibl.id})
      end
      row :units do |bibl|
        link_to "#{bibl.units.size}", admin_units_path(:q => {:bibl_id_eq => bibl.id})
      end
      row :orders do |bibl|
        link_to "#{bibl.orders.count}", admin_orders_path(:q => {:bibls_id_eq => bibl.id}, :scope => :uniq )
      end
      row :customers do |bibl|
        link_to "#{bibl.customers.count}", admin_customers_path(:q => {:bibls_id_eq => bibl.id})
      end
      # row :components do |bibl|
      #   link_to "#{bibl.components.count}", admin_components_path(:q => {:bibls_id_eq => bibl.id})
      # end
      row "Agencies Requesting Resource" do |bibl|
        raw(bibl.agency_links)
      end
      row "Legacy Identifiers" do |bibl|
        raw(bibl.legacy_identifier_links)
      end
      row("Collection Bibliographic Record") do |bibl|
        if bibl.parent_bibl
          link_to "#{bibl.parent_bibl.title}", admin_bibl_path(bibl.parent_bibl)
        end
      end
      row "child bibls" do |bibl|
      	link_to "#{bibl.child_bibls.size}", admin_bibls_path(:q => {:parent_bibl_id_eq => bibl.id } )
      end
    end
  end

  sidebar "Digital Library Workflow", :only => [:show],  if: proc{ !current_user.viewer? } do
     if bibl.in_dl?
        div :class => 'workflow_button' do button_to "Publish",
          publish_admin_bibl_path(:datastream => 'all'), :method => :put end
     else
        "No options available.  Object is not in DL."
     end
  end

  form :partial => "form"

  collection_action :external_lookup

  collection_action :create_dl_manifest do
    CreateDlManifest.exec( {:staff_member => current_user } )
    redirect_to "/admin/dashboard", :notice => "Digital library manifest creation started.  Check your email in a few minutes."
  end

  member_action :publish, :method => :put do
    bibl = Bibl.find(params[:id])
    bibl.update_attribute(:date_dl_update, Time.now)
    logger.info "Bibl #{bibl.id} has been flagged for an update in the DL"
    redirect_to "/admin/bibls/#{params[:id]}", :notice => "Bibl flagged for Publication"
  end

  controller do
      before_filter :get_virgo, only: [:edit, :show]
      def get_virgo
         @virgo_meta = {}
         if !resource.catalog_key.blank? || !resource.barcode.blank?
            @virgo_meta =  Virgo.external_lookup(resource.catalog_key, resource.barcode)
         end
      end
      before_filter :blank_virgo, only: [:new ]
      def blank_virgo
         @virgo_meta = {catalog_key: '', barcode: '' }
      end

      def external_lookup
         # look up catalog ID (passed as a parameter) in external metadata source,
         # getting back a Bibl object with the values from the external source
         @virgo_meta = Virgo.external_lookup(params[:catalog_key], params[:barcode])
         render json: @virgo_meta, status: :ok
      end
  end
end
