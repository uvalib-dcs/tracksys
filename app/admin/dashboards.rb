ActiveAdmin.register_page "Dashboard" do
   menu :priority => 1

   content do
      div :class => 'three-column' do
         panel "Recent DL Items (20)", :toggle => 'show' do
            table_for Metadata.in_digital_library.limit(20) do
               column ("Title") {|metadata| truncate(metadata.title, :length => 80)}
               column ("Thumbnail") do |metadata|
                  if metadata.has_exemplar?
                     info = metadata.exemplar_info(:small)
                     image_tag(info[:url], id: info[:id] )
                  else
                     "no thumbnail"
                  end
               end
               column("Links") do |metadata|
                  div do
                     if metadata.type == "XmlMetadata"
                        link_to "Details", "/admin/xml_metadata/#{metadata.id}", :class => "member_link view_link"
                     else
                        link_to "Details", "/admin/sirsi_metadata/#{metadata.id}", :class => "member_link view_link"
                     end
                  end
               end
            end
         end
      end

      div :class => 'three-column' do
         panel "Outstanding Orders", :toggle => 'show' do
            table do
               tr do
                  td do "Orders Due Today" end
                  td do link_to "#{Order.due_today.count}", admin_orders_path(:order => 'date_due_desc', :page => '1', :scope => 'due_today') end
               end
               tr do
                  td do "Orders Due In A Week" end
                  td do link_to "#{Order.due_in_a_week.count}", admin_orders_path(:order => 'date_due_desc', :page => '1', :scope => 'due_in_a_week') end
               end
               tr do
                  td do "Orders Overdue (< 1 yr)" end
                  td do link_to "#{Order.overdue.count}", admin_orders_path(:order => 'date_due_desc', :page => '1', :scope => 'overdue') end
               end
               tr do
                  td do "Invoices Overdue (30 days or more)" end
                  td do link_to "#{Invoice.past_due.count}", admin_invoices_path(:order => 'date_invoice_desc', :page => '1', :scope => 'past_due') end
               end
               tr do
                  td do "Invoices Overdue (2nd notice)" end
                  td do link_to "#{Invoice.notified_past_due.count}", admin_invoices_path(:order => 'date_invoice_desc', :page => '1', :scope => 'notified_past_due') end
               end
               tr do
                  td do "Customers with unpaid orders" end
                  td do link_to "#{Customer.has_unpaid_invoices.count}", admin_customers_path(:customer => 'id_desc', :page => '1', :scope => 'has_unpaid_invoices')  end
               end
               tr do
                  td do "Total unpaid invoices" end
                  td do
                     link_to "#{number_to_currency(Order.unpaid.to_a.sum(&:fee_actual), :precision => 0)}",
                        admin_orders_path( :page => 1, :scope => 'unpaid', :order => 'fee_actual_desc'  )
                  end
               end
            end
         end

         panel "Recent Job Status Summary", :namespace => :admin, :toggle => 'show' do
            table do
               tr do
                  td do "Pending Jobs" end
                  td do link_to "#{JobStatus.jobs_count('pending')}", admin_job_statuses_path(:q => {:status => 'pending'} ) end
               end
               tr do
                  td do "Running Jobs" end
                  td do link_to "#{JobStatus.jobs_count('running')}", admin_job_statuses_path(:q => {:status_eq => 'running'} ) end
               end
               tr do
                  td do "Successful Jobs" end
                  td do link_to "#{JobStatus.jobs_count('success')}", admin_job_statuses_path(:q => {:status_eq => 'success'} ) end
               end
               tr do
                  td do "Failed Jobs" end
                  td do link_to "#{JobStatus.jobs_count("failure")}", admin_job_statuses_path(:q => {:status_eq => 'failure'} ) end
               end
            end
         end

         panel "Finalization", :width => '33%', :namespace => :admin, :toggle => 'show' do
            table do
               tr do
                  td do "Unfinished Units of Partially Finalized Orders" end
                  td do
                     link_to "#{Unit.uncompleted_units_of_partially_completed_orders.count}",
                     admin_units_path( :order => 'id_desc', :page => '1', :scope => 'uncompleted_units_of_partially_completed_orders')
                  end
               end
               tr do
                  td do "Orders Ready for Delivery" end
                  td do link_to "#{Order.ready_for_delivery.count}", admin_orders_path( :order => 'id_desc', :page => '1', :scope => 'ready_for_delivery') end
               end
            end
         end

         panel "PID Finder" do
            render 'admin/pid_finder'
         end
         panel "Master File Finder" do
            render 'admin/master_file_finder'
         end
      end

      div :class => 'three-column' do
         panel "My Projects", :toggle => 'show' do
            if current_user.projects.count > 0
               table do
                  tr do
                     th do "Name" end
                     th do "Due On" end
                     th do "Current Step" end
                     th do "Link" end
                  end
                  current_user.projects.order(due_on: :desc).each do |p|
                     tr do
                        td do p.project_name.truncate( 30, separator: ' ') end
                        td do p.due_on end
                        td do p.current_step.name end
                        td do link_to "Details", "/admin/projects/#{p.id}" end
                     end
                  end
               end
            else
               div do
                  "No projects are currently assigned to you"
               end
            end
         end
         if !current_user.viewer? && !current_user.student?
            panel "Problem Projects", :toggle => 'show' do
               if Project.has_error.count == 0 && Project.failed_qa.count == 0 && Project.overdue.count == 0
                  div do
                     "There are no problems with any active projects"
                  end
               else
                  table do
                     tr do
                        th do "Name" end
                        th do "Due On" end
                        th do "STEP" end
                        th do "Status" end
                        th do "Link" end
                     end
                     Project.has_error.order(due_on: :desc).limit(10).each do |p|
                        tr do
                           td do p.project_name.truncate( 30, separator: ' ') end
                           td do p.due_on end
                           td do p.current_step.name end
                           td do "ERROR" end
                           td do link_to "Details", "/admin/projects/#{p.id}" end
                        end
                     end
                     Project.failed_qa.order(due_on: :desc).limit(10).each do |p|
                        tr do
                           td do p.project_name.truncate( 30, separator: ' ') end
                           td do p.due_on end
                           td do p.current_step.name end
                           td do "FAILED QA" end
                           td do link_to "Details", "/admin/projects/#{p.id}" end
                        end
                     end
                     Project.overdue.order(due_on: :desc).limit(10).each do |p|
                        tr do
                           td do p.project_name.truncate( 30, separator: ' ') end
                           td do p.due_on end
                           td do p.current_step.name end
                           td do "OVERDUE" end
                           td do link_to "Details", "/admin/projects/#{p.id}" end
                        end
                     end
                  end
               end
            end
         end
      end
   end

   page_action :get_yearly_stats do
      CreateStatsReport.exec( {:user_id=>current_user.id, :year => params[:year]} )
      flash[:notice] = "Stats Report Being Created. You will receive an email when report is ready."
      redirect_to "/admin/dashboard"
   end

   page_action :master_file_lookup do
      if params[:box].blank? && params[:folder].blank? && params[:tag].blank?
         flash[:notice] = "Box, folder or tag is required!"
         redirect_to "/admin/dashboard"
      end
      # q%5Blocation_container_id_starts_with%5D=boxy&q%5Blocation_folder_id_starts_with%5D=xxx
      qp = []
      if !params[:box].blank?
         qp << "q[location_container_id_starts_with]=#{params[:box]}"
      end
      if !params[:folder].blank?
         qp << "q[location_folder_id_starts_with]=#{params[:folder]}"
      end
      if !params[:tag].blank?
         qp << "q[tags_tag_contains]=#{params[:tag]}"
      end
      redirect_to "/admin/master_files?#{qp.join('&')}"
   end

   page_action :pid_lookup do
      object = Metadata.find_by(pid: params[:pid])
      if !object.nil?
         redirect_to "/admin/#{object.type.underscore}/#{object.id}" and return
      end

      object = MasterFile.find_by(pid: params[:pid])
      if !object.nil?
         redirect_to "/admin/master_files/#{object.id}" and return
      end
      object = Component.find_by(pid: params[:pid])
      if !object.nil?
         redirect_to "/admin/components/#{object.id}" and return
      end

      flash[:notice] = "Could not find PID #{params[:pid]}"
      redirect_to "/admin/dashboard"
   end
end
