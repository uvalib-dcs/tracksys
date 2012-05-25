ActiveAdmin.register Unit do
  menu :priority => 4
  
  scope :all, :default => true
  scope :approved
  scope :unapproved
  scope :awaiting_copyright_approval
  scope :awaiting_condition_approval
  scope :canceled

  actions :all, :except => [:destroy]

  batch_action :approve_units do |selection|
    Unit.find(selection).each {|s| s.update_attribute(:unit_status, 'approved') }
    flash[:notice] = "Units #{selection.join(", ")} are now approved."
    redirect_to :back
  end

  batch_action :cancel_units do |selection|
    Unit.find(selection).each {|s| s.update_attribute(:unit_status, 'canceled') }
    flash[:notice] = "Units #{selection.join(", ")} are now canceled."
    redirect_to :back
  end

  batch_action :check_condition_units do |selection|
    Unit.find(selection).each {|s| s.update_attribute(:unit_status, 'condition') }
    flash[:notice] = "Units #{selection.join(", ")} need to be vetted for condition."
    redirect_to :back
  end

  batch_action :check_copyright_units do |selection|
    Unit.find(selection).each {|s| s.update_attribute(:unit_status, 'copyright') }
    flash[:notice] = "Units #{selection.join(", ")} need to be vetted for copyright."
    redirect_to :back
  end

  batch_action :print_routing_slips do |selection|

  end

  filter :id
  filter :date_archived
  filter :date_dl_deliverables_ready
  filter :date_queued_for_ingest
  filter :include_in_dl, :as => :select, :input_html => {:class => 'chzn-select'}
  filter :bibl_call_number, :as => :string, :label => "Call Number"
  filter :bibl_title, :as => :string, :label => "Bibl. Title"
  filter :order_id, :as => :numeric, :label => "Order ID"
  filter :customer_id, :as => :numeric, :label => "Customer ID"
  filter :agency, :as => :select, :input_html => {:class => 'chzn-select'}
  filter :indexing_scenario, :input_html => {:class => 'chzn-select'}
  filter :availability_policy, :input_html => {:class => 'chzn-select'}

  index do
    selectable_column
    column :id
    column("Status") do |unit|
      status_tag(unit.unit_status)
    end
    column ("Bibliographic Record") do |unit|
      div do 
        link_to "#{unit.bibl_title}", admin_bibl_path("#{unit.bibl_id}") 
      end
      div do 
        unit.bibl_call_number
      end
    end
    column ("DL Status") {|unit|
      case 
        when unit.include_in_dl?
          Unit.human_attribute_name(:include_in_dl)
        when unit.exclude_from_dl?
          Unit.human_attribute_name(:exclude_from_dl)
      end
    }
    column :date_archived do |unit|
      format_date(unit.date_archived)
    end
    column :date_queued_for_ingest do |unit|
      format_date(unit.date_queued_for_ingest)
    end
    column :date_dl_deliverables_ready do |unit|
      format_date(unit.date_dl_deliverables_ready)
    end
    column :intended_use
    column("Master Files") do |unit| 
      link_to unit.master_files_count, admin_master_files_path(:q => {:unit_id_eq => unit.id})
    end
    column("") do |unit|
      div do
        link_to "Details", resource_path(unit), :class => "member_link view_link"
      end
      div do
        link_to I18n.t('active_admin.edit'), edit_resource_path(unit), :class => "member_link edit_link"
      end
    end
  end

  show :title => proc{"Unit ##{unit.id}"} do
    div :class => 'two-column' do
      panel "General Information" do
        attributes_table_for unit do
          row ("Status") do |unit|
            status_tag(unit.unit_status)
          end
          row :unit_extent_estimated
          row :unit_extent_actual
          row :heard_about_resource
          row :patron_source_url
          row :special_instructions
          row :staff_notes
        end
      end
    end

    div :class => 'two-column' do
      panel "Patron Request" do
        attributes_table_for unit do
          row :intended_use
          row :intended_use_deliverable_format
          row :intended_use_deliverable_resolution
          row :remove_watermark do |unit|
            format_boolean_as_yes_no(unit.remove_watermark)
          end
          row :date_materials_received do |unit|
            format_date(unit.date_materials_received)
          end
          row :date_materials_returned do |unit|
            format_date(unit.date_materials_returned)
          end
          row :date_archived do |unit|
            format_datetime(unit.date_archived)
          end
          row :date_patron_deliverables_ready do |unit|
            format_datetime(unit.date_patron_deliverables_ready)
          end
        end
      end
    end

    div :class => "columns-none" do
      panel "Digital Library Information", :toggle => 'hide' do
        attributes_table_for unit do 
          row :indexing_scenario
          row :availability_policy
          row :use_right
          row ("Digital Library Status") do |unit|
            case 
              when unit.include_in_dl?
                Unit.human_attribute_name(:include_in_dl)
              when unit.exclude_from_dl?
                Unit.human_attribute_name(:exclude_from_dl)
            end
          end
          row :master_file_discoverability do |unit|
            format_boolean_as_yes_no(unit.master_file_discoverability)
          end
          row :date_queued_for_ingest do |unit|
            format_datetime(unit.date_queued_for_ingest)
          end
          row :date_dl_deliverables_ready do |unit|
            format_datetime(unit.date_dl_deliverables_ready)
          end
        end
      end
    end

    div :class => "columns-none" do
      if not unit.master_files.empty?
      then
        panel "Master Files", :toggle => 'show' do
          table_for unit.master_files do |mf|
            column :filename, :sortable => false
            column :title do |mf|
              truncate_words(mf.title)
            end
            column :description do |mf|
              truncate_words(mf.description)
            end
            column :date_archived do |mf|
              format_date(mf.date_archived)
            end
            column :date_dl_ingest do |mf|
              format_date(mf.date_dl_ingest)
            end
            column :pid, :sortable => false
            column("Thumbnail") do |mf|
              link_to image_tag(mf.link_to_static_thumbnail, :height => 125), "#{mf.link_to_static_thumbnail}", :rel => 'colorbox', :title => "#{mf.filename} (#{mf.title} #{mf.description})"
            end
            column("") do |mf|
              div do
                link_to "Details", admin_master_file_path(mf), :class => "member_link view_link"
              end
              div do
                link_to I18n.t('active_admin.edit'), edit_admin_master_file_path(mf), :class => "member_link edit_link"
              end
              if mf.in_dl?
                div do
                  link_to "Fedora", "#{FEDORA_REST_URL}/objects/#{mf.pid}", :class => 'member_link', :target => "_blank"
                end
              end
              if mf.date_archived
                div do
                  link_to "Download", copy_from_archive_admin_master_file_path(mf.id), :method => :put
                end
              end
            end          
          end
        end
      else
        panel "No Master Files Directly Associated with this Component"
      end
    end
  end

  form do |f|
    f.inputs "General Information", :class => 'panel three-column ' do
      f.input :unit_status, :as => :select, :collection => Unit::UNIT_STATUSES, :input_html => {:class => 'chzn-select', :style => 'width: 150px'}
      f.input :unit_extent_estimated
      f.input :unit_extent_actual
      f.input :special_instructions, :as => :text, :input_html => { :rows => 5 }
      f.input :staff_notes, :as => :text, :input_html => { :rows => 5 }
    end

    f.inputs "Patron Request", :class => 'panel three-column' do
      f.input :intended_use, :as => :select, :collection => IntendedUse.all, :input_html => {:class => 'chzn-select'}
      f.input :remove_watermark, :as => :radio
      f.input :date_materials_received, :as => :string, :input_html => {:class => :datepicker}
      f.input :date_materials_returned, :as => :string, :input_html => {:class => :datepicker}
      f.input :date_archived, :as => :string, :input_html => {:class => :datepicker}
      f.input :date_patron_deliverables_ready, :as => :string, :input_html => {:class => :datepicker}
      f.input :patron_source_url,  :as => :text, :input_html => { :rows => 1 }
    end

    f.inputs "Related Information", :class => 'panel three-column' do 
      f.input :order, :as => :select, :collection => Order.all, :input_html => {:class => 'chzn-select', :style => 'width: 200px'}
      f.input :bibl, :as => :select, :collection => Hash[Bibl.all.map{|b| [b.barcode,b.id]}], :input_html => { :class => 'chzn-select', :style => 'width: 250px'}
      f.input :archive, :as => :select, :collection => Archive.all, :input_html => { :class => 'chzn-select', :style => 'width: 250px'}
    end

    f.inputs "Digital Library Information", :class => 'columns-none panel', :toggle => 'hide' do
      f.input :indexing_scenario
      f.input :availability_policy
      f.input :use_right
      f.input :include_in_dl, :as => :radio
      f.input :exclude_from_dl, :as => :radio
      f.input :master_file_discoverability, :as => :radio
      f.input :date_queued_for_ingest, :as => :string, :input_html => {:class => :datepicker}
      f.input :date_dl_deliverables_ready, :as => :string, :input_html => {:class => :datepicker}
    end

    f.inputs :class => 'columns-none' do
      f.actions
    end

  end

  sidebar "Related Information", :only => [:show] do
    attributes_table_for unit do
      row :bibl
      row :order do |unit|
        link_to "##{unit.order.id}", admin_order_path(unit.order.id)
      end
      row :master_files do |unit|
        link_to "#{unit.master_files_count}", admin_master_files_path(:q => {:unit_id_eq => unit.id})
      end 
      row :customer
      row :automation_messages do |unit|
        link_to "#{unit.automation_messages_count}", admin_automation_messages_path(:q => {:messagable_id_eq => unit.id, :messagable_type_eq => "Unit" })
      end
      row :agency
      row :archive
    end
  end

  # In order to keep this print_routing_slip method DRY, the patron path will still be referred to since there 
  # are no further actions available at that screen.  When replaced by generating PDFs, we can revisit this DRYness.
  sidebar :approval_workflow, :only => :show do
    div :class => 'workflow_button' do button_to "Print Routing Slip", print_routing_slip_patron_unit_path, :method => :put end
  end

  sidebar "Delivery Workflow", :only => [:show] do
    if File.exist?(File.join(IN_PROCESS_DIR, "%09d" % unit.id))
      if not unit.date_archived
        div :class => 'workflow_button' do button_to "QA Unit Data", qa_unit_data_admin_unit_path , :method => :put end
        div :class => 'workflow_button' do button_to "QA Filesystem and XML", qa_filesystem_and_iview_xml_admin_unit_path , :method => :put end
        div :class => 'workflow_button' do button_to "Create Master File Records", import_unit_iview_xml_admin_unit_path, :method => :put end
        div :class => 'workflow_button' do button_to "Send Unit to Archive", send_unit_to_archive_admin_unit_path, :method => :put, :confirm => 'Are you sure you want to archive this unit?' end
      end
      if not unit.date_patron_deliverables_ready and not unit.intended_use == 'Digital Collection Buidling'
        div :class => 'workflow_button' do button_to "Begin Generate Deliverables", check_unit_delivery_mode_admin_unit_path, :method => :put end
        # <%=button_to "Begin Generate Deliverables", {:action=>"check_unit_delivery_mode", :unit_id => unit.id, :order_id => unit.order.id} %>
      end

      if unit.date_archived and unit.date_patron_deliverables_ready and not unit.intended_use == 'Digital Collection Building'
        div do "This unit has been archived and patron deliverables are generated.  There are no more finalization steps available." end
      end
    else
      div do "Files for this unit do not reside in the finalization directory. No work can be done on them." end
    end 

    if unit.date_archived
      div :class => 'workflow_button' do button_to "Download Unit From Archive", copy_from_archive_admin_unit_path(unit.id), :method => :put end
    else
      div :class => 'workflow_button' do button_to "Download Unit From Archive", copy_from_archive_admin_unit_path(unit.id), :method => :put, :disabled => true end
      div do "This unit cannot be downloaded because it is not archived." end
    end
  end

  action_item :only => :show do
    link_to_unless(unit.previous.nil?, "Previous", admin_unit_path(unit.previous))
  end

  action_item :only => :show do
    link_to_unless(unit.next.nil?, "Next", admin_unit_path(unit.next))
  end

  member_action :print_routing_slip, :method => :put do
    @unit = Unit.find(params[:id])
    @bibl = @unit.bibl
    @order = @unit.order
    @customer = @order.customer
    render :layout => 'printable'
  end

  # Member actions for workflow
  member_action :check_unit_delivery_mode, :method => :put do
    Unit.find(params[:id]).check_unit_delivery_mode
    redirect_to :back, :notice => "Workflow started at the checking of the unit's delivery mode."
  end

  member_action :copy_from_archive, :method => :put do 
    Unit.find(params[:id]).get_from_stornext(request.env['HTTP_REMOTE_USER'].to_s)
    redirect_to :back, :notice => "Unit #{params[:id]} is now being downloaded to #{PRODUCTION_SCAN_FROM_ARCHIVE_DIR}."
  end

  member_action :import_unit_iview_xml, :method => :put do
    Unit.find(params[:id]).import_unit_iview_xml
    redirect_to :back, :notice => "Workflow started at the importation of the Iview XML and creation of master files."
  end

  member_action :qa_filesystem_and_iview_xml, :method => :put do
    Unit.find(params[:id]).qa_filesystem_and_iview_xml
    redirect_to :back, :notice => "Workflow started at QA of filesystem and Iview XML."
  end

  member_action :qa_unit_data, :method => :put do
    Unit.find(params[:id]).qa_unit_data
    redirect_to :back, :notice => "Workflow started at QA unit data."
  end

  member_action :send_unit_to_archive, :method => :put do
    Unit.find(params[:id]).send_unit_to_archive
    redirect_to :back, :notice => "Workflow started at the archiving of the unit."
  end
end